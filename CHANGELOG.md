# Changelog

## [0.31.40] - 2026-08-14

**Correct the protocol-excerpt documentation drift and add a mechanical check for it (gh348-10, Step 10 of #348 spec, finding N1).** `CONTEXT.md`'s "Protocol excerpt" entry and `.claude/wiki/protocol-delivery-tiers.md` had fallen out of sync with the live templates after gh348 Steps 4, 11, and 17 added/renamed sections: both docs still said `templates/persona-protocol.md` carried 16 canonical sections (live: 19) and `templates/persona-protocol-slim.md` carried 6 (live: 7).

### Changed
- **`CONTEXT.md`, `.claude/wiki/protocol-delivery-tiers.md`** (scribe, `d41ebd7`): Re-measured live counts and corrected both docs — 16 -> 19 full-tier, 6 -> 7 slim-tier. Re-enumerated the wiki's full-tier section list in template order, dropping "Reviewer roast-work advisory pass trigger" (no longer exists) and adding "Teammate Write/Edit fallback and gate rephrasing doctrine", "Blocked by a gate you do not own", "Fourth verdict: escalate-to-human", and "Microworld bundles"; added "Blocked by a gate you do not own" to the slim-tier list; corrected the orchestrator description, which now carries a real 5-section drop list (14 of 19) rather than the full untrimmed set.
- **`tests/protocol-doc-drift.test.js`** (new, this step): Extracts the documented section counts from both `CONTEXT.md` and the wiki and asserts they equal the live `grep -c "^## "` count of `templates/persona-protocol.md` and `templates/persona-protocol-slim.md`, so this drift class cannot silently recur. Registered in `tests/validate.sh`.

### Notes
- Out of scope, flagged for a future cleanup: the wiki's stale line counts (says 300/83 lines, actual 529/84) and a "Three fail-closed behaviours" heading that actually enumerates 4 items.

## [0.31.39] - 2026-08-14

**Compress the two-gate rephrasing doctrine to a pointer (gh348-17, Step 17 of #348 spec).** `reviewed-path-gate.sh` and `human-decision-gate.sh` already print their complete remediation — the sanctioned heredoc template, its rules, and which gate a path-rephrasing workaround is (and isn't) sanctioned for — in their own refusal text, which is the only moment that doctrine is actionable. The full-tier `## Teammate Write/Edit fallback and gate rephrasing doctrine` section (added by Step 11, `ba1ad48`) reproduced that doctrine a second time across ten always-loaded persona copies; this step replaces the two rephrasing bullets with a single pointer sentence.

### Changed
- **`templates/persona-protocol.md`:** Replaced the `reviewed-path-gate.sh` command-text-constraint bullet and the "That rephrasing move is sanctioned for `reviewed-path-gate.sh` only" bullet in `## Teammate Write/Edit fallback and gate rephrasing doctrine` with one sentence: both gates print their complete remediation in their own refusal text, and rewording a command to dodge `human-decision-gate.sh`'s scan is always a self-authorized bypass, never a sanctioned workaround. The call-time-rejection bullet, the Bash-heredoc fallback idiom, and the grant-independence note are untouched. Section count unchanged at 19; the section retains its own header (still carries the Write/Edit rejection, the heredoc idiom, and the grant-independence note, ~19 lines including header).
- **`hooks/scripts/human-decision-gate.sh`, `hooks/scripts/reviewed-path-gate.sh`:** Untouched — this step's premise is that their refusal text already carries the full doctrine; confirmed unchanged (`git diff --exit-code` on both) and `tests/human-decision-gate.test.sh` still passes.
- **`.claude/agents/*.md`, `.claude/persona-protocol.md`, `.claude/persona-config.json` (`fileHashes`):** Mirrors regenerated via `node bin/cli.js --update`.

### Notes
- `tests/adapter-protocol-parity.test.js` needed no change: the section header text is unchanged, only its body content was compressed.
- Kept untouched per the step's scope: `templates/persona-protocol-slim.md` (Step 12 already removed the slim copy of this doctrine); `## Blocked by a gate you do not own` (the pointer's natural home, already stated the general rule).

## [0.31.38] - 2026-08-14

**Re-home the slim-tier Write/Edit fallback doctrine to scribe only (gh348-12, Step 12 of #348 spec).** The slim protocol template has no per-persona trimming seam (`selectProtocolSections` throws for the slim tier by design), so the Write/Edit-fallback bullets in `## Agent-teams mode` were reaching all four slim personas (explorer, researcher, scribe, agent-auditor) even though only scribe genuinely holds `Write, Edit`. No trimming mechanism is built here (rejected as disproportionate); the doctrine is instead moved into scribe's own body as a short paragraph.

### Changed
- **`templates/persona-protocol-slim.md`:** Cut the Write/Edit-fallback bullets (call-time rejection, Bash-heredoc fallback, `reviewed-path-gate.sh` two-gate rephrasing constraint, grant-independence note) from `## Agent-teams mode`. Kept the `skills:`/`mcpServers:` non-application, foreground-subagents-vs-nested-teams, and `SendMessage`-reporting bullets, which apply to all four slim personas. Section count unchanged at 7.
- **`agents/scribe.md`:** Added a short `## Write/Edit fallback in a teammate dispatch` paragraph carrying the call-time rejection, the Bash-heredoc fallback idiom, and a pointer to the relevant gate's own refusal text for the rephrasing rules — scribe is the one slim persona that genuinely holds `Write, Edit` (`agents/scribe.md:7`).
- **`tests/adapter-protocol-parity.test.js`:** Corrected a stale comment (~line 127) claiming "three" personas receive `persona-protocol-slim.md`; verified count is four (explorer, researcher, scribe, agent-auditor).
- **`.claude/agents/*.md`, `.claude/persona-protocol*.md`, `.claude/protocol-digest.md`, `.claude/persona-config.json` (`fileHashes`):** Mirrors regenerated via `node bin/cli.js --update`.

### Notes
- Measured word-count saving (`wc -w` on the shipped `.claude/agents/explorer.md` mirror, before this step's regeneration -> after): 1409 -> 1145. This is the finding's headline win: explorer is meant to be fast and cheap, and it never needed this doctrine in the first place.
- Kept untouched per the step's scope: `templates/persona-protocol.md` (Step 17 owns the full-tier copy of this doctrine); the slim template's `Blocked by a gate you do not own` and `Terminal status line` sections; `selectProtocolSections`'s slim-tier throw — no slim trimming mechanism is built here.

## [0.31.37] - 2026-08-14

**Split the Agent-teams protocol section so its Write/Edit-fallback half can be trimmed for `orchestrator` (gh348-11, Step 11 of #348 spec).** Trim granularity is whole `## ` sections, but only the `SendMessage`/nested-teams bullets of `Agent-teams mode` apply to the orchestrator as team lead — the Write/Edit call-time-rejection doctrine does not, since the orchestrator's own tools list never includes them. Splitting the section is what makes that half independently droppable.

### Changed
- **`templates/persona-protocol.md`:** Split `## Agent-teams mode (only relevant if you were spawned as a teammate)` at its natural seam. The section now keeps only the `skills:`/`mcpServers:` non-application, foreground-subagents-vs-nested-teams, and `SendMessage`-reporting bullets. A new canonical section, `## Teammate Write/Edit fallback and gate rephrasing doctrine`, carries the rest: the `Write`/`Edit` call-time rejection, the Bash-heredoc fallback, the `reviewed-path-gate.sh` command-text constraint and two-gate rephrasing doctrine, and the grant-independence note. 18 -> 19 top-level sections.
- **`bin/cli.js`:** The new header is NOT added to `UNIVERSAL_PROTOCOL_CORE` (which would reach every persona via its unconditional spread into every row's `include`); it is instead added explicitly to the `include` list of every full-tier row except `orchestrator`, whose row gains it in `drop` alongside `A note on \`memory\`` (`Microworld bundles` was already dropped for orchestrator by Step 4). `assertProtocolMatrixComplete` and `assertNoDanglingCrossReferences` both still pass at module load. Non-vacuity demonstrated by temporarily leaving the new header in both `UNIVERSAL_PROTOCOL_CORE` and orchestrator's `drop`: throws `PROTOCOL_SECTIONS_BY_PERSONA['orchestrator'] lists the same section in both include and drop`. The stale comment above the matrix claiming orchestrator is carried "including the memory note ... the table wins over the iff-frontmatter rule" no longer matches reality after this drop; corrected in place.
- **`tests/adapter-protocol-parity.test.js`:** Added a `deferred` entry for the new header to both `codexMap` and `cursorMap`, alongside the existing `Agent-teams mode` deferral (both ports already drop agent-teams mode entirely for v1). Non-vacuity: removing either entry makes `checkPort()` throw `no parity-map entry`.
- **`.claude/agents/*.md`, `.claude/persona-protocol.md`, `.claude/persona-config.json` (`fileHashes`):** Mirrors regenerated via `node bin/cli.js --update`.

### Notes
- Measured word-count saving (`wc -w` on the shipped `.claude/agents/orchestrator.md` mirror, before this step's regeneration -> after): 8817 -> 8394.
- Kept untouched per the step's scope: `templates/persona-protocol-slim.md` (Step 12 owns the slim copy of this doctrine); the `Terminal status line` section, including its protected "Why it exists" rationale paragraph; `GATED_AGENT_SECTIONS`.

## [0.31.36] - 2026-08-14

**Trim duplicated protocol excerpt sections (gh348-4, Step 4 of #348 spec).** `PROTOCOL_SECTIONS_BY_PERSONA` drop-list edit only, no prose rewrite: reviewer drops `Fourth verdict: escalate-to-human` (full escalation procedure already at `agents/reviewer.md:165-254`) and `Microworld bundles` (its whole duty already stated at `agents/reviewer.md:57-66`); orchestrator drops `Third verdict`/`Fourth verdict` (already at `agents/orchestrator.md:176-235`) and `Microworld bundles` (neither authors nor verifies bundles) — a partial, operator-approved (2026-08-13) reversal of the Pass-1 A3 ruling that orchestrator's row is deliberately untrimmed; spec-master and task-master drop `Microworld bundles`. `lead-programmer` retains the full schema unchanged — it is the author.

### Changed
- **`bin/cli.js`:** Moved the four headers above from `include` to `drop` on the `reviewer`, `orchestrator`, `spec-master`, and `task-master` rows of `PROTOCOL_SECTIONS_BY_PERSONA`. `assertProtocolMatrixComplete` and `assertNoDanglingCrossReferences` both still pass at module load — no new dangling cross-reference introduced.
- **`.claude/agents/*.md`, `.claude/persona-protocol*.md`, `.claude/protocol-digest.md`, `.claude/persona-config.json` (`fileHashes`):** Mirrors regenerated via `node bin/cli.js --update`.
- **`tests/cli-backfill.test.js`:** Updated the two assertions that hard-coded the superseded A3 ruling ("orchestrator row must drop nothing") to check the row's actual include/drop lists instead; added a dedicated orchestrator include/drop check (orchestrator is kept out of `TRIMMED_PERSONAS` because that list also drives the memory-section iff-frontmatter check, which orchestrator is a documented exception to).

### Notes
- Measured word-count saving (`wc -w` on the shipped `.claude/agents/*.md` mirror, before this step's regeneration -> after): `reviewer.md` 7725 -> 5619; `orchestrator.md` 11137 -> 8817; `spec-master.md` 5697 -> 4946; `task-master.md` 4821 -> 4070; `lead-programmer.md` 4681 -> 4681 (unchanged, retains the full microworld schema as its author).
- The stale `tests/cli-backfill.test.js` assertions were not in this step's originally stated Affected files list — found while running `tests/validate.sh`. Fixing them is a direct, documented consequence of the operator-approved A3 reversal this step implements (`docs/plans/2026-08-13-persona-efficiency-audit-gh348.md` finding 1.1), not new scope.

## [0.31.35] - 2026-08-14

**Make cross-section protocol references self-contained (gh348-2, Step 2 of #348 spec).** `selectProtocolSections()` trims `templates/persona-protocol.md` per persona without checking whether the surviving rendered text still points at a dropped section — the root cause behind several dangling backward references (2.2/2.6).

### Changed
- **`templates/persona-protocol.md`:** Rewrote every dangling `above`/`below`/quoted-header backward reference found by inspection to state the needed fact inline instead of pointing elsewhere — four "WIP sentinel ... above" mentions now carry the sentinel's file path (`.claude/wip-handoff.<agent-id>`); the Review-ownership paragraph's `"Third verdict"`/`"Fourth verdict"` pointers and the `.blocked` marker's `(below)` pointer are inlined; "the cap below" (Third- and Fourth-verdict sections) and "`.fail` record above" (Continuing-after-a-FAIL-verdict section) — two more instances of the identical root cause, found while auditing every above/below occurrence, not originally named in the spec step — are also inlined. The `<!-- ANTISLOP:BEGIN persona-protocol -->` header comment no longer claims the block is "Role-agnostic content only"; it now says the block is trimmed per persona and does carry role-specific sections.
- **`bin/cli.js`:** Added `assertNoDanglingCrossReferences()`, a build-time guard next to `assertProtocolMatrixComplete` that rejects a `PROTOCOL_SECTIONS_BY_PERSONA` row whose `include` set keeps a section referencing (by quoted header name, or bare key phrase near "above"/"below") a header the same row `drop`s. Runs at module load against the real matrix.
- **`tests/protocol-cross-references.test.js`** (new): C2.1 (five named full-tier mirrors carry the sentinel's file path wherever they mention it), C2.2 (no mirror carries a bare Third/Fourth-verdict backward reference), and C2.3 (the guard, against both a synthetic dangling row and the real matrix) — registered in `tests/validate.sh`.
- **`.claude/agents/*.md`, `.claude/persona-protocol.md`, `.claude/persona-config.json` (`fileHashes`):** Mirrors regenerated via `node bin/cli.js --update`.

### Notes
- Found but explicitly out of scope: `templates/persona-protocol-slim.md` (used by slim-tier personas `agent-auditor`/`explorer`/`scribe`/`researcher`) has the identical "WIP sentinel ... above" dangle with no accompanying section at all — not in this step's Affected files list, left for a separate pass.
- The guard is not exhaustive by design: a reference that names the dropped CONTENT without naming the header itself (the "cap below" / "`.fail` record above" shapes above) is outside what a text-matching guard can see — documented in its own comment.

## [0.31.34] - 2026-08-14

**Remove anomaly check A5 from the agent auditor (gh366, Step 18 of #348 spec).** A5 flagged a subagent whose final message lacked the `STATUS:` line, but `agents/agent-auditor.md` itself documents that finding as "a prompt to resume the subagent, not a defect" -- a check defined to be non-actionable. Ships onto contested ground by explicit operator choice: #334, #337, and #290 all touch these same three files and must re-baseline against an A5-free corpus after this lands (R10.2).

### Changed
- **`scripts/agent-audit.sh`:** Removed the A5 detection block, its plain-text summary line, and its `jq` detail line. Header comment updated from "six anomaly checks (A1-A6)" to "five anomaly checks (A1-A4, A6)" -- A6 was NOT renumbered.
- **`tests/agent-auditor.test.sh`:** Removed the `a5bad`/`a5good` fixtures, the `assert_agent_finding A5` assertions, and the `mutation_proof A5 a5bad` invocation. Header comment updated to credit A1 alone for mutation-proof non-vacuity.
- **`agents/agent-auditor.md`:** Removed the "A5 -- Missing terminal status line" entry and corrected the surrounding check count.

### Notes
- Mutation-proof coverage falls from two anomaly checks to one (A1 only) as a direct, acknowledged cost of this change (C18.4).
- The `## Terminal status line` section of `templates/persona-protocol.md` is untouched -- the STATUS line itself is not being removed from the protocol, only the audit check that reported its absence.
- `#334`, `#337`, `#290` all collide with this step on the same three files; left open, to be re-baselined against an A5-free corpus by whoever picks them up next (R10.2).

## [0.31.33] - 2026-08-14

**Widen marker-filename charclass to match dispatch grammar (gh360, Step 7 of #348 spec).** The `is_sanctioned_marker_write()` function in human-decision-gate.sh now accepts dots and hashes in marker-file ids (e.g., `gh345.1.pass`, `gh#348.pass`), matching the id grammar used by other dispatch gates. Leading-dot and traversal rejection unchanged.

### Changed
- **`hooks/scripts/human-decision-gate.sh`:** Widened id charclass from `[A-Za-z0-9_-]+` to `[A-Za-z0-9_][A-Za-z0-9_#.-]*` (line 58). Updated header comment (lines 19-23) to document the widened charclass and traversal-prevention mechanism.
- **`.claude/hooks/scripts/human-decision-gate.sh`:** Mirror regenerated to match source byte-for-byte.
- **`tests/human-decision-gate.test.sh`:** Added four new test cases (N24-N27) covering dot-containing ids, hash-containing ids, leading-dot rejection, and traversal prevention. Mutation-proof verified.

### Notes
- All 22 existing attack-case tests pass unchanged (C7.2 verified).
- BASH_REMATCH indices remain stable (no new capture group added; id charclass widened in-place).
- Byte-identical sync of source and mirror confirmed (C7.5).
- Validation passes (C7.6 verified).

## [0.31.32] - 2026-08-14

**Remove `antislop:coding-discipline` skill from reviewer persona (gh359, Step 6 of #348).** The reviewer persona never writes code, so the coding-discipline skill was dead weight. This change removes it from the reviewer's `skills:` frontmatter line, leaving only `antislop:roast-work` and `antislop:ubiquitous-language`.

### Changed
- **`agents/reviewer.md`:** Removed `antislop:coding-discipline` from frontmatter `skills:` line (C6.1).
- All persona mirrors (`.claude/agents/reviewer.md`, etc.) regenerated via `--update` to match.

### Notes
- No body references to coding-discipline existed to remove (C6.2 verified).
- Validation passes (C6.3 verified).

## [0.31.31] - 2026-08-14

**Documentation: remove expired legacy-marker grace-period paragraph from persona protocol.** The grace period ending on 2026-07-27 expired 18 days ago. This change removes the descriptive paragraph referencing the 2026-07-27 cutover from the canonical protocol template and regenerates all inline mirrors, leaving the hook script's actual expiry logic untouched. Addresses gh355 (Step 1 of #348 spec).

### Changed
- **`templates/persona-protocol.md` (before "Pending-review flag" section):** Deleted "Until 2026-07-27 (legacy-marker grace period)..." paragraph describing the warning-and-allow behavior that expired and was superseded by unconditional rejection.
- All persona mirrors (`.claude/agents/*`, `.claude/persona-protocol.md`, `.claude/protocol-digest.md`) regenerated via `--update` to match.

### Notes
- `hooks/scripts/task-gate.sh` expiry logic is unchanged — only the prose describing it was deleted.
- `GRACE_PERIOD_END` constant remains in place and continues to guard the expired behavior path for backward compatibility.

## [0.31.30] - 2026-08-13

**Documentation update: annotate superseded fable-roast-pass policy in three ADRs (gh361, Step 8 of #348 spec).** ADR-0013 removes the separate fable advisory dispatch for roast-work. This change adds inline annotations to ADR-0004, ADR-0006, and ADR-0010 marking the affected passages as superseded by ADR-0013, following the precedent of ADR-0004's "Cost claim superseded" marker. Annotations are positioned adjacent to the dead text (not in footers) for immediate visibility to a reader following the pointer chain from `agents/reviewer.md` to ADR-0004's heavy-unit trigger.

### Changed
- **ADR-0004 (line 34):** Added marker after "Task-master tags heavy units" noting that the separate fable advisory pass is superseded by ADR-0013.
- **ADR-0006 (line 36):** Added marker after "Fable stays confined to" noting that the separate fable advisory dispatch is superseded by ADR-0013.
- **ADR-0010 (line 79):** Added marker after "A haiku-implemented unit satisfying the heavy criteria" noting that the separate fable advisory roast pass is superseded by ADR-0013.

### Notes
- No ADR body text was deleted; all changes are additions only.
- No new ADR numbers were allocated; the 0007 hole remains untouched.
- The roast-work advisory-only property (ADR-0004 Tension 1) and all other ADR content remain unchanged; only the specific passages about the fable dispatch are annotated.

## [0.31.29] - 2026-08-13

**Security fix: only the orchestrator (the main session) may spawn the `reviewer`.** A confirmed, twice-observed pattern: an `Agent` call dispatched to resolve a human escalation omitted `subagent_type`, defaulted to `general-purpose`, was refused the marker write by `reviewed-path-gate.sh`, and answered that refusal by spawning a nested `reviewer` to perform the write for it — a **self-authorized bypass**. Both occurrences were verified against the on-disk transcript store rather than taken on report (2026-08-11 gh134, where the nested `spawnDepth: 2` reviewer did write `.claude/reviewed/gh134.pass`; 2026-08-12 gh340, caught before any marker was written). The gh134 marker is well-formed and correctly transcribes a real human decision, so this was a process breach, not a forged verdict. Two layers ship together, because the evidence shows either alone is insufficient: `agents/orchestrator.md` already carried the prose instruction that occurrence 2 violated, and `general-purpose` loads none of this project's persona instructions, so an instruction-level rule is structurally unreachable for it.

### Fixed
- **Caller allowlist in `reviewer-route-gate.sh`.** A `reviewer`-targeted dispatch is now admitted only from the main session: an empty `agent_type` (`settings.json`'s `.agent` unset) or `orchestrator` (with it set, which ADAPT always does). Written as an allowlist rather than adding `general-purpose` beside the existing `lead-programmer` block, because a blocklist would have to enumerate every generic identity forever (`Explore`, `claude`, any future built-in) and would still leave `spec-master`, `scribe` and friends able to spawn the reviewer — all measured at exit 0 before this change. The invariant is positive, so the gate encodes it positively. The pre-existing `lead-programmer` branch is kept and evaluated first, so its tailored message and behaviour are preserved byte-for-byte and the allowlist is purely additive.
- **This gate site deliberately fails CLOSED**, inverting the liberal-matcher convention that `lib/agent-identity.sh` documents for gate sites (where a miss must fail open). Recorded in the hook's header comment so a later reader does not "correct" it back. The blast radius is bounded: the closed direction applies only when the dispatch target is `reviewer`, and non-reviewer targets are unaffected. Deadlock is unreachable by construction — allowing both main-session forms covers every shipped configuration, and `orchestrator` is a core persona that can never be deselected.
- **The refusal is instructional, not just a denial**, matching the house style set by `human-decision-gate.sh`: it names the likely root cause (an `Agent` call with no `subagent_type`), states that spawning a reviewer to perform a blocked write is a self-authorized bypass, and points at report-and-wait per "Blocked by a gate you do not own".
- **`agents/orchestrator.md`'s escalation step 4 now names the literal `subagent_type: reviewer` parameter**, alongside the defaulting failure mode it prevents and the general rule that review-adjacent work is never dispatched to an untyped or generic agent. The step's existing substance is unchanged (first non-blank line `Unit: <task-id>`, body naming only the standing escalation's DECISION file, never relaying the decision). This is the complementary clarity layer — it keeps the orchestrator from tripping the new gate, rather than being the thing that stops the bypass.

### Added
- `tests/reviewer-route-gate-caller.test.sh`, wired into `tests/validate.sh`: an eight-row caller/exit-code table asserted against the real hook, plus a non-reviewer-target case, preservation of the original `lead-programmer` message, and the new message's instructional content. The first row is proven non-vacuous — `general-purpose` → `reviewer` exits 0 before the fix.
- A **reviewer-dispatch caller allowlist** entry in `CONTEXT.md`, cross-referencing **self-authorized bypass**, the **default-unnamed dispatch rule** (which governs `name:`, not the caller), and **The Writer/Reviewer split**. No ADR: this hardens an existing invariant rather than deciding a new one.

### Notes
- `SendMessage` to an existing reviewer teammate in agent-teams mode remains out of scope by design (a different tool with a different payload shape; neither confirmed occurrence used it), as does extending `dispatch-hygiene.sh` to refuse any untyped `Unit:`-shaped dispatch. Both are recorded as explicit deferrals.
- The `PreToolUse` payload carries no `spawnDepth` or `parentAgentId`; those exist only in the harness's transcript metadata that `scripts/agent-audit.sh` reads post-hoc for finding A3. Prevention needs neither — a nested spawn is fully identified by caller identity alone. Detection already worked; what was missing was prevention.

## [0.31.28] - 2026-08-13

**Security fix: `bin/cli.js --update` now propagates hook scripts and their registrations, so an already-installed standalone project actually receives gates added after it was installed.** `--update` — the zero-token resync path `/antislop:update-antislop` runs — refreshed persona files and protocol documents only. `buildFileSpecs()` listed no hook script at all, and `runUpdate()` touched `hooks` only to *strip* duplicate registrations under `--dedupe-hooks`, so a standalone install was frozen at its scaffold-time gate versions forever: it received neither new gates nor patches to existing ones, while `--update` truthfully reported its persona files current. Measured consequence: in a standalone install missing `human-decision-gate.sh`, `.claude/human-review/<task-id>/DECISION` — the human's exclusive channel for resolving an `ESCALATE-TO-HUMAN` verdict — is writable by any agent identity, defeating the human-in-the-loop escalation feature. Only the *upgrade* path was affected; a fresh scaffold and `--overwrite` always copied the scripts.

### Fixed
- **Hook scripts are now managed files.** `buildHookScriptSpecs()` enumerates every path under `hooks/scripts/**` (including `lib/`) from the packaged directory at runtime rather than from a hardcoded list, so a hook added later propagates without editing a list. They join `runUpdate`'s existing per-file loop as `kind: 'raw'` specs: copied verbatim with the packaged file's mode (a restored gate that isn't executable is a gate that never fires), with no protocol inlining and **no version stamp** — an HTML comment is not shell syntax — so they are tracked by content hash alone. Deliberately kept out of `buildFileSpecs()`, whose other callers treat every spec it returns as a stamped, ADAPT-rendered mirror.
- **An absent hook script is created unconditionally; a diverged one respects the existing contract.** Absence has no user edit to protect. A script that is present, differs from the packaged version, *and* whose recorded `fileHashes` entry differs from its on-disk hash is reported as diverged and exits non-zero until `--accept=<path>` or `--keep=<path>` resolves it — the same contract persona files have had. Because hook scripts carry no stamp, the pre-scan compares their content against the packaged source, which is what lets a plain `--update` (no `--check`) see a stale gate at a matching `pluginVersion`.
- **Registration backfill.** A script that ships but was never registered sits inert, so `--update` merges the packaged `hooks.json` — rewritten to the standalone `${CLAUDE_PROJECT_DIR}/.claude/hooks/scripts` form — into `.claude/settings.json` via the existing `mergeNestedHooksJson`, which matches groups by matcher and dedupes entries within them. It runs before the version-match fast path, so a project already current on persona files still gets it. **Skipped entirely when the marketplace plugin is enabled** (reusing `detectMarketplacePlugin`, never a second detector): merging there would double-register every hook and reproduce the "Ran 2 stop hooks" defect the existing guard was built to prevent. Pinned by an adversarial test asserting the `hooks` key is untouched in that case.
- **A one-time bootstrap note now names the hook-script paths.** On the first `--update` after this change no hook script has a recorded `fileHashes` entry, so the existing backfill adopts each file's on-disk content as its clean baseline — which means a hand-edit predating this version is refreshed without a divergence prompt. Unavoidable (there is no earlier hash to compare against) and the same caveat the CLI already printed for personas, but it is now stated explicitly and lists the affected paths.

### Added
- `tests/cli-hook-propagation.test.js`, wired into `tests/validate.sh`: eight checks over the real CLI process (scaffold into a throwaway cwd with a throwaway `HOME`, so `detectMarketplacePlugin` can't pick up the dev box's own enabled plugin), covering restoration of deleted scripts, whole-directory byte-parity enumerated at runtime, file mode, registration backfill and its no-duplicate property, the marketplace guard, the diverged/`--accept`/`--keep` contract, and the bootstrap note.
- **A mirror-parity check in `tests/validate.sh`**, so the drift can never go silent again: `diff -rq hooks/scripts .claude/hooks/scripts` must exit 0 or the merge gate fails, naming the diverged paths and the one command that fixes them. Deletion of a mirror file was already *technically* caught before this, but only incidentally by `cli-backfill`'s F2 regression cases and only as two paragraphs of fixture-internal `--update` stdout that name neither the mirror nor the missing file — a failure mode that reads as an unrelated broken test. Divergence that F2 structurally cannot see (an orphan file present in the mirror but not in `hooks/scripts/`, which `--update` has no reason to delete) is now caught too.
- `.claude/hooks/scripts/` in this repo is regenerated to parity by the fixed `--update` itself (3 created, 4 stale files updated — `dispatch-hygiene.sh`, `reviewed-path-gate.sh`, `reviewer-route-gate.sh`, `stop-gate.sh`, each predating landed security fixes). Not cosmetic: the two `cli-backfill` F2 regression cases copy this working tree into a fixture, so the fix cannot be green here while the mirror it now manages is stale.

## [0.31.27] - 2026-08-12

### Changed
- **The rephrasing workaround is now scoped to the gate that actually sanctions it (issue #345, Step 2).** Documentation only — no gate's behaviour changes. `templates/persona-protocol.md` and `templates/persona-protocol-slim.md` told an agent blocked while writing a marker to author the document with a placeholder token "so the invoking command text never spells the path", attributing that constraint to a vague *marker-directory gate*. Two gates match that description and they are not interchangeable: `reviewed-path-gate.sh` **grants the reviewer an identity**, so rewording a command only avoids a text match on a path the reviewer is entitled to write, while `human-decision-gate.sh` **grants nobody**, so the same reword is a `self-authorized bypass`. Both protocol templates now name the script explicitly and carry the boundary sentence *never for `human-decision-gate.sh`*, pointing at the sanctioned marker-write template (0.31.26) as the legal alternative, with report-and-wait as the fallback. The same scoping is applied to the workaround comment in `hooks/scripts/lib/benign-command.sh` and to `reviewed-path-gate.sh`'s own deny message, so an agent reading the refusal that recommends the move is told in the same breath where it does not apply.
- **The glossary-avoided synonym `marker-directory gate` is gone from every source and mirror file.** `CONTEXT.md`'s **Gate** entry has always listed it under `_Avoid_` as a vague synonym for a named script; on 2026-08-12 that vagueness was the mechanism of a real incident, where an agent facing `human-decision-gate.sh` read generic advice written for `reviewed-path-gate.sh` and applied it. Both of `reviewed-path-gate.sh`'s copies (source and the shipped standalone one) now name the script in the empty-`file_path` message too. The one remaining occurrence in the repo is `.claude/reviewed/gh309.pass`, an immutable audit record, deliberately left alone.

## [0.31.26] - 2026-08-12

**Behaviour change: `human-decision-gate.sh` now recognises one sanctioned marker-write template, so a review marker whose body quotes the `DECISION` path verbatim is no longer refused.** The gate previously conflated "this command writes something" with "this command writes `DECISION`": any Bash command whose text contained both `human-review` and `DECISION` had to clear `command_is_provably_benign()`, which rejects every write to every target. The protocol *mandates* that a `human:` attestation quote `.claude/human-review/<task-id>/DECISION` verbatim inside a `.claude/reviewed/<task-id>.pass` marker, so writing a correct marker was structurally blocked. On 2026-08-12 a reviewer met that block by splitting the path across shell variables to defeat the substring scan, and then recorded that technique for future sessions — a `self-authorized bypass`, and the direct motivation for this fix.

### Fixed
- **The Bash-shape false positive (issue #345, Step 1).** `is_sanctioned_marker_write()` in `hooks/scripts/human-decision-gate.sh` accepts exactly one shape — `cat > <marker-path> <<'DELIM'`, with `>>` permitted — and is consulted **only after** `command_is_provably_benign()` has already declined, so the change is **strictly additive to the allow set**: nothing allowed before is newly denied. Four properties carry its safety. Only the first physical line is code and it must match the template end-to-end, so no leading command, pipeline, extra redirection or trailing operator rides along. The delimiter must be single-quoted, which is bash's own guarantee that the body is wholly inert — a body may contain `$(...)`, backticks, `>` and `;`, and the `DECISION` path itself, as pure data. The target must be a bare literal `.claude/reviewed/<id>.<suffix>` (`pass`/`fail`/`directed`/`blocked`/`escalated`) whose id charclass excludes `/` and `.`, so no traversal escapes the marker directory. And the **first** line equal to the delimiter must be the **last** line of the command — without which a body could close the heredoc early and have whatever follows execute as a second command.
- **The refusal message is now instructional rather than merely prohibitive.** It prints the sanctioned template literally, states the delimiter/target/terminator rules, keeps the existing `rm -rf .claude/human-review/<task-id>` guidance for discarding a resolved packet, and names splitting the path across shell variables as a `self-authorized bypass` **for this gate** — scoping that workaround to `reviewed-path-gate.sh`, which grants the reviewer an identity, where this gate grants nobody. A blocked agent's next move is now "do what the gate asks", not a judgment call; report-and-wait remains the fallback for anything the template cannot express.
- **The gate's own header no longer claims "Reads stay allowed."** Measured false: the shared lexer fails closed on *any* backslash, including one inside single quotes where it is inert, so a read containing one is denied. Left open deliberately — closing it means modelling backslash escapes in a lexer `reviewed-path-gate.sh` also depends on. The same correction is applied to `docs/plans/2026-08-11-human-decision-channel.md` (Step 1's claim, and R-B's blanket "accepted residual" posture, now withdrawn for the false-positive half only) and to `README.md`'s Known-limitations section.

### Added
- **`tests/human-decision-gate.test.sh` is now behind the merge gate (Constitution P5).** It had **zero** references in `tests/validate.sh` — a security hook's suite outside the merge gate. Now wired in, and extended from 10 cases to 34. The pre-existing cases a–j are kept byte-identical: they are the evidence that the allow-set change is additive. N1–N5 cover the template (both operators, an inert body, and the `.fail`/`.directed` targets); N6–N20 are the invariant, every one of them measured as already-denied *before* the recognizer existed, so they pin behaviour rather than describe it; N21 pins the split-variable residual as deliberately **allowed**, so closing it later is a visible decision rather than an accident; N22/N23 assert the refusal message's content.
- **N6b, found by mutation testing.** The headline P7 attack (early heredoc terminator, second command writes `DECISION`) was denied by the *last-line* rule alone, because its final line is the second command — so it never exercised the early-terminator guard, which was effectively untested. N6b repeats the delimiter at the end so the last line still looks like a terminator; only "the **first** line equal to the delimiter must be the last" rejects it. Deleting that guard flips N6b to allowed, verified by mutation; N6 alone stays green either way.

## [0.31.25] - 2026-08-12

### Fixed
- **Mirror drift on `agents/agent-auditor.md` (issue #340, plan Step 11).** Commit `c6ac6e9` (gh290) edited the source persona file's "benign classes" and "full per-persona model-dispatch distribution" prose but did not regenerate `.claude/agents/agent-auditor.md` or bump the version — a Constitution P3 violation that left `tests/validate.sh` RED via `tests/cli-backfill.test.js`'s F2 regression check. This release's version bump forces `node bin/cli.js --update --check` to re-render the mirror under the new stamp (a same-version `--update` takes the fast "already current" path and would not have re-rendered it). No content decision was made — `agents/agent-auditor.md` itself is unchanged by this entry; only the mirror and `fileHashes` catch up to it.

## [0.31.24] - 2026-08-11

### Added
- **Institutional knowledge for human-in-the-loop and microworld bundles (issue #138, Step 8b).** Scribe documentation for the human-review feature: `CONTEXT.md` glossary entries for `Microworld`, `escalation packet`, `ESCALATE-TO-HUMAN`, `.escalated` marker, `.directed` marker, and `humanReviewMode`, with explicit contrasts (.escalated vs .blocked — reviewer lacked context vs. policy wants human eyes; microworld bundle vs escalation packet — gitignored scratch vs. durable snapshot). Two ADRs authored: `docs/adr/0018-human-in-the-loop-review-on-by-default.md` (on-by-default rationale and accepted costs; why not off-by-default, all, or off) and `docs/adr/0017-microworld-bundles-gitignored.md` (why bundles are working-tree scratch; the user's override of the original recommendation; the survivability gap and how escalation packets close it; accepted limitations R10 and R5). Wiki updated: `.claude/wiki/architecture.md` documents `.escalated` / `.directed` marker state machine and escalation packet lifecycle; `.claude/wiki/conventions.md` documents microworld bundle layout and gitignored-scratch status; `.claude/wiki/changelog.md` records that human review ships **on** at `critical` (the single most likely thing a downstream maintainer will need to look up after an update, per plan spec). **Fix pass (reviewer FAIL remediation):** the first gh138 build (commits `36a1cfb`/`81c197d`) appended near-duplicate glossary entries instead of amending the pre-existing ones in place; this pass merges each pair back into a single canonical entry and corrects several statements that had drifted from the live state (see below).
- **Record correction (post-FAIL fix pass, issue #138).** Commit `81c197d`'s diff to `.claude/persona-config.json` shows `humanReviewMode` flipping `off` → `critical`; that value change was **not** authored by gh138. The orchestrator had already set it to `critical` earlier in the same session while resolving the gh134 escalation (`docs/plans/2026-08-11-human-decision-channel.md` Step 4.7) but left it uncommitted; gh138's own G1 version-bump commit swept up that already-dirty field alongside its own `pluginVersion` bump. gh138 itself only intended to bump `pluginVersion`. `critical` is the correct, desired end-state and is unchanged by this note — only the historical attribution of that commit's diff is being corrected here, not the value itself.
- **ADR renumbered: 0007 → 0018.** The human-in-the-loop-review ADR was originally (mistakenly) written as `docs/adr/0007-human-in-the-loop-review-on-by-default.md`. The `0007` slot is a deliberately preserved hole (unit #260, see `docs/adr/0015-commit-anchored-pass-markers.md`) and must never be backfilled; the file has been renamed to `docs/adr/0018-human-in-the-loop-review-on-by-default.md` (0018 being the next free number, since 0017 was already taken by this same unit's other new ADR).

## [0.31.23] - 2026-08-11

**Behaviour change: an escalation decision now travels as a human-written `DECISION` file, never as a chat message relayed by an agent.** When a unit escalates, the human writes `.claude/human-review/<task-id>/DECISION` in their own terminal — `human-decision-gate.sh` (0.31.20) blocks every agent identity, the reviewer included, from creating it — and the reviewer reads, verifies and **transcribes** it. Telling the orchestrator "approve it" in chat no longer resolves an escalation, and the personas now say so explicitly: *a decision relayed in the dispatch prompt or any chat message is never a substitute for the DECISION file.*

### Added
- **Human-decision routing: the three routes and the `.directed` marker (issue #136, Step 7; amended by `docs/plans/2026-08-11-human-decision-channel.md` Step 3).** `templates/persona-protocol.md` gains a subsection under the existing `## Fourth verdict: escalate-to-human` header — deliberately a `### ` subsection, so no new parity-map entry is needed and `tests/adapter-protocol-parity.test.js` stays green. It specifies: the `DECISION` file's first-line format (`DECISION <task-id> <UTC ISO-8601> route: approve|reject|direct escalation: <timestamp>`, second line `by: <name>`), the **staleness binding** — `escalation:` repeats the standing `.escalated` marker's own first-line timestamp, so a decision left from an earlier escalation of the same unit cannot resolve a later one — the reviewer's four-point verification (file exists, first line parses, task-id matches, timestamp matches) and its **transcribe-never-re-review** duty, and the three terminal routes with their asymmetric cap accounting. Ported in condensed form to `adapters/cursor/rules/persona-protocol.mdc` and `adapters/codex/agents-md-fragment.md`.
- **Cap asymmetry, stated where it is acted on.** *Reject with reason* writes `.fail` with the human's reason verbatim as the defect list and **consumes** a 2-FAIL-cap slot; *fixable a specific way* writes `.claude/reviewed/<task-id>.directed` (first line exactly `DIRECTED <task-id> <UTC ISO-8601 timestamp> fix: <one-line human directive>`, then the prescribed fix verbatim) and **does not consume** one — a human-directed correction, not the writer failing its own attempt, the same logic that spares `INSUFFICIENT-CONTEXT`. The counting rule itself is unchanged (it counts `.fail` records only); `agents/task-master.md` just gains the explicit statement that `.directed` is not a FAIL and must not be read as durable evidence for a model-tag bump. `.directed` keeps having **no** `stop-gate.sh` branch — that omission is load-bearing, since the flags clearing is what lets the directed fix be dispatched, and `tests/stop-gate-escalated.test.sh` case (e) still pins it.
- **Surface, never decide (`agents/orchestrator.md`).** The orchestrator surfaces the marker verbatim plus the packet's `run.sh` command and the `DECISION` command template, re-reading the marker with the ungated Read tool whenever the human returns — possibly in a later session, since the packet is untracked-but-persistent. It **never runs `run.sh`, never pre-digests its result, never writes `DECISION`, and never offers to**; the resolution dispatch names only the unit and relays no decision. On a `.directed` marker it dispatches `lead-programmer` with the directive and routes back for re-review. All new prose uses `(if present)` phrasing for the opt-out `reviewer` persona (G3), so `tests/validate.sh`'s paragraph-scoped conditional-phrasing check stays green.
- `agents/reviewer.md` gains the resolution bullet (verification steps, the three routes, and the mandatory `rm -rf .claude/human-review/<task-id>` that deletes `.escalated` and the packet — including the decision file — in the same action, since no identity may `rm` it by name). `agents/lead-programmer.md` gains the rule that a `.directed` dispatch carries a human's prescribed fix to apply exactly, never to re-plan around. The unattended/CI path is documented as-is: `.escalated` simply stands, turn-end stays blocked, and the only way through is the **existing** `defer:`/`skip:` escape hatch — with `skip:` leaving **both** the marker and the packet standing, the fail-safe direction.

## [0.31.22] - 2026-08-11

**Behaviour change, on by default: critical units will now block turn-end until a human decides.** From this version, a review that would have PASSed is instead escalated to you when the unit meets the heavy-unit trigger — the reviewer writes an escalation marker and turn-end stays blocked until a human resolves it. This applies to **every already-adapted project on its next update**, without you editing anything, because an absent `humanReviewMode` key resolves to `critical`. **Set `"humanReviewMode": "off"` in `.claude/persona-config.json` to restore the previous behaviour** (fully automatic PASSing). This is a deliberate, informed tradeoff chosen over an off-by-default opt-in, to slow down hyperscaling-by-default; it is not an oversight.

### Added
- **`humanReviewMode` config field, defaulting to `critical` (issue #135, Step 6).** `templates/persona-config.schema.json` gains the field (`enum: ["off","critical","all"]`, `default: "critical"`) with a description stating plainly that an absent key resolves to `critical` and that `off` is the explicit opt-out. `bin/cli.js`'s **fresh-install skeleton only** writes `humanReviewMode: 'critical'`; the `existingPersonaConfig` branch is deliberately left untouched, so an already-adapted project never receives the key. That is why the shipped default is encoded as an **absent-key fallback in the consumer** — `agents/reviewer.md` now states that it reads `humanReviewMode` from `.claude/persona-config.json` and that an absent key **and any unrecognised value** both resolve to `critical` (fail toward escalation, never toward silent auto-approval); only `off`, spelled exactly, disables it. Encoding the default in the `--update` backfill instead would have been the single most likely way to ship "on by default" that is silently off for every existing user. Also stated explicitly in `agents/reviewer.md`: in a project that selected no `reviewer` persona the whole escalation path is inert whatever the mode says, since only the reviewer writes the `.escalated` marker — structural, not a gap. Two new cases in `tests/cli-backfill.test.js` pin the pair: a fresh install carries `"humanReviewMode": "critical"`, and an existing config **without** the field is left without it across `--update` (seeded with a stale version stamp so the run genuinely rewrites the config rather than passing on the version-match fast-path; a mutation control inserting a backfill into `runUpdate` flips that case to FAIL, so it binds). No stop-gate change: Step 5's gate is marker-driven and mode-independent by design, so there is no hook-side read to give a fallback. `README.md` documents the three values, the on-by-default posture and its rationale. This repo's own `.claude/persona-config.json` deliberately keeps `"humanReviewMode": "off"` for now — a temporary, documented bootstrap window (`docs/plans/2026-08-11-human-decision-channel.md` Step 4) held open until the human-decision resolution channel lands, so this fix batch's own units cannot escalate into a route that does not yet exist.

## [0.31.21] - 2026-08-11

### Fixed
- **Escalation-laundering hole in `reviewed-path-gate.sh`'s no-reviewer fallback closed (issue #326, Step 2).** Previously, when `agent_type` was empty (main session) and `personaSelection` lacked `reviewer`, the fallback exited 0 unconditionally for any `.claude/reviewed/` write, including one that would resolve a standing `.escalated` marker with zero human artifact — deselecting the reviewer persona was enough to silently discard a pending escalation. The branch now globs `.claude/reviewed/*.escalated` before its `exit 0`; if any marker stands, it blocks (`exit 2`), naming the DECISION channel (`hooks/scripts/human-decision-gate.sh`, issue #325) as the route that resolves an escalation and a human's own terminal as the only other legitimate route. With no `.escalated` marker standing, the fallback is unchanged. New test cases (j)-(n) in `tests/reviewed-path-gate.test.sh`: (j) a Write into the marker dir is blocked with a standing escalation, (k) an `rm` of the marker itself is blocked, (l) the fallback still allows a write when no escalation stands, (m) reads of the marker stay allowed, (n) the reviewer's grant is unaffected. `bash tests/reviewed-path-gate.test.sh` and `bash tests/validate.sh` both pass.

## [0.31.20] - 2026-08-11

### Added
- **`human-decision-gate.sh`: DECISION is agent-unwritable, no grant branch (issue #325, Step 1).** New PreToolUse hook, registered for both the `Write|Edit` and `Bash` matchers in `hooks/hooks.json`, that blocks **every** agent identity — reviewer included, empty/main-session `agent_type` included — from writing `.claude/human-review/<task-id>/DECISION`, the human's own resolution of a pending `ESCALATE-TO-HUMAN` packet. Unlike `reviewed-path-gate.sh`, there is no grant branch and no no-reviewer fallback: no identity may ever write this file. Reads stay allowed. Write/Edit path normalizes `file_path` via `normalize_path()` and blocks iff the basename is exactly `DECISION` under `human-review`; Bash path uses a substring early-exit on `human-review` and `DECISION` both present, then allows only if `command_is_provably_benign()` finds the command read-only or text-only. Every block appends a `decision-gate-denied identity=<sanitized>` line to `.claude/review-audit.log`, reusing `_identity_sanitize()` from `lib/agent-identity.sh`. The gate's header names `rm -rf .claude/human-review/<task-id>` as the sanctioned way to discard a resolved packet — its command text never spells `DECISION`, so it clears the substring early-exit and is never routed through the benign-command check at all; a per-file `rm .../DECISION` is blocked for every identity, including the reviewer, by design. No adapter port, same precedent as `reviewed-path-gate.sh`. New `tests/human-decision-gate.test.sh` covers cases (a)-(j): Write/Edit blocked for reviewer/empty/orchestrator identities, allowed for a non-`DECISION` file in the same directory, blocked through a `../` normalization bypass attempt; Bash `printf > DECISION` blocked for all three identities, `cat DECISION` allowed (reads), a heredoc mentioning both substrings blocked (lexer fails closed), `rm -rf` of the whole packet directory allowed (sanctioned deletion path), and an audit-log assertion that a blocked write logs `decision-gate-denied identity=antislop:reviewer`. Both `tests/human-decision-gate.test.sh` and `tests/reviewed-path-gate.test.sh` pass.
- **Shared benign-command lexer extracted to `hooks/scripts/lib/benign-command.sh` (issue #325, Step 1).** The six lexer functions (`program_allowed`, `command_skeleton`, `mask_inert_redirections`, `segment_allowed`, `command_is_provably_benign`, `normalize_path`) moved verbatim out of `reviewed-path-gate.sh` into the new lib file, sourced the same way `lib/agent-identity.sh` already is, so `human-decision-gate.sh` can reuse the identical implementation rather than a second copy. Mechanical only — `reviewed-path-gate.sh`'s own behavior is unchanged and `tests/reviewed-path-gate.test.sh` passes with zero assertion changes.
- `hooks/scripts/human-decision-gate.sh` and `hooks/scripts/reviewed-path-gate.sh` added to `.claude/persona-config.json`'s `protectedPaths`. README.md's "Known limitations" section gains a paragraph on the new gate's Bash-path obfuscation residual (same framing as the existing `reviewed-path-gate.sh` caveat), noting the narrower blast radius since this gate has no grant branch at all.

## [0.31.19] - 2026-08-11

### Added
- **`.escalated` marker enforcement in the turn-end gate (issue #134, Step 5).** The reviewer-`SubagentStop` branch of `hooks/scripts/stop-gate.sh` now globs `<dot-dir>/reviewed/*.escalated` alongside `*.blocked`, with identical flag-keeping semantics and a **distinct** audit token `verdict=escalated flags-kept`. Without it, Step 4's `ESCALATE-TO-HUMAN` verdict was prose only: nothing stopped turn-end or the next gated dispatch, so the human never got a chance to look. The two globs are evaluated and logged **independently** (two `if`s, not an `if/elif`), so a unit blocked and another escalated in the same reviewer turn both appear — keeping "the reviewer lacked context" and "policy wanted human eyes on critical code" distinguishable in `.claude/review-audit.log` after the fact. `.blocked` behaviour, its token and its ordering are unchanged; the combined check exits 0 once either glob matched. `.directed` (Step 7) is **deliberately** absent from both globs — the flags clearing is exactly what lets the human-directed fix be dispatched, so globbing it would deadlock the route it exists to open; stated in each script's header-comment logic list so a future reader does not "fix" the omission. `hooks/scripts/reviewer-route-gate.sh` needed no change (it keys off `.pending-review.*`, so kept flags block the next dispatch automatically) — asserted by test, not assumed. Hand-ported into `adapters/cursor/hooks/scripts/stop-gate.sh` and `adapters/codex/hooks/scripts/stop-gate.sh` in each port's own style (the codex port reaches `allow()` only after both tokens are logged, so neither is skipped by the loop-guard-resetting early exit). No stop-gate reads `humanReviewMode`: the gate is marker-driven and mode-independent by design. New `tests/stop-gate-escalated.test.sh` (registered in `tests/validate.sh`) executes the real hooks with canned hook-input JSON per constitution P1: (a) an active `.escalated` marker keeps the pending-review flag standing and logs the token, (b) both markers present log both tokens, (c) no markers still clears and logs `cleared-by=reviewer`, (d) with `.escalated` standing an orchestrator→lead-programmer dispatch through the unmodified route gate exits 2, (e) a `.directed` marker **alone** clears the flags, (f) mutation control — with the `.escalated` glob neutralised in a throwaway copy the flag clears again, so (a) binds to the new branch, (g) both adapter ports driven through their own payload shapes. Known limitation carried forward unchanged from `.blocked` (R5): writing `skip: <reason>` into a flag deletes the flag but not the marker, so a stale `*.escalated` keeps flags standing at the next reviewer stop — it fails safe (over-blocks, never under-blocks) and clears when the reviewer resolves the unit; documented in Step 8a, not fixed here.

## [0.31.18] - 2026-08-10

### Added
- **Microworld dashboard documentation in README.md (issue #322, Step D9).** Add "Microworld dashboard" section under "Using AntiSlop" documenting what the dashboard is, how to start it (`node bin/cli.js --dashboard`), that it binds to loopback only (127.0.0.1), requires the printed token, writes nothing, has ephemeral in-page cells lost on refresh, states "each cell runs in a fresh process", documents that cells share no state and the dashboard is never a gate. Document feedback block shape and that `location` is authored by lead-programmer. Extend "Known limitations" with dashboard-specific items: token visibility (accepted tradeoff), bundle verification (working artifacts, not source truth), and line number staleness (mitigated by commit SHA in block). State explicitly that no new `.gitignore` entry is needed for the dashboard since it writes nothing, coordinating with #131. Packaging assertions verified without edits: `bin/dashboard/` ships because `files` in package.json contains `bin`; `validate.sh`'s npm-pack included/excluded lists require no change.

## [0.31.17] - 2026-08-10

### Added
- **Microworld dashboard escalation packets as second read source (issue #321, Step D8).** Dashboard discovery now enumerates `.claude/human-review/*/` as escalation packets with `source: "packet"` and id namespaced as `packet:<task-id>` (distinct from `working:<unit-slug>` working bundles by D2's design). Packets appear in a **separately labelled section** in the left rail ("Working Bundles" and "Escalation Packets" headers) and are never interleaved with working bundles. Each packet's `status` is always `null` even if an audit log entry exists for that unit (packets are snapshots, not live). Dashboard never reads `humanReviewMode` config field or any escalation-decision marker file — escalation packets are discovered and rendered as a pure second read location by filesystem enumeration, inheriting reachability from the escalation-packet directory's siting outside the reviewer-owned marker-directory gate. Packets are fully invocable via `POST /api/invoke` with the same manifest/function/input contract as working bundles; invocation resolves bundle paths to `.claude/human-review/<task-id>/` instead of `microworlds/` based on the `source` field. New test suite `tests/dashboard-packets.test.js` with five test cases: (a) fixture packet appears in discovery with correct source and id namespacing, (b) working bundle and packet for the SAME unit slug both appear with distinct ids (the collision case), (c) packet status is always null even with a real audit-log entry present for that unit (proved by asserting the co-located working bundle DOES pick up the status), (d) packet function invocation works and resolves to packet directory (not microworlds), (e) graceful handling of missing escalation-packet directory. Register test in `tests/validate.sh`. Asserted via grep: zero `humanReviewMode` references in `bin/dashboard/`, zero escalation-marker references, `git status --porcelain` byte-identical before/after packet discovery and invoke cycle. No runtime npm dependencies (G4); no changes to `bin/dashboard/invoke.js` or `bin/dashboard/audit-log.js` required.

## [0.31.16] - 2026-08-10

### Added
- **Fourth verdict `ESCALATE-TO-HUMAN` + durable escalation packet (issue #133, Step 4).** New canonical `## Fourth verdict: escalate-to-human` section in `templates/persona-protocol.md`, sited immediately after `## Third verdict: insufficient-context`, with condensed hand-ports into `adapters/cursor/rules/persona-protocol.mdc` and `adapters/codex/agents-md-fragment.md` and `{probe}` entries in both parity maps (R3). Verdict precedence is stated explicitly — `FAIL` > `INSUFFICIENT-CONTEXT` > `ESCALATE-TO-HUMAN` > `PASS` — because a fourth verdict makes ordering ambiguous: escalation is a **gate on PASS**, never a replacement for FAIL (a real defect is a plain FAIL; an unverifiable criterion is INSUFFICIENT-CONTEXT), so only a unit the reviewer *would have passed* escalates. Trigger: `humanReviewMode` is `all`, or is `critical` (an absent key reads as `critical`) and the unit meets the heavy-unit trigger — referenced **by pointer** to `docs/adr/0004-reviewer-roast-work-dual-model-routing.md` § "Heavy unit trigger" (as amended by ADR-0013) and deliberately **not** restated, so a later amendment cannot leave two copies disagreeing (`grep -c 'impacted files' templates/persona-protocol.md` is 0). Marker `.escalated` under the reviewed-markers directory carries a byte-exact first line (`ESCALATE-TO-HUMAN <task-id> <ts> trigger: <criterion> microworld: <packet path or "none">`) followed by the packet's `run.sh` invocation, `commit: <sha>`, an inputs/expected-outputs line, the would-be verdict and criteria checked, and non-blocking notes. In the **same action** the reviewer snapshots the unit's bundle to `.claude/human-review/<task-id>/` (executable bit on `run.sh` preserved) plus `PACKET.md`, a byte-identical copy of the marker body with the marker authoritative wherever the two differ (R11); a unit with no bundle still gets a packet directory with `PACKET.md` alone and `microworld: none` — escalation is never skipped for want of a bundle. The packet sits outside the reviewed-markers directory on purpose: `hooks/scripts/reviewed-path-gate.sh` blocks execution of any Bash command whose text merely contains that path for every non-reviewer caller, so a packet sited there would be unrunnable by the orchestrator or by a human — stated in the protocol text so a future reader does not "tidy" it there. Untracked, so `git clean -fdx` or a fresh clone destroys a pending escalation unrecoverably (R10) — documented, not fixed. Distinct from `.blocked` (reviewer *lacked context* vs. policy wants *human eyes on critical code*): separate marker files, separate audit-log tokens. `.escalated` never consumes a 2-FAIL-cap slot. Resolution is always the reviewer's, on a later re-dispatch carrying the human's decision, via one of Step 7's three terminal transitions, each deleting `.escalated` and its packet as part of writing the successor. `agents/reviewer.md` gains a matching "On ESCALATE-TO-HUMAN (both modes)" bullet and its verdict list grows from three to four; `templates/protocol-digest.md`'s existing "Review ownership" bullet is amended **in place** (27 lines, pre-change 26 — no new bullet). Consequential to the new canonical section, `bin/cli.js`'s `PROTOCOL_SECTIONS_BY_PERSONA` matrix classifies it in all six full-tier rows, mirroring the Third-verdict classification exactly (included for `orchestrator` and `reviewer`, dropped for the other four) — the matrix is exhaustive by assertion, so a new section cannot land unclassified. No `humanReviewMode` config surface is added here (Step 6); the field is referenced by name in protocol prose only.

## [0.31.15] - 2026-08-10

### Added
- **`.gitignore` reach for microworld bundles and escalation packets (issue #131, Step 3a).** `microworlds/`, `<adapter-root>/human-review/` and `<adapter-root>/microworld-audit.log` are now ignored in four places, not one: this repo's own `.gitignore`, and all three `bin/cli.js` scaffold `appendUnique` lists (`.claude/`, `.cursor/`, `.codex/` — `microworlds/` is project-root and therefore identical across all three; only the two dotted paths carry the adapter prefix). Closing **R9**, `runUpdate` also gains its own idempotent `appendUnique` call for the claude-side lines, sited alongside the existing `migrateGlobalProtocolImport` fixup: previously `runUpdate` called none of the scaffold lists, so a rule added only at scaffold time would never have reached an already-adapted project, which would then have seen bundles and escalation packets as untracked noise in `git status` and plausibly committed them — silently reinstating the "committed bundles" outcome the user explicitly overrode on 2026-07-28. New `tests/cli-backfill.test.js` case drives the `runUpdate` path against a fixture project whose `.gitignore` lacks the rules: asserts each line lands as its own line, asserts every pre-existing line survives unmodified and unreordered (exact-prefix check), and asserts a second `--update` leaves the file byte-identical. Acceptance greps: `git check-ignore -q microworlds/x/run.sh` exits 0, `grep -c '^microworlds/$' .gitignore` is 1, `grep -c 'human-review' .gitignore` is 1, `grep -c "'microworlds/'" bin/cli.js` is exactly 4 (a value of 3 would mean `runUpdate` was skipped). Must land before Step 4, whose escalation-packet criterion `grep -q 'human-review' .gitignore` asserts exactly that ordering.

## [0.31.14] - 2026-08-10

### Added
- **Microworld dashboard feedback primitives (issue #320, Step D7).** Add source excerpt reader `GET /api/source` (bounded, root-confined, anti-traversal proof), context endpoint `GET /api/context` (returns git HEAD sha), free-text per-function/per-cell comment box (ephemeral, browser-tab only), and "Copy feedback" button for exporting a fixed-shape markdown feedback block. New modules: `bin/dashboard/source.js` (read-only excerpt reader, 400 on path traversal, 404 with stated reason on file/line errors, line-count cap e.g. 400 lines), `bin/dashboard/feedback-block.js` (pure formatter taking context object and producing exact markdown shape for LLM parsing). Edit `bin/dashboard/server.js` to add both endpoints with existing token-auth contract (401 with no token). Edit `bin/dashboard/index.html` to add excerpt pane (auto-fetched via `/api/source` if location exists), comment textarea, copy button, and clipboard mechanics: `navigator.clipboard.writeText` primary path with `<textarea>` + `document.execCommand('copy')` fallback (unverifiable browser behavior over plain HTTP, so fallback is required). Feedback block markdown shape: `## Microworld feedback — <unit-slug> / <function label>`, metadata lines (function id, group, location or "location: not declared", git sha, bundle path), `### Comment` section (verbatim), optional `### Last run` section (cells only, never emitted with empty fields). Add comprehensive test suite `tests/dashboard-feedback.test.js` with thirteen acceptance criteria (a)-(m): (a) `/api/context` returns correct git HEAD sha, (b) `/api/source` with valid location yields exact declared line range, (c) PATH-TRAVERSAL proof (relative `../../etc/passwd` and absolute `/etc/passwd` each return 400), (d) nonexistent file and out-of-range lines return 404 with stated reason, (e) endLine beyond cap returns at most capped lines, (f) both endpoints return 401 with no token, (g) formatter reproduces comment with backticks and fenced code block byte-for-byte, (h) function with no location produces "location: not declared", (i) function vs cell: no "### Last run" for function, present for cell, (j)-(m) are mutation-proved validation tests for the fixes applied in the second review. Register test in `tests/validate.sh`. Asserted via grep: `navigator.clipboard` and `execCommand` present in index.html, no write operations in `source.js`, no `handoff` references anywhere under `bin/dashboard/`, `git status --porcelain` byte-identical before/after full annotate-and-copy cycle. No runtime npm dependencies (G4).

### Fixed
- **Step D7 FAIL-verdict fixes (issue #320).** The initial implementation shipped in this release had 6 real defects against a reviewer FAIL: (1) security — `/api/source`'s path-containment check was purely lexical (no `fs.realpathSync`), so a symlink inside the project root pointing outside it was followed and its contents leaked via HTTP 200 (live violation of plan guardrail 6); (2) `endLine < startLine` silently returned HTTP 200 with an empty result instead of a stated-reason 404 (plan explicitly forbids "a silent empty one"), reachable from the shipped client's default endLine=100; (3) only one function-scoped comment box existed (hardcoded singleton id); the plan required "per function AND per cell" with per-instance ids, and the rule "`### Last run` appears only when copying from a cell" was inverted; (4) `feedback-block.js` (the issue's named pure formatter) was dead code — `index.html` re-implemented the markdown shape inline instead, and the two implementations had already diverged; (5) no truncation marker was emitted for a truncated cell result, contradicting the plan's fixed block shape; (6) CHANGELOG/commit message falsely claimed a working per-cell comment box. Per haiku-escalates-on-first-FAIL policy, re-dispatched on sonnet (commit `26a0191`). Fix pass: real `fs.realpathSync.native` containment check for (1); stated-reason 404 for (2); genuine per-cell comment boxes with per-instance ids for (3), with corrected `### Last run` scoping (cell-copy only); server-side injection of `feedback-block.js`'s real source into the served page for (4) (one implementation, not two); explicit `*(output truncated)*` marker for (5); (6) became true once (3) was genuinely fixed. Added test cases (j)-(m), each mutation-tested (revert → red with the original symptom → restore → green). Second review PASSed on commit `26a0191` (mandatory opus tier due to prior FAIL), independently re-verifying all 6 fixes including a live 3-cell drive confirming the "THAT cell, not the last cell" per-cell isolation property. FAIL-cap: 1-of-2, resolved.

## [0.31.13] - 2026-08-10

### Added
- **Microworld dashboard notebook feature (issue #319, Step D6).** Add client-side in-memory notebook to track execution history of `POST /api/invoke` invocations as cells, each storing `{ cellId, functionId, inputs, startedAt, result }`. Cells are appended on each invocation (re-running never overwrites). Each cell renders with three controls: edit-and-re-run (prefills input form from cell's recorded inputs without needing to re-fetch manifest), collapse/expand (inline), and remove. Cell state persists in-memory while switching tabs away and back but is lost on page refresh (guardrail 5, by design — no localStorage/sessionStorage/indexedDB). Add required UI text warning "each cell runs in a fresh process" to clarify that cell executions are independent (Cell 2 cannot see variables from Cell 1). Add comprehensive test suite `tests/dashboard-notebook.test.js` with five cases: (a) fresh-process proof via PID (two invocations get different PIDs), (b) no-shared-state proof via counter (value always same, never increases across cells), (c) route table unchanged from prior steps (no new server endpoints added), (d) GET / still returns 200 and references /api/invoke, (e) real client-side test driving the actual inline `<script type="module">` via `vm.createContext` against a stub DOM, asserting fetch called with /api/invoke and correct body, cell appended per invoke, second invoke appends SECOND cell (not overwrite), post-invoke listener rewiring, and collapse toggle works both directions. Server implementation is zero-diff: no edits to `bin/dashboard/server.js`, `discover.js`, `audit-log.js`, or `invoke.js` — notebook feature is pure client-side. Register test in `tests/validate.sh`. No runtime npm dependencies (G4).

### Fixed
- **Step D6 FAIL-verdict fixes (issue #319).** The initial implementation shipped in this release had 4 real defects against a reviewer FAIL: (1) temporal-dead-zone `ReferenceError` on every "Run" click — duplicate `const inputs = {}` declaration after its own use inside `invokeFunction()` meant the invoke call was NEVER made and no cell was ever created (total regression of D4/D5 feature); (2) collapse/expand was dead (`isCollapsed` ternary evaluated to `false` for all inputs); (3) cells had no event listeners wired (missing `attachCellEventListeners()` call after re-render); (4) test suite exercised zero client-side JS (`vm` imported but never used), which is exactly why defects 1-3 passed the original acceptance criteria. Per haiku-escalates-on-first-FAIL policy, re-dispatched on sonnet. Fix commit `1b331b7`: collapsed the duplicate input-collection into a single pass reused by the invoke call (removing the shadowing declaration entirely); fixed collapse boolean to `cell.collapsed === true`; added missing `attachCellEventListeners()` call after `invokeFunction()`'s re-render; added real client-side test (e) using the same `vm.createContext` pattern already proven in `tests/dashboard-client.test.js`. All three code fixes individually mutation-tested (reverting each one, one at a time, turns test (e) red) by both the fix-pass lead-programmer and, independently, the second reviewer in its own throwaway worktree. Second review PASSed. FAIL-cap: 1-of-2, resolved on first fix attempt.

## [0.31.12] - 2026-08-10

### Added
- **Microworld dashboard browser client (issue #318, Step D5).** Add `bin/dashboard/index.html` as a static HTML file with inline JavaScript (no framework, no CDN, no build step) that provides a full browser UI for the microworld dashboard. Features left-rail bundle list with live status indicators (pass/fail/timeout/unknown), nested tabs for function groups and individual functions, dynamic input form generation supporting text/number/json/file input types with defaults and descriptions, and an output pane displaying invocation results with banners for timeout and truncation states. Empty state messaging explains what microworld bundles are when no bundles exist. Token-based authentication enforced via `X-Antislop-Token` header or `?t=` query parameter (same contract as existing `/api/bundles` and `/api/invoke`). Add comprehensive test suite `tests/dashboard-client.test.js` with four test cases: (a) valid token returns 200 with text/html, (b) HTML contains required `/api/bundles` and `/api/invoke` references, (c) no external script src attributes pointing outside origin, (d) requests without token return 401. Register test in `tests/validate.sh`. No runtime npm dependencies (G4).

### Fixed
- **Step D5 FAIL-verdict fixes (issue #318).** The initial `bin/dashboard/index.html` shipped in this release had 8 defects against a reviewer FAIL: the group tab tier was unwired (functions rendered flat, no nested tabs); the left rail never polled `/api/bundles` and so was not live; a function with no declared `inputs[]` had no Invoke button; `default` prefill JSON-quoted string/file values and dropped falsy defaults (`0`/`false`/`""`); the exit code was always shown in error-red styling regardless of value; a fetch/auth failure was indistinguishable from a genuinely empty bundle list; and the empty state didn't name what a microworld bundle is. Also hardened `escapeHtml` to escape `"` and `'` (previously only `& < >`), applied to the `data-*` attribute interpolations for bundle and function ids. Add `tests/dashboard-client.test.js` cases (e) and (f), executing the client's rendering logic against a stub DOM to prove group-tab and default-prefill behavior directly, closing the test-coverage gap the reviewer flagged as why these defects survived a green suite.

## [0.31.11] - 2026-08-10

### Added
- **Function invocation endpoint `POST /api/invoke` with injection-proof guardrails (issue #317, Step D4).** Add `bin/dashboard/invoke.js` exporting an async `invoke()` function that spawns a function entry via `child_process.spawn` with argv array and NO shell, writes human-supplied inputs as one JSON object on stdin (never on command line), kills on timeout via manifest `timeoutSeconds` (default 60), caps stdout/stderr at 1 MiB each, and returns `{ ok, exitCode, stdout, stderr, durationMs, timedOut, truncated }`. Concurrent invocations are independent. Edit `bin/dashboard/server.js` to add `POST /api/invoke` route with same token-auth contract as GET routes; validate `id` and `functionId` against discovered bundles, return 400 for unknown/disabled functions (no spawn on error), return 200 with result for all completion states (including non-zero exit). Add comprehensive test suite `tests/dashboard-invoke.test.js` with mutation-proof injection case (shell metacharacters delivered verbatim, never executed), timeout kill proof (pid check post-kill), 1 MiB truncation proof, concurrent invocation proof, auth 401 proof, and unknown-id 400 proof. Register test in `tests/validate.sh`. Asserted structurally and behaviourally: no `shell: true`, no `execSync`, no bare `exec()`. No disk writes during invocation (git status byte-identical before/after). No runtime npm dependencies (G1, G4).

## [0.31.10] - 2026-08-10

### Added
- **Live dashboard status by tailing audit log with cross-language contract test (issue #316, Step D3).** Add `bin/dashboard/audit-log.js`, a Node.js module that tails and parses `.claude/microworld-audit.log` emitted by `hooks/scripts/microworld-rerun.sh`, returning a map of most-recent status per unit. Absent or unreadable log yields empty map, never an error. Modify `bin/dashboard/discover.js` to load audit status and attach it to each bundle as a `status` field, and add `fs.watch` on `microworlds/` directory for live bundle discovery. Modify `bin/dashboard/server.js` to add `GET /api/status` endpoint (same auth contract as `/api/bundles`). Add cross-language contract test `tests/microworld-audit-contract.test.js`: executes the REAL hook against a fixture bundle whose check fails, reads the REAL audit line, parses it with the REAL parser, asserts correctness of `{unit, result, file}`, and includes mutation proof (changing the hook's emitted separator makes the test fail). Extend `tests/dashboard-server.test.js` with new cases (g) fixture audit log with 2+ lines per unit reports most recent, (h) no audit log → all bundles report `status:null`, (i) appending a line to the log is reflected in subsequent request without restart, (j) creating a new bundle directory is reflected without restart. Status liveness is provided by `discover()` re-reading the filesystem on every HTTP request, not by `fs.watch` event processing. Register new contract test in `tests/validate.sh`. Update header comment in `hooks/scripts/microworld-rerun.sh` stating that the audit line format is a consumed interface with the Node parser (`bin/dashboard/audit-log.js`) and naming the contract test (`tests/microworld-audit-contract.test.js`). No runtime npm dependencies; no logic changes to the hook itself (G1, G4, G5).

## [0.31.9] - 2026-08-10

### Added
- **Reactive microworld rerun hook (issue #132, Step 3b).** Add `hooks/scripts/microworld-rerun.sh`, a `PostToolUse(Edit|Write)` hook registered on the existing `Edit|Write` matcher after `graph-update.sh` and `lint-on-edit.sh`, so microworld breakage surfaces on the fly instead of only at review. It no-ops silently when the project has no `microworlds/` directory or when the edited path matches no bundle's `watch` globs, and otherwise re-runs each matching bundle's `run.sh` under its manifest `timeoutSeconds` (default 60), appending `<ts> unit=<slug> result=pass|fail|timeout file=<path>` to `.claude/microworld-audit.log`. It is a **reporter, not a gate**: exit 2 (stderr surfaced to the model) only when a matched bundle genuinely failed or timed out, while every infrastructure problem — absent `jq`, malformed `manifest.json`, missing `run.sh` — is logged and exits 0. The edited path is passed to `run.sh` as a positional parameter, never string-interpolated into an `eval`. Hand-adapted mirrors ship as `adapters/cursor/hooks/scripts/microworld-rerun.sh` (top-level `.file_path` off `afterFileEdit`, `.cursor/` audit log) and `adapters/codex/hooks/scripts/microworld-rerun.sh` (`.cwd`, sibling `tool_input` keys plus the `apply_patch` header fallback, `.codex/` audit log), both registered in their own hook manifests. Add `tests/microworld-rerun.test.sh`, which executes the hooks with canned hook-input JSON and carries the executable relocation proof — a bundle copied outside `microworlds/` exits with the same status as the original — that the escalation packet depends on. Register the test in `tests/validate.sh`.

## [0.31.8] - 2026-08-10

### Added
- **Microworld dashboard shell: CLI flag, HTTP server, discovery, token, empty state (issue #315, Step D2).** Add `--dashboard` and `--dashboard-port=<n>` CLI flags to `bin/cli.js` that start an HTTP server binding `127.0.0.1` only, printing the full URL with per-launch token on startup. Introduce `bin/dashboard/discover.js` to enumerate `microworlds/*/manifest.json`, reading `unit`, `description`, and `functions[]` from each; malformed JSON, missing manifests, missing/non-executable entries are marked `disabled: true` with a reason string (fail-soft always). Introduce `bin/dashboard/server.js` with routes `GET /` (placeholder HTML), `GET /api/bundles` (bundle list with auth); every request requires `?t=<token>` or `X-Antislop-Token` header (missing/wrong → `401`). Introduce `bin/dashboard/index.html` as a minimal placeholder showing an empty-state message when no bundles exist. Add comprehensive test suite `tests/dashboard-server.test.js` covering bundle discovery, authentication, error handling, concurrent servers, and feature graceful degradation. Register test in `tests/validate.sh`. No runtime npm dependencies (G4).

## [0.31.7] - 2026-08-10

### Fixed
- **Extend Microworld bundles section reach to spec-master and task-master (issue #314 advisory followup).** Move the canonical `Microworld bundles (format and the check contract)` section from the `drop` arrays to the `include` arrays for both `spec-master` and `task-master` personas in `bin/cli.js` — ensuring the section's normative "never an acceptance criterion" sentinel reaches the two personas that actually author acceptance criteria. Regenerate all three affected persona files (`.claude/agents/spec-master.md`, `.claude/agents/task-master.md`, `.claude/agents/reviewer.md`) via `--update`.
- **Remove garbled duplication in reviewer.md.** Remove redundant duplicate clause "never an acceptance criterion and **never an acceptance criterion**" in `agents/reviewer.md` so it reads once as intended.

## [0.31.6] - 2026-08-10

### Added
- **Microworld bundle format v2: canonical protocol section for `functions[]`, `location`, and terminology (issue #314, Step D1).** Add new canonical section `## Microworld bundles (format and the check contract)` to `templates/persona-protocol.md` defining the microworld bundle format (`manifest.json` with `functions[]`, the `entry` execution contract, the `location` field, `run.sh` check contract, storage rules, and authoring policy). Hand-port condensed equivalents to both `adapters/cursor/rules/persona-protocol.mdc` and `adapters/codex/agents-md-fragment.md` in their own established styles. Add required parity-map entries to both `codexMap` and `cursorMap` in `tests/adapter-protocol-parity.test.js`. Update `agents/lead-programmer.md` with authoring policy for `functions[]` on heavy units (referencing ADR-0004 trigger as amended by ADR-0013, not restating thresholds). Update `agents/reviewer.md` with microworld-specific verification guidance (filesystem check only, never execute entries, dashboard never an acceptance criterion, containing the sentinel phrase twice as required).

## [0.31.5] - 2026-08-10

### Fixed
- **Orchestration dispatch identity hardening (issues #306–#312).** A named `Agent` dispatch for a `reviewer` unit (specifying `name:` to enable mid-flight `SendMessage`) silently changes the agent's `agent_type` field to that name instead of the persona type, defeating privilege isolation — `reviewer-route-gate.sh` now refuses such a dispatch at spawn time (gh306), with centralized audit-log visibility added for all privilege denials (gh307); both are real code changes, shipped in `hooks/scripts/reviewer-route-gate.sh` and `hooks/scripts/stop-gate.sh`, with adapter port mirrors (gh308 corrects dispatch-naming prose). `reviewed-path-gate.sh` audit hardening for privilege denials also ships in the main location; its adapter equivalent is `protected-paths.sh`. `Write` and `Edit` tools granted to a persona — whether via frontmatter `tools:` or the `memory:` auto-grant path — can still be rejected at call time when dispatched as a named/teammate-style subagent due to a harness limitation; no repo-side code fix exists for this, so it is mitigated via shared protocol documentation of the Bash-heredoc fallback (gh309, guidance-only). A named dispatch's turn-completion does not auto-notify the dispatcher; orchestration-aware guidance now defaults to unnamed `Agent` dispatch, naming only when genuine mid-flight addressability is needed (gh310, guidance-only). A bare-name `SendMessage` to `reviewer` can misroute to a stale session from an unrelated unit (risking the gh-304 dual-marker conflict); orchestration-aware guidance now requires a fresh `Agent` dispatch (never message-resume) for a different unit, and checking the active roster before reusing a name (gh311, guidance-only). `CONTEXT.md`'s Agent-identity glossary was amended to reflect this hardening (gh312). All of the above are grounded in ADR-0016 (dispatch identity and privilege isolation); gh306 and gh307 ship enforcement code, while gh309–gh311 are prose-only protocol guidance.


## [0.31.4] - 2026-08-09

### Added
- **Mutation-proved structural test for `skills/ubiquitous-language/SKILL.md` (issue #305, rewritten Step 4).** `tests/ubiquitous-language.test.js` asserts, against the real SKILL.md, that both mode headings are present, the no-glossary degradation text names `CONTEXT.md` and `scribe` in the same paragraph, the three lenses' descriptions are mutually distinguishing, and the two modes' anchor forms are mutually distinguishing. Since the skill is pure prose with no programmatic entry point, non-vacuity is proven by running the test against a mutated in-memory copy (`UL_TEST_MUTATE=1`) with the degradation paragraph and the three lenses' language collapsed to identical boilerplate — the real file passes, the mutated copy fails. Registered in `tests/validate.sh`. The lens's semantic correctness remains untested by design (P2).

## [0.31.3] - 2026-08-10

### Changed
- **Wire `spec-master`'s consumption of ubiquitous-language skill (issue #304).** Amend `agents/spec-master.md` to check the raw request during grill-before-planning and the draft plan during Self-check in prose mode against `CONTEXT.md` glossary, grounding category 8 (Terminology consistency) in actual glossary definitions. Findings are advisory-only and never block progression. Read glossary once per session and reuse across both check points.

## [0.31.2] - 2026-08-09

### Changed
- **Normalize `CONTEXT.md` to canonical `CONTEXT-FORMAT.md` shape (issue #303).** Convert flat `- **Term** — definition` list to structured format: `## Language` heading, `**Term**:` entries with definition on next line, and `_Avoid_:` synonym lines for near-synonym pairs. Preserves all 32 existing definitions verbatim. Adds `_Avoid_: clear-watermark` to `review-join stamp` entry (the retired predecessor mechanism). Scribe-owned unit; complements issue #302 (ubiquitous-language skill) and prepares glossary for issue #138 (Microworlds Step 8).


## [0.31.1] - 2026-08-09

### Added
- **New optional `ubiquitous-language` skill: detect terminology drift
  against a canonical glossary (issue #302).** Dual-mode skill with shared
  drift core (three lenses: term redefinition, new synonym, undeclared domain
  term) and two input adapters — diff mode for `reviewer` (file:line anchors,
  preserved from issue #129) and prose mode for `spec-master` (quoted-span
  anchors, new). Advisory-only; never gates. Amends `reviewer.md` verdict
  bullet to support plural advisory sections with fixed order (roast-work
  first, then ubiquitous-language).

All notable changes to the antislop plugin (formerly seb-personas) are
recorded here. Dates are ISO (YYYY-MM-DD).

## [0.31.0] - 2026-08-09

### Fixed
- **`agent-auditor`'s `--format-probe` now genuinely distinguishes its
  states (issue #297, F3).** R1, this feature's own most-dangerous-failure-
  mode mitigation, requires that "'no anomalies' and 'could not read' must
  never render alike" — the shipped probe collapsed four distinct operator
  conditions (readable-but-no-dispatches, empty root, missing root, and
  genuinely malformed records) into one `FORMAT-UNRECOGNIZED` output, and
  additionally raised a false alarm on the normal empty/no-dispatch case.
  The probe now reports five states: `FORMAT-OK`,
  `FORMAT-OK-NO-DISPATCHES`, `FORMAT-EMPTY`, `FORMAT-NO-STORE`, and
  `FORMAT-UNRECOGNIZED`. `--all` is now loud (prints a `FORMAT-UNRECOGNIZED`
  banner) on a malformed store, while the empty-store render stays exactly
  `no data for window` and exit codes stay 0 in every mode, matching the
  persona's non-gating contract. The persona doc now states the probe runs
  first and that `FORMAT-UNRECOGNIZED` means the report must not be
  presented as "no anomalies" — closing both halves of a prior FAIL
  record's non-blocking note that had raised and mis-cleared this exact
  class.

## [0.30.0] - 2026-08-09

### Added
- **New optional `agent-auditor` persona: read-only observability over agent
  activity and dispatch history.** Runs `scripts/agent-audit.sh` against the
  transcript store and reports six anomaly checks — undeclared tool use (A1),
  unregistered agent type (A2), nested spawn (A3), gated dispatch without a
  later reviewer dispatch in the same session (A4), missing terminal status
  line (A5), and an orphan PASS marker with no reviewer dispatch in the
  window (A6) — plus two informational summaries: model distribution
  (dispatched vs. declared, I1) and skill-invocation inventory grouped by
  persona (I2). It never gates, blocks, fixes, or re-dispatches anything; a
  finding is an observation for a human, not a verdict. Selected per-project
  like the other optional personas; the orchestrator routes to it when
  present, distinct from `milestone-auditor` (audits the plan) and `reviewer`
  (issues a verdict on code).

## [0.29.0] - 2026-08-08

### Removed
- **`gh api` is no longer on `reviewed-path-gate.sh`'s Bash write-intent
  allowlist, so it is blocked for non-reviewer personas** in any command whose
  text spells the marker directory (issue #272). `gh api` is a general-purpose
  authenticated HTTP client whose method is implicit (POST as soon as any
  `-f`/`-F` flag is present) and which reaches GraphQL mutations naming no REST
  route, so no scan of the command's text can bound what it writes — the same
  denylist-fails-open reasoning already recorded for `git` and `rg` (0.17.0).
  The `gh` arm now admits `issue`/`pr`/`search` only. **Workarounds**: `cat` to
  read a marker file, and `gh issue`/`gh pr` comments to discuss one. This is
  an intentional reduction in delivered function, which is why it is a minor
  bump rather than a patch, mirroring #186's 0.16.x -> 0.17.0 precedent for the
  same kind of allowlist narrowing.
- **`rg`'s flag-inventory audit is moot, not merely skipped.** #186 (0.17.0)
  already removed `rg` from the allowlist outright, so there is no `rg` entry
  left to guard and no flag inventory to complete — a repeat audit would find
  nothing to diff. Recorded here so this conclusion does not have to be
  re-derived by a future audit.

## [0.28.0] - 2026-08-07

### Changed
- **Per-unit review-join stamp replaces the global clear-watermark (issue #226).** When multiple reviewers run concurrently, the check coupling a reviewer's stop to a marker-write now asks the right question — "did *this dispatched unit* get a verdict?" — instead of the wrong one ("has *any* marker been written since *anyone's* last clear?"). Each reviewer dispatch now opens with `Unit: <task-id>` as its literal first non-blank line; `reviewer-route-gate.sh` reads that line to stamp a per-unit join at `.claude/.review-join.<unit-id>`, and `stop-gate.sh` consumes it when that unit's verdict marker is found. This closes the liveness failure (concurrent-reviewer deadlock) completely and the under-inclusive failure (unit A's marker satisfying unit B's check) substantially.
- **Bare zero-byte markers no longer satisfy the format check (issue #226).** The check is now unified with `task-gate.sh`'s `marker_valid()`, which rejects existence-only markers and requires a prefix match on the first line. A marker written by `touch` with no content will not be accepted.

## [0.27.0] - 2026-08-07

### Added
- **Marker format v3 (commit-anchored PASS markers).** The reviewer now verifies that the reviewed state is actually committed before writing a PASS marker. This is the marker format v3 delta over v2: a `commit: <sha|none>` field is inserted into the marker's first line, between the timestamp and `criteria:` (`PASS <task-id> <UTC ISO-8601 timestamp> commit: <sha|none> criteria: <acceptance-criteria command(s) run>`), so the `dispatch-hygiene.sh` H3 validator can decline to fire when a marker's attested commit is unreachable from `HEAD` — i.e. the marker's own work has since vanished from history. This is additive, not a breaking format change: `task-gate.sh`'s `marker_valid()` checks only line 1's `PASS <task-id> ` prefix and non-emptiness, so v2 markers remain valid and are never retroactively rejected.

## [0.26.0] - 2026-08-07

### Changed
- **Efficiency audit remediation, Milestone 3 (F9, F11; F10 assessed and
  rejected).** Two findings from the efficiency audit remediated, one
  finding assessed and rejected:
  - **F9 — resume the same reviewer on `INSUFFICIENT-CONTEXT`:** After
    fetching the named missing constraint, the orchestrator now resumes the
    same reviewer session by name via `SendMessage`, quoting the constraint,
    instead of spawning a fresh reviewer dispatch. Unchanged: this does not
    count against the 2-FAIL cap, does not re-dispatch lead-programmer, and
    the standing pending-review flag stays in place.
  - **F10 — milestone-audit gate: assessed and rejected, not reversed.** The
    milestone-audit gate remains unconditional and mandatory; "a clean
    checkpoint is not a reason to skip the audit" is unchanged. F10's saving
    is partly captured by F1 (unit #230), which drops a clean, FAIL-free,
    all-mechanical milestone's audit from `fable` to `sonnet` — but only for
    milestones **under 8 units**. A clean milestone of **8 or more units**
    still audits on `fable` (3 of this repo's 12 milestones, 25 %). That
    partial saving was the narrower of two supports for the rejection; the
    load-bearing one is that the principle is deliberate and reasoned. The
    audit itself was never made optional.
  - **F11 — reuse a forwarded blast-radius answer instead of re-deriving
    it:** When a dispatch packet already contains a `## Pre-resolved
    context` blast-radius / structural answer, personas now verify the
    specific doubted claim via `explorer` rather than re-deriving from
    scratch. Applies to lead-programmer, spec-master, and milestone-auditor
    only — the reviewer is explicitly exempt and always re-derives blast
    radius independently.

## [0.25.0] - 2026-08-06

### Changed
- **Efficiency audit remediation, Milestone 2 (F6, F7).** Two findings from the
  efficiency audit remediated:
  - **F6 — spec-master's ceremony becomes conditional on measured ambiguity:**
    Three ceremony elements become conditional: the dated `Q … → A …`
    clarification lines, now required only for categories scored Partial or
    Missing (previously required for every category); the itemized `CHKn`
    self-check, required only when the plan has ≥3 steps or any category
    scored Partial/Missing (a 3-item floor still applies below that
    threshold); and `to-spec` tracker publication, opt-in below the
    multi-milestone / ≥3-unit threshold. Grilling/interrogation itself is
    unchanged and remains unconditional for any non-trivial task. Stays
    mandatory unconditionally: machine-checkable acceptance criteria per
    step, the finalized spec / `docs/plans/` document as the canonical
    artifact, the 9-line taxonomy scorecard, Open Questions (never resolved
    silently), and the Constitution check.
  - **F7 — ≤2-unit fast path: spec-master emits dispatch contracts directly:**
    For specs that task-master would slice into ≤2 units, spec-master now emits
    the nine-element dispatch contract directly without running `to-tickets` or
    filing tracker issues; retrieval points at the `docs/plans/` path. Resolves
    an ADR-0003 collision discovered during exploration. task-master remains
    mandatory for: specs resolving to ≥3 units, any debug-spec re-derivation,
    and any `## Convergence follow-ups` slice.

## [0.24.0] - 2026-08-06

### Changed
- **Skills library remediation (spec #245, units #246–#255, completed 2026-08-07).** Comprehensive reachability fix: skills marked with `disable-model-invocation` are now unreachable to agents in all modes (previously only in agent-teams mode). Skill rewiring: `implement` skill deleted; `handoff`, `improve-codebase-architecture`, `to-spec`, and `to-tickets` un-flagged for availability; `grill-me` superseded by `grilling` in persona frontmatter definitions; `domain-modeling` wired into `scribe`; all persona-declared skills verified live post-cache-refresh (not just by file-content grep, per unit #255's acceptance test). The `fm-noflag` declared-deviation class this un-flagging introduced is recorded architecturally in `docs/adr/0012-vendored-skill-declared-deviations.md` (unit `245-CF1`, 2026-08-07).

## [0.23.0] - 2026-08-06

### Changed
- **Efficiency audit remediation, Milestone 1 (F1, F2, F4, F5, F8).** Five
  distinct cost drivers in the persona system and orchestrator prose were
  identified and remediated:
  - **F1 — fable's inverted cost-benefit in spec-master:** The most expensive
    model tier was routed to the easiest spec work (already-enumerated scope,
    existing seams, no interrogation needed). Rerouted `spec-master` to
    `opus` or `sonnet` only. `milestone-auditor` was amended to route fable
    to size-measured bulk-context work (≥8 units) rather than the previous
    inverted condition.
  - **F2 — removing the fable roast-work advisory pass:** The pass duplicated
    the reviewer's own inline `roast-work` (same rubric, same diff), but was
    gated on triggers that fired on 2-line diffs (no size floor). Decision:
    removed the pass outright, accepting a capability reduction against
    ADR-0004 in exchange for simplicity. This removes the reviewer's
    advisory fable pass — see R-I decision below.
  - **F4 — expire implementer-side `.fail` ratchets on PASS:** A `.fail`
    record permanently disqualified a unit from cheaper tiers; now expires
    once a `.pass` marker for that unit exists and postdates the `.fail`.
    The reviewer gate (`.fail` disqualifier) remains permanent, preserving
    ADR-0006 and ADR-0009 safety invariants.
  - **F5 — scribe double-dispatch:** The scribe was called twice per unit
    (once blocking from lead-programmer, once from orchestrator post-landing)
    with overlapping payloads. Consolidated to a single post-landing dispatch.
  - **F8 — persona-protocol.md prose compression:** The "Per-unit model
    routing" section consumed 36 % of orchestrator.md and was reproduced
    across six personas. Compressed via Steps 1, 4, 5 (fable removal, ratchet
    expiry, scribe consolidation); further prose cleanups in subsequent
    releases.

  **R-I decision (F2 consequence): Steps 1 + 2 remove `fable` from
  `spec-master`'s dispatch and from the reviewer's advisory `roast-work`
  pass — they do not retire `fable` outright.** `milestone-auditor`'s
  **tier-2** fable dispatch survives: it is a live dispatch path on a ≥8-unit
  judgment-signal-free milestone (see `agents/orchestrator.md` § Dispatch-
  model routing for spec-master and milestone-auditor). The standing
  exclusion guard in `agents/orchestrator.md` (§ task-master model routing)
  is a non-dispatch guard, deliberately retained to prevent accidental
  re-introduction into `task-master`. This is a deliberate cost reduction,
  not an oversight. ADR-0004 § Decision Tension 2 (fable's bulk-context
  critique on large surfaces) is explicitly superseded by the review-centric
  approach; ADR-0004's Tension 1 (roast-work as advisory, never gating)
  survives unchanged.

### Internal
- Milestone 1 release (version bump + mirror regeneration + CHANGELOG).

## [0.22.0] - 2026-08-02

### Changed
- **`reviewer` stop can now be blocked by a missing or malformed PASS marker,
  enforcing that a completed unit awaits independent verification before any
  downstream gated dispatch resumes.** Prior versions allowed a reviewer to
  end its turn even if the marker it should have written was invalid or
  missing; in this release, an invalid marker (empty or malformed) blocks
  `reviewer`'s own stop until the marker is fixed. In default (subagent-
  orchestrator) mode this is a mechanical stop-gate block; in agent-teams
  mode, it gates the `TaskCompleted` hook. Issue #221.
- **`scribe` now mutates tracker state, closing finished-review issues as
  part of its institutional-knowledge duties.** Prior versions logged
  review closures to the audit trail but never issued the close command;
  `scribe` now writes the `gh issue close` command to close issues that have
  reached their end state, making the workflow visible and synchronized
  across Claude Code (the `.claude/review-audit.log` and `.claude/wip-audit.log`
  local records) and the GitHub issue tracker. Issue #223.

### Fixed
- **`dispatch-hygiene.sh`'s `.dispatch-override` escape hatch no longer fails
  a legitimate double-fire of the same dispatch.** A bounded 10-second replay
  window now honors both runs of a sequential or parallel double-fire (same
  dispatch key, matched via a content hash of the prompt) instead of only
  the first, writing an atomic `.dispatch-override.consumed` stamp and
  logging the replayed run as `override-replay=` (distinct from `override=`)
  for audit traceability. Issue #166 Finding 2.

### Internal
- Adapter port alignment for Cursor and Codex #222.

## [0.21.0] - 2026-08-01

### Changed
- **`lead-programmer` now defaults to `haiku`, and `task-master` can no longer
  pre-emptively tag a unit above it — tagging is reactive-only, so a
  large-surface, structural, or security-sensitive unit still starts on
  `haiku` and only escalates after a measured signal (e.g. a FAIL) calls for
  it.** Every already-adapted downstream
  project inherits this default on its next `--update`.
- **A new blocking `H4` dispatch-contract check in `dispatch-hygiene.sh`, on
  by default, refuses any gated dispatch missing a required contract
  section.** Escape hatches: `.claude/.dispatch-override`,
  `dispatchHygiene.mode: warn|off`, or the new
  `dispatchHygiene.requireContract: false`. Every already-adapted downstream
  project inherits this gate on its next `--update`.

## [0.20.0] - 2026-08-01

### Changed
- **`reviewer-tier.sh` now fails closed on an unresolvable marker directory
  and treats `agents/*.md` / `.claude/agents/*.md` as sensitive, so some
  units that previously measured `sonnet` will now measure `opus`.** Three
  fail-open gaps closed together, all the same failure mode (a measurement
  the script could not make was treated as "safe" rather than
  "unmeasurable"): `diff.relative=true` could drop a sensitive file from the
  `numstat` output entirely rather than merely mis-anchor its path, silently
  shrinking both the file and line counts; the marker directory defaulted to
  `.` instead of `git rev-parse --show-toplevel` when
  `CLAUDE_PROJECT_DIR` was unset, and an id given with no locatable marker
  directory now fails closed to `opus` instead of measuring around it; and
  `agents/` / `.claude/agents/` were absent from `SENSITIVE_PATHS`, so the
  prose that governs how deeply every other persona source is reviewed could
  itself measure `sonnet` on a 1-file/1-line edit. Issue #199.
- **An empty `defer: ` / `skip: ` reason now blocks turn-end where it
  previously allowed it (operator ruling, 2026-08-01).** This is a
  correction, not a new restriction: the `'defer: '*` / `'skip: '*` glob
  matched a reason that was empty after the colon (`*` matches the empty
  string), so a content-free escape hatch exited 0 — and for `skip:`, even
  deleted the pending-review flag — while all three block messages already
  claimed "Empty reason rejected." and the WIP sentinel genuinely enforces
  the same rule. The stop-gate now blocks (exit 2) instead, matching the
  contract it already advertised; non-empty `skip:` deletion is unchanged.
  A related fix in the same batch flattens a multi-line `defer:` reason to
  one logical line before comparison and write, so the consecutive-duplicate
  audit-log dedupe fires for multi-line reasons the same way it always did
  for single-line ones (previously: three `Stop`s with an unchanged
  multi-line reason wrote three identical audit records instead of one).
  Issue #201.

Secondarily: the `defer:`/empty-reason fixes above were ported verbatim to
both the Cursor and Codex stop-gate adapters, which had drifted out of the
parity their own headers claimed with `hooks/scripts/stop-gate.sh` — a new
merge-gate test (`tests/adapter-stop-gate-parity.test.sh`) now checks that
claim instead of trusting it (issue #202). `bin/cli.js` also now fails
loudly, at both scaffold-default load time and on every project-config
render, when `gatedAgents` names a slim-tier persona — the slim protocol
template carries neither gate section, so the force-include was previously
a silent no-op (issue #203; currently latent/unreachable under this
project's own shipped `gatedAgents` config).

## [0.19.0] - 2026-08-01

### Changed
- **A resumed persona asked only to confirm completion now replies briefly
  instead of re-running the tests/tools it already reported.** Across the
  #188-197 batch, a resume that only asked "did you finish?" was observed
  costing 53k-108k tokens and up to 45 tool calls as the resumed persona
  re-verified work it had already reported done — defeating the point of a
  cheap resume. The "Terminal status line" section (unchanged canonical
  heading, so the protocol-tier matrix and completeness validator need no
  changes) now tells every gated persona to answer a confirm-only resume with
  a one-or-two-sentence reply plus the status line, and to re-verify only when
  the resume explicitly asks it to continue work, check something new, or it
  genuinely doubts its own prior report. The orchestrator itself now checks
  independently-verifiable repo state (`git log`/`git status`, re-running the
  reported test command) before resuming solely for a missing `STATUS:` line,
  when the report already reads complete with verifiable evidence — cheaper
  than a resume, and sometimes avoids needing one at all. This does not relax
  the existing "resume at most once per dispatch" bound. Ad hoc
  operator-requested unit, same precedent as the `maxturns-bump-lp-reviewer`
  unit recorded under 0.14.0.

## [0.18.0] - 2026-08-01

### Changed
- **Reviewer tier is now decided by a measured diff at reviewer-dispatch
  time, not by `task-master`'s pre-implementation `haiku` tag.** The
  orchestrator runs the new `hooks/scripts/reviewer-tier.sh <task-id>
  <git-range>` and passes its verdict (`sonnet` or `opus`) as the reviewer
  dispatch's `model`. The script prints `sonnet` only when the diff is at
  most 40 changed lines AND at most 3 changed files AND touches no
  sensitive path class (`hooks/`, `bin/cli.js`, `tests/validate.sh`, the
  protocol templates, settings/plugin manifests, …); it fails closed to
  `opus` on an empty/malformed range, an existing `.fail` record for the
  unit, or anything it cannot measure. Because `task-master` previously
  emitted the old `Suggested reviewer model: sonnet` tag only for a
  non-`haiku` unit — and no unit in this repo is tagged `haiku` — the old
  gate was reachable roughly 0% of the time in practice; the measured gate
  makes ~15% of units sonnet-eligible (measured against the last 50
  commits). The orchestrator's own judgment may **downgrade** the script's
  verdict (`sonnet` → `opus`) but may **never upgrade** it (`opus` →
  `sonnet`); fable stays permanently off the gate and a `.fail` record still
  forces `opus`. `docs/adr/0009-reviewer-tier-measured-eligibility.md`
  amends ADR-0006 with this rule; `task-master` no longer emits any reviewer
  model tag at all.
- **The pending-review flag's `defer:` is now documented as sticky — this
  was always the implemented behaviour, and the previous documentation was
  wrong, not a behaviour change.** A `defer: <reason>` write persists on the
  flag and permits turn-end on *every* subsequent `Stop`, not just the one
  that wrote it, until the reviewer's own `SubagentStop` clears it or a
  `skip:` deletes it; `reviewer-route-gate.sh` still blocks the next gated
  dispatch on the flag's mere existence regardless of a defer, so the real
  guard ("no next implementation unit until the reviewer runs") is
  unaffected — only the turn-end nag is relaxed. As of this release the
  orchestrator writes one `defer: reviewer dispatched (agent <id>), awaiting
  verdict` at the moment it dispatches the reviewer in the background,
  instead of repeating a defer every turn, and `stop-gate.sh` no longer
  appends a duplicate `.claude/review-audit.log` line for a `defer:` whose
  reason is unchanged from the immediately preceding line (a changed reason,
  or any other line in between, is still logged).
- Each full-tier persona's `.claude/agents/*.md` mirror now physically
  inlines only the protocol sections that mechanically apply to that
  persona, instead of the full 2,806-word protocol regardless of role —
  16-41% smaller bodies across the five trimmed personas (`reviewer` saves
  450 words/16%; `lead-programmer` saves 597 words/17%; `milestone-auditor`
  saves the most, 1,157 words/41%).
  `orchestrator` keeps the untrimmed protocol, since it is the one persona
  that routes and acts on every mechanism. Any persona listed in
  `persona-config.json`'s `gatedAgents` always force-includes the "WIP
  sentinel" and "Pending-review flag" sections regardless of its trimmed
  row, so the matrix cannot go stale against that config (this is why
  `lead-programmer`, the one gated persona today, keeps "Pending-review
  flag" and saves 597 rather than 712 words).
- `.claude/persona-protocol.md` is restored as a full, version-stamped,
  on-disk reference copy generated by `--update` — reversing the prior
  `OQ11=DROP` decision now that a trimmed persona needs somewhere to read a
  rule that was excerpted out of its own mirror. Nothing auto-loads it, so
  it costs zero tokens per dispatch. `--update` also now restores any
  deleted **managed markdown mirror** (any `.claude/agents/*.md`, this file,
  or `persona-protocol-slim.md`/`protocol-digest.md`) even when the
  installed version otherwise matches — previously a deleted mirror other
  than the one hard-coded path silently went unnoticed and `--update`
  reported "already current". This covers only the markdown mirrors listed
  above; hook scripts, skill copies, and `settings.json` registrations are
  scaffold-time-only copies and are **not** covered by this self-heal.

### Fixed
- `templates/persona-protocol.md` and the Codex/Cursor adapter ports no
  longer describe protocol delivery as a single `@.claude/persona-protocol.md`
  CLAUDE.md import — that migration away from the global include was
  deliberate (`@import` does not resolve inside a subagent body) and this
  repo's own `CLAUDE.md` has carried no such line for some time; the prose
  now matches the physical per-persona inlining `bin/cli.js` has always
  done. `skills/install-antislop/SKILL.md` no longer instructs a fresh
  install to add the line or hand-copy the protocol file, both of which
  `--update` immediately undid.

## [0.17.0] - 2026-07-31

### Removed
- **`git` and `rg` are no longer on `reviewed-path-gate.sh`'s Bash write-intent
  allowlist, so seven command forms that 0.16.0 deliberately unblocked are
  blocked again for non-reviewer personas** on every already-adapted
  marketplace-plugin project after `--update` (`bin/cli.js` copies
  `hooks/scripts/*.sh` wholesale; the standalone-install caveat under 0.16.0
  still applies). Specifically: a `git commit -m` message naming the marker
  directory, `git log`/`git diff`/`git show`/`git status`/`git blame` scoped to
  it, and `rg` searching it. **Workarounds**, both stated in the block message
  itself: put the message in a file and use `git commit -F <file>` — the command
  text then never names the path, so the gate returns before any matcher runs —
  and use `grep -r`, which stays allowlisted, to search the directory. There is
  **no** workaround for `git log -- <marker directory>`; that capability is
  simply withdrawn from non-reviewer personas. This is an intentional reduction
  in delivered function, which is why it is a minor bump rather than a patch.
- **Why they were removed rather than guarded better:** an allowlisted program
  can be steered by configuration it reads at run time that appears nowhere in
  the command line, established by an earlier command that never names the
  marker directory. No text-scanning improvement can detect that, because the
  decisive input is never in the text the hook inspects, and validating that
  ambient state would mean enumerating a third-party program's entire
  configuration surface — a denylist, which fails open on everything the
  enumeration missed. The surface was removed instead of inspected. More
  generally, the allowlist matches a program *name*, while what actually
  executes is decided by name resolution and by that program's own ambient
  configuration, neither of which this hook can see. **The Bash write-intent
  allowlist is a guardrail against careless or accidental writes by a
  cooperating agent; it is not a security boundary against a caller that
  controls its own environment.** `README.md`'s "Known limitations",
  `docs/design.md` and an appended note on ADR 0002 now say so; ADR 0002's own
  decision is unchanged.
- **The flag-scan machinery added in 0.16.1 is removed with its subject**, so a
  reader of the 0.16.1 entry below is not left believing it is still in force:
  the flag scans it fixed guarded exactly the two programs that are now off the
  allowlist, and the exhaustive flag-boundary regression sweep that pinned them
  went with them. The technique lesson it established survives in the wiki and
  in `docs/plans/2026-07-31-program-allowed-flag-boundary.md`. The regression
  suite now pins the removal itself, with a mutation control against the
  pre-removal gate so the reconciled suite cannot pass vacuously.

## [0.16.1] - 2026-07-31

### Fixed
- **The flag-scan boundary check in `hooks/scripts/reviewed-path-gate.sh`'s
  `program_allowed()` was less strict than intended, and is now a fail-closed
  over-approximation of bash word splitting.** The scans that keep an
  allowlisted-but-option-dangerous program (`rg --pre`/`--hostname-bin`,
  `git --output`/`-o`) from being used as a writer treated a word boundary as a
  single literal space. Bash's own rule differs in three independent ways, each
  separately sufficient to slip a flag past the scan: a word also begins after
  any of bash's ten **metacharacters**; **quote characters** are removed during
  word splitting, so they are not part of a word at all and may be sprinkled
  anywhere inside a flag name; and **expansion** can forge a flag token out of
  text that spells no flag anywhere. The first two are now normalized away
  before matching; the third cannot be resolved without running the command, so
  a segment carrying one of bash's expansion characters is refused outright at
  that scan — the same fail-closed choice already made for backslashes and
  heredocs. The flag inventory is unchanged: this changes which *text* counts as
  a flag, not which flags are listed. This **closes the still-open gap recorded
  in the 0.16.0 entry below**, which is tracked as issue #184.
- Because `bin/cli.js --update` copies `hooks/scripts/*.sh` wholesale, this fix
  reaches every already-adapted **marketplace-plugin** project on `--update`.
  The standalone-install caveat noted under 0.16.0 still applies unchanged.
- **Known over-block introduced by the above, accepted deliberately:**
  `rg --pre-glob '<glob>'` is now blocked when its glob contains `*`, `?`, `[`
  or `{`, because those are exactly the characters an expansion-forged flag
  hides behind. Quoting the glob does not help (quotes are transparent to this
  scan by design). Workaround: scope the search with a path instead. Pinned as a
  ratified residual rather than carved out, since deciding which `*` is a glob
  and which is a forged flag is the kind of extra-construct modelling that
  produced this bug class in the first place.

## [0.16.0] - 2026-07-31

### Changed
- **The Write/Edit tool path to the marker directory (`.claude/reviewed/`) is
  now BLOCKED for non-reviewer personas, where it was previously entirely
  ungated.** `hooks/scripts/reviewed-path-gate.sh` previously only ran on the
  Bash `PreToolUse` path; a direct `Write` or `Edit` tool call to
  `.claude/reviewed/*.pass`/`.fail`/`.blocked` was not checked by any hook,
  letting any persona fabricate a review marker. The same script is now also
  registered on the `Write|Edit` `PreToolUse` matcher and applies the same
  reviewer-GRANT / no-reviewer-fallback identity rules to `tool_input.file_path`
  that the Bash path already applied to `tool_input.command`. This is an
  **intentional increase in enforcement**, not a bug fix. This
  reaches every already-adapted project on `--update`, since `bin/cli.js`
  copies `hooks/scripts/*.sh` wholesale — **except** that `runUpdate` does
  **not** re-copy `hooks/scripts/` or re-merge `hooks.json` into
  `settings.json` for an already-adapted **standalone** (non-marketplace)
  project; only marketplace-plugin installs pick up the new gate automatically
  on `--update`. A standalone project needs a fresh re-scaffold (or a manual
  `hooks.json` merge) to activate it.
- **The Bash path's write-intent matcher was narrowed from a substring block
  to an allowlist of provably-benign commands**, so read-only inspection
  (`ls`, `cat`, `git log`, …) and benign text mentions (a `gh` issue body or
  `git commit -m` message naming the marker directory) are now allowed, while
  actual writes stay blocked. The matcher's operator scan and segment split
  were subsequently made quote-, comment-, heredoc- and word-boundary-aware,
  so quoted `>`/`;`/`|`/`&&` characters and fd-redirection/`/dev/null` forms
  (`2>&1`, `2>/dev/null`) inside an otherwise-benign command no longer cause a
  false block. The previous block message's incorrect "use the Read tool for
  that" advice (the Read tool cannot list a directory) has been removed and
  replaced with an accurate description of what is checked.

### Known limitations
- **The variable-split obfuscation bypass remains open.** A command such as
  `d=.claude/re; printf x > ${d}viewed/9.pass` still defeats the Bash matcher,
  because resolving shell variable expansion would require executing the
  command, which no hook can do. This is unchanged from before this effort
  and is documented, not fixed, by design.
- **Two narrow over-blocks in the quote/comment-aware matcher are ratified,
  intentional residuals, not defects.** (1) Any backslash anywhere in the
  command fails closed — e.g. `cat .claude/reviewed/a\ b` is blocked even
  though it only reads — because an escaped space defeats the word-start test
  the same way an escaped quote defeats quote pairing; workaround: quote the
  path instead of escaping it (`cat ".claude/reviewed/a b"`). (2) A trailing
  segment that is entirely a comment fails closed — e.g. `ls .claude/reviewed`
  followed by a newline and `# note` is blocked, because the comment's masked
  first word (`#`) is not allowlisted; workaround: put the comment above the
  command, or omit it.
- **A separate, still-open gap in the same matcher family, found during this
  effort's final review and NOT yet fixed here.** `program_allowed()`'s
  flag-scans for `rg --pre` and `git --output`/`-o` (the exact guards the
  Bash-path allowlist added) use a literal-space boundary check rather than a
  true word-boundary predicate, and are bypassable with a tab or a
  quote-adjacent form — e.g. `git diff<TAB>--output=.claude/reviewed/9.pass`.
  Bisected as present unchanged since the allowlist's original commit; not
  introduced by the later quote-awareness work, and not yet closed by it
  either. **This word-boundary/matching-hardening effort is not fully closed**
  — a fast-follow fix is planned but not yet filed as a tracked issue.

## [0.15.0] - 2026-07-30

### Changed
- **`Agent` dispatch is now BLOCKED by default in every already-adapted
  project when it exceeds configured token-hygiene limits.** Delivery of the
  gate depends on install type: **plugin-enabled** projects get it from the
  marketplace plugin cache refresh (`hooks.json` resolves
  `dispatch-hygiene.sh` via `${CLAUDE_PLUGIN_ROOT}`), potentially without
  ever running `--update`; **standalone-installed** projects do not get it
  from `--update` at all (`runUpdate` has no copy step for
  `hooks/scripts`/`hooks.json`) and need a fresh re-scaffold to activate it.
  Once live, an oversized prompt (`maxPromptBytes`, default 30000) or an
  oversized inlined fenced block (`maxInlineBlockLines`, default 80) exits
  the dispatching hook non-zero and the `Agent` call never reaches the
  subagent — a behaviour change, not an opt-in feature, since `block` is the
  shipped default posture. Two outs exist for a project that needs to
  disable this: set `dispatchHygiene.mode: "off"` in `persona-config.json`
  (per-project, permanent), or drop the single-use, audited
  `.claude/.dispatch-override` sentinel (per-dispatch, logged). A third
  check, H3 (re-dispatch of an already-PASSed unit), is REDUCED PROTECTION
  on arrival: it only fires when the reviewer's marker id actually matches
  the dispatch's `Unit:` line, a convention that issue #153 documents as not
  yet reliably followed — so H3 should be read as best-effort until that
  discipline is in place, not as a guaranteed catch.

### Added
- `dispatchHygiene` config surface (`persona-config.json`): `mode`
  (`block`/`warn`/`off`), `maxPromptBytes`, `maxInlineBlockLines`.
- `hooks/scripts/dispatch-hygiene.sh`, registered on `PreToolUse` for the
  `Agent` tool, implementing the oversized-prompt, oversized-inline-block,
  and re-dispatch-of-a-PASSed-unit (H3) checks above.

### Fixed
- **`bin/cli.js --update` no longer strands a mirror's version-stamp
  comment when its rendered content is byte-identical across a version
  bump.** The per-file "already current" fast path compared only the
  content hash (which never included the stamp line), so a mirror whose
  source hadn't changed kept whatever stamp it was last rendered under,
  silently drifting behind `persona-config.json`'s `pluginVersion` release
  after release (`.claude/agents/task-master.md`/`orchestrator.md`/
  `reviewer.md`/six others were all still stamped `v0.13.18` going into this
  release, despite two version bumps having passed). `--update` now
  re-stamps a content-unchanged mirror to the resolved version instead of
  leaving it untouched, and this repo's own 11 stranded mirrors were trued
  up to `v0.15.0` using the fixed tool (issues #168-174), replacing the two
  prior ad-hoc hand-patch commits (`dc46914`, `e184e7d`) that had worked
  around the same gap manually.

## [0.14.0] - 2026-07-30

### Changed
- **`spec-master`/`task-master` `maxTurns` raised 30 → 40 — shipped
  unmeasured, a deliberate product decision, not a trialled result.** Unlike
  the E1/E2 cap changes in `docs/self-improvement-loops.md` (both measured
  through the self-improvement harness before shipping), this raise carries
  no cost/turns/wall-time data and no holdout run: `spec-master` was observed
  being cut off live at `maxTurns: 30` on 2026-07-28, mid-edit of a spec doc
  and mid-republish of a GitHub issue, and the call was that closing the
  cutoff-detection gap below mattered more right now than precisely pricing a
  higher cap first. Recorded in `docs/self-improvement-loops.md` as an open,
  unvalidated hypothesis ("E6"), not a confirmed result.

### Added
- **Terminal status line — a machine-checkable completion signature on every
  dispatched turn, covering all personas in both protocol tiers.** The last
  non-empty line of a dispatched persona's final message must now read
  `STATUS: complete` or `STATUS: incomplete — <reason>`. This exists because,
  verified directly against Claude Code v2.1.220 (binary and session-payload
  inspection — revisit this workaround if a future release adds a real
  termination-reason field to the Agent-tool result or to `SubagentStop`), a
  capped subagent cannot see its own turn count or its own cap being hit, and
  the harness renders the `max_turns_reached` attachment as zero content
  blocks — so a mid-task cutoff reads identically to a clean finish unless the
  finish carries a signature. Added to both `templates/persona-protocol.md`
  (full tier) and `templates/persona-protocol-slim.md` (slim tier —
  `explorer`, `researcher`, `scribe`), and enforced fail-closed against the
  Codex and Cursor adapter ports by `tests/adapter-protocol-parity.test.js`.
  The orchestrator now reads this line on the receiving side of every
  dispatch before treating it as done, resuming the persona by name (never
  re-`Agent`) on `STATUS: incomplete` or a missing line, bounded to at most
  one resume for a missing line so it cannot loop forever.

## [0.13.18] - 2026-07-30

### Fixed
- **Agent identities are now matched namespace-aware, not as bare strings
  (2026-07-28 plan, Steps 2–5b).** `agent_type`/`subagent_type`/settings.json's
  `.agent` can arrive as a possibly-namespaced wire value (e.g.
  `antislop:reviewer`), not only a bare persona name. `stop-gate.sh`,
  `reviewed-path-gate.sh`, and `reviewer-route-gate.sh` (plus the Cursor and
  Codex adapter mirrors) now normalize both sides of every comparison via
  `hooks/scripts/lib/agent-identity.sh`, liberally at gate checks (a miss
  fails open) and conservatively at privilege grants (a miss fails closed
  and is recorded as an `identity-drift` audit line). This release is the
  first to ship that fix — it was not present in any earlier version.
- **Empirical record repaired (Step 8).** Probe A's fixture
  (`eval/harness/scaffold.sh`) installed personas as bare-name project-local
  copies only, so its captured `agent_type` payload was necessarily bare —
  but its verdict generalized that single observed form as if it were the
  field's only possible shape, which the namespace-aware fix above corrects.
  `docs/experiments/2026-07-probe-hook-payloads.md` now carries a scope
  caveat on Probe A's verdict (the captured payload itself is untouched) and
  a Probe C placeholder for the still-outstanding namespaced-dispatch
  re-probe (Step 9, blocking acceptance gate).

### Documented
- `README.md` "Known limitations" now covers the cross-namespace identity
  behavior (liberal matching at gate checks, conservative at privilege
  grants — a bare or `antislop:`-prefixed reviewer identity both clear
  pending-review flags) and what an `identity-drift` audit-log line means
  for a reader (an unrecognized namespace or a malformed/unparseable
  identity).
- Header comment blocks of `hooks/scripts/stop-gate.sh`,
  `reviewed-path-gate.sh`, `reviewer-route-gate.sh`, and the Cursor
  `stop-gate.sh`/`reviewer-route-gate.sh` mirrors already stated the
  normalization contract from Steps 2–5b; the two Codex mirrors
  (`stop-gate.sh`, `reviewer-route-gate.sh` — there is no Codex
  `reviewed-path-gate.sh`) were still missing it and are backfilled here, so
  no header asserts `agent_type` always equals a bare persona name. No
  executable logic changed — comments only.

## [0.13.16] - 2026-07-22

### Fixed
- **Roast-work advisory-pass trigger backfilled into the Codex and Cursor
  protocol ports (Step-10 adapter-parity remediation, U15/OQ12).** U8's
  reviewer roast-work trigger + downgrade/expiry path never reached
  `adapters/codex/agents-md-fragment.md` or
  `adapters/cursor/rules/persona-protocol.mdc` — both ports had zero
  roast/downgrade content. The section is now backfilled into each port in its
  own established condensed style (the three heavy-unit triggers — large
  surface, structural/cross-cutting, security-sensitive — plus the per-class
  clean-streak downgrade/expiry path), not a verbatim copy of the canonical
  template. The ports are deliberately hand-adapted (reworded headers,
  platform-specific degradation notes) and copied verbatim by `bin/cli.js`, so
  construction-time injection was rejected in favor of a drift guard.

### Added
- **`tests/adapter-protocol-parity.test.js` — fail-closed section-level drift
  guard.** Derives the canonical top-level section list from
  `templates/persona-protocol.md` and requires each section to be either
  present (probe) in each adapter port or on an explicit, documented deferred
  allow-list. A new canonical section with no map entry throws (fail-closed),
  and self-verifying negative cases prove the checker rejects unmapped/absent
  sections. The pre-existing broader port drift ("Agent-teams mode", "Running
  acceptance-criteria commands", "Third verdict: insufficient-context", "A note
  on memory") is recorded as documented deferred gaps, not silently dropped.
  Wired into `tests/validate.sh`.

## [0.13.15] - 2026-07-22

### Fixed
- **Stale bare `persona-protocol.md` prose cross-references corrected
  (OQ11/U12 trade-off remediation).** `agents/lead-programmer.md`,
  `agents/reviewer.md`, and `agents/orchestrator.md` each pointed readers at
  a standalone `persona-protocol.md` file that no longer exists since U12
  dropped the generated `.claude/persona-protocol.md` copy in favor of
  per-persona inlining. Three redundant "see persona-protocol.md" pointers
  (to content already inlined verbatim further down the same body) were
  removed; `reviewer.md`'s listing of `persona-protocol.md` as a third
  auto-injected sibling file (alongside `CLAUDE.md`/`constitution.md`) was
  reworded to describe the protocol as inlined into the file itself. The
  three genuine `templates/persona-protocol.md` references (the real,
  still-existing canonical source, including Step 8's roast-pass dedup
  pointers) are untouched. Closes #121 (U14).

## [0.13.14] - 2026-07-22

### Added
- **Persona-system audit patch: design-notes relocation, per-persona
  protocol delivery, roast-pass dedup/downgrade path, and fable context
  assembly.** Remediates the four findings from the external architecture
  audit of the persona system. Permanent maintainer rationale moved out of
  persona bodies into version-controlled `docs/persona-design-notes.md`,
  leaving persona bodies free of unenforceable prose. Protocol delivery is
  no longer a single global `@import` line duplicated into every subagent;
  `bin/cli.js` now inlines the full protocol per-persona directly into each
  `.claude/agents/*.md` body (`inlineProtocolBlock`), and a new
  `templates/persona-protocol-slim.md` digest is registered with
  `--update` for lightweight, stateless personas that don't need the full
  protocol's token cost. The fable "roast pass" trigger, previously
  duplicated verbatim across persona bodies, is now defined once and
  cost-tightened, with a downgrade/expiry path (3 consecutive clean passes
  for a recurring unit class drops it from the trigger, restored on any
  Major/Critical finding) so system cost stops only ratcheting up. The
  orchestrator now specifies who assembles the fable roast pass's context
  and what it contains (the structured advisory review packet). The
  inverted-version-skew pre-flight guard for `--update` (refusing/warning
  on a source version older than the recorded project `pluginVersion`) was
  confirmed already covered by the existing `warnIfDowngradeStamp` guard —
  no new code required. The full/slim protocol-tier split is mirrored to
  the Codex and Cursor adapters. Two convergence follow-ups landed
  mid-plan: the now-orphaned generated `.claude/persona-protocol.md` copy
  (superseded by per-persona inlining) is no longer generated by
  `buildFileSpecs`/`fileHashes` and is cleaned up on `--update` for
  already-adapted projects; and a stale-reference sweep corrected
  README/`session-start.sh`/`bin/cli.js` prose and comments that still
  described the removed global `@import` line. Closes #121.

## [0.13.13] - 2026-07-22

### Added
- **Review-pipeline hardening: third `INSUFFICIENT-CONTEXT` verdict, persisted
  PASS-marker notes, and a structured advisory review packet.** The reviewer
  can now return `INSUFFICIENT-CONTEXT` (alongside PASS/FAIL) when a required
  constraint is neither in the review packet nor discoverable via its own
  exploration; this writes a `.claude/reviewed/<task-id>.blocked` marker,
  never consumes a 2-FAIL-cap slot, and does not re-dispatch
  `lead-programmer`. `stop-gate.sh` now keeps the pending-review flag
  standing (instead of clearing it) whenever a `.blocked` marker is active,
  so turn-end and the next gated dispatch stay blocked until the unit
  resolves to a real PASS/FAIL — mirrored to the codex and cursor adapter
  copies. The orchestrator's review routing gained an `INSUFFICIENT-CONTEXT`
  branch that dispatches explorer/scribe for the missing constraint and
  re-dispatches the reviewer, and now forwards the sliced issue's
  constraints/affected-files/rationale plus the lead-programmer's advisory
  review packet into the reviewer dispatch as non-authoritative inputs. A
  PASS marker may now carry the reviewer's non-blocking notes appended after
  its required first line, so Minor findings persist instead of being
  discarded. `task-master`'s slicing guidance now requires sliced issues to
  carry the originating spec step's constraints, affected-files, and
  rationale (not just the acceptance-criteria command), and
  `lead-programmer`'s ready-for-review reports now require a structured
  advisory packet (changed files, commit/diff range, acceptance command,
  spec-step id), explicitly marked advisory/non-authoritative. Closes #113
  (Steps 1-7; #114, #115, #116, #117, #118, #119, #120).

### Fixed
- **Extended the downgrade-stamping guard to the three `--overwrite` scaffold
  paths in `bin/cli.js`.** `scaffoldCursor`, `scaffoldCodex`, and the main
  claude-target `--overwrite` branch each unconditionally stamped
  `pluginVersion = version`, so a stale/older plugin resolving over a newer
  recorded version silently wrote the stamp backward. A new
  `warnIfDowngradeStamp` helper (reusing the hardened `compareSemver` from
  #109) now emits a warning naming both versions before each stamp. This is
  warn-and-proceed, not refuse — `--overwrite` is already an explicit
  destructive opt-in, so the defect fixed is the silence, not the stamping.
  Added per-path regression tests covering all three scaffold branches,
  including the equal-version boundary (recorded pluginVersion equal to the
  current plugin version) that proves the guard's `< 0` predicate.
  Fixes #110.
- **Hardened `compareSemver`'s dotted-suffix parsing and made the downgrade-
  refusal recovery message install-aware in `bin/cli.js`.** `compareSemver`
  now splits on the first `-`/`+` before dotted-segment parsing, so a
  pre-release suffix like `-beta.3` can no longer leak an extra non-numeric
  segment into the numeric comparison. The `--update` downgrade-refusal
  recovery text now branches on whether the marketplace plugin is enabled:
  marketplace installs keep the `claude plugin update` command; non-
  marketplace installs get local clone/scaffold guidance instead of an
  inapplicable command (`detectMarketplacePlugin` is now computed once,
  ahead of the guard). Added a direct `compareSemver` regression case, split
  the refusal test to assert both recovery branches, and added a filesystem-
  state assertion proving nothing is written before the exit-1 refusal.
  Fixes #109.
- **Allowlisted the two permanently-noisy `claude plugin tag --dry-run`
  advisory lines in `tests/validate.sh`.** The CLAUDE.md-not-loaded-as-
  project-context notice and the `agents/explorer.md` frontmatter-parse
  failure (its ADAPT-time `<REAL_LAUNCH_COMMAND_...>` placeholder is by
  design unresolved in this source repo) are now filtered out before the
  advisory WARNs, so the block only surfaces genuinely new mismatches. The
  filter is factored into `tests/lib/claude-tag-filter.sh` and covered by a
  fixture-driven `tests/claude-tag-filter.test.sh` (run from `validate.sh`)
  that proves both known-permanent lines suppress cleanly and an injected
  new mismatch line is not swallowed. The two-line header/detail match now
  buffers the header until the detail line is confirmed (instead of
  unconditionally dropping it), so a new/different single-line error or a
  header with a mismatched detail line both survive the filter intact
  rather than being swallowed; the buffer also tolerates a blank line
  between header and detail without leaking the known-permanent detail line
  as if it were new. Fixes #111.

## [0.13.12] - 2026-07-21

### Fixed
- **Reconciled the "distinct case" dispatcher-supervision lead-in in
  `agents/orchestrator.md`'s "Managing a long-running background dispatch"
  section with the three real mechanisms.** Dropped the inaccurate "one of
  two trigger cases" enumeration — a foreground command killed by the
  600000 ms timeout fits neither the false-watcher case nor the
  WIP-sentinel case — and reframed both as non-exhaustive examples plus the
  killed-mid-run case. Also fixed the doubled "Either way." Documentation/
  protocol-only. Fixes #89.

## [0.13.11] - 2026-07-21

### Fixed
- **Added the third (foreground-timeout-kill) remediation branch to the
  orchestrator's nested-background-Bash dispatcher guidance in
  `agents/orchestrator.md`'s "Managing a long-running background
  dispatch" section.** The dense "distinct case" paragraph is now a
  lead-in plus a three-state sub-list (still running / finished / killed
  with nothing left to finish). The new killed branch covers a foreground
  `Bash` call cut off by the 600000 ms per-call ceiling: the dispatcher
  should resume the subagent to retry the command, not to check a result
  that will never arrive, since external inspection can't always tell a
  finished background job apart from a killed foreground one. Also
  applied the two #95 polish notes: rewrote the orphaned "not merely an
  alternative 'or'" trailer sentence and rewrapped the section to its
  prevailing width. Documentation/protocol-only. Fixes #89.

## [0.13.10] - 2026-07-21

### Fixed
- **Broadened the orchestrator's nested-background-Bash dispatcher
  guidance in `agents/orchestrator.md`'s "Managing a long-running
  background dispatch" section.** The guidance previously keyed only on a
  subagent's legacy false claim of having "set up a background watcher."
  It now also covers the Step-1-compliant case: a subagent that correctly
  ends its turn via the WIP sentinel with the "no autonomous wake-up
  available" wording still requires the same dispatcher verify-then-resume
  response. Added the symmetric "still genuinely running" branch so the
  dispatcher does not resume prematurely when independent verification
  shows the command hasn't finished, and added a `ps` process-namespace
  caveat noting `ps` is only a trustworthy signal when the dispatcher and
  subagent share a process namespace (not guaranteed under `isolation:
  "worktree"`/`"remote"` dispatch), with git/file state as the primary
  fallback otherwise. Documentation/protocol-only. Fixes #89.

## [0.13.9] - 2026-07-21

### Fixed
- **Corrected the subagent self-wake fallacy for backgrounded acceptance-
  criteria commands.** A subagent that backgrounds a slow test/build/lint
  run (`run_in_background: true`) and ends its turn believing it will be
  autonomously notified when the command finishes was going dormant
  indefinitely — only a *dispatching* session's own `Agent`-tool calls get
  an autonomous wake-up; a subagent's own nested background `Bash` job has
  no such mechanism. `templates/persona-protocol.md` (and its
  `.claude/persona-protocol.md` mirror) now has a new "Running
  acceptance-criteria commands (there is no self-wake)" section mandating
  synchronous foreground execution (up to the 600000 ms `Bash` timeout
  ceiling) and, for the rare command that genuinely exceeds it, the sole
  legitimate escalation path: the existing WIP sentinel with wording that
  plainly states no autonomous wake-up is available. `agents/orchestrator.md`
  now distrusts a subagent's "background watcher" claim by default and
  independently verifies real state before deciding whether to resume it.
  `agents/reviewer.md` and `agents/lead-programmer.md` each gained a
  one-line pointer to the shared rule at their existing acceptance-criteria
  guidance. Documentation/protocol-only; no new hook or file format. Fixes
  #89.

## [0.13.8] - 2026-07-20

### Changed
- **Clarified that the heavy-trigger "structural / cross-cutting change"
  condition's examples are illustrative, not exhaustive.** Condition 2 of
  the `Roast pass: fable` heavy-unit trigger (in `agents/orchestrator.md`'s
  "Reviewer roast-work advisory pass" section and `agents/task-master.md`'s
  mirrored copy, plus their ADAPT-substituted `.claude/agents/` copies) used
  to list only a persona split, an orchestrator routing rewrite, or a
  `bin/cli.js` migration as examples. Expanded the wording to state the list
  is illustrative and that any other change to shared/cross-persona surface
  a reasonable reviewer would call structurally cross-cutting should also
  trigger heavy review, with guidance to trigger when in doubt since the
  pass is cheap. Documentation-only; no mechanism changes.

## [0.13.7] - 2026-07-17

### Changed
- **Tightened model-tiering wording in `agents/task-master.md` and
  `agents/spec-master.md` so each is correct standalone.** The
  `Roast pass: fable` heavy-unit trigger in `agents/task-master.md` now
  copies the same three numbered criteria (large surface, structural/
  cross-cutting change, security-sensitive surface) verbatim from
  `agents/orchestrator.md`'s "Reviewer roast-work advisory pass" section,
  with a citation keeping the two files in sync, and emission is now
  mandatory (`MUST`, was `MAY`) when the trigger fires — the tag remains
  advisory downstream. Both `.claude/reviewed/<task-id>.fail` checks in
  `agents/task-master.md` are now unconditional on every unit, not only
  re-scoped ones. `agents/spec-master.md`'s comment block now summarizes
  the fable-eligibility conditions and `.fail` disqualifier for its own
  dispatch, citing `agents/orchestrator.md`'s "Opus|Fable routing for
  spec-master and milestone-auditor" section as authoritative. No
  behavioral mechanism changes — documentation/wording tightening only.

## [0.13.6] - 2026-07-17

### Fixed
- **`agents/orchestrator.md` per-unit model routing now documents all three
  `Suggested model` tiers.** `agents/task-master.md` already tags sliced
  units `Suggested model: haiku|sonnet|opus`, but the orchestrator's
  consumer-side documentation (the "## Per-unit model routing" section and
  the roast-work parenthetical) only enumerated `haiku|sonnet`, so a strict
  reading of an `opus`-tagged unit would fall through to "omit the
  parameter" and silently downgrade it to lead-programmer's sonnet default.
  Corrected the enumeration to `haiku|sonnet|opus` and added a clause
  stating an `opus` tag routes identically (passed straight through as the
  `model` dispatch parameter), reserved for genuinely hard-judgment /
  high-stakes units. The three-tier enumeration is now consistent across
  `agents/task-master.md`, `agents/orchestrator.md`, and ADR-0003.
  Documentation-only; `agents/task-master.md` was not modified. Fixes #87.

## [0.13.5] - 2026-07-17

### Changed
- **Cursor and Codex adapter orchestrators now route through the
  `spec-master`->`task-master` two-stage vocabulary instead of the legacy
  `hivemind` persona.** `adapters/cursor/agents/orchestrator.md` and
  `adapters/codex/agents/orchestrator.toml` (both `copyStamped`-managed,
  version-stamped templates) were ported off the single-persona `hivemind`
  planning step onto the split `spec-master` (spec-writing) and `task-master`
  (dispatch-ready slicing) two-stage flow already in use by the main Claude
  Code persona set, keeping the Cursor/Codex adapters' routing prose
  consistent with the primary orchestrator's vocabulary. Prose/vocabulary
  correction only, no behavior change. Fixes #35.

## [0.13.4] - 2026-07-17

### Added
- **`node bin/cli.js --update` now detects and deduplicates stale standalone
  hook registrations when the marketplace plugin is enabled.** When `--update`
  detects the marketplace plugin is active (via `detectMarketplacePlugin`) AND
  stale standalone `${CLAUDE_PROJECT_DIR}/.claude/hooks/scripts/*.sh` registrations
  remain in `.claude/settings.json` from a pre-guard install, it warns the user
  of the duplicate collision. A new `--dedupe-hooks` flag surgically removes
  just the standalone registrations (leaving the marketplace plugin to provide
  the hooks); default behavior is warn-only and NEVER rewrites
  `.claude/settings.json` without the flag. `--dedupe-hooks` is a no-op when
  the plugin is not enabled (never disables all hooks). This extends the 0.13.2
  fresh-install guard to the `--update` resync path, which the original guard
  did not cover. Fixes #75, #76.

## [0.13.3] - 2026-07-17

### Fixed
- **Standalone installer now respects Claude Code settings precedence when
  detecting the marketplace plugin.** `bin/cli.js`'s `detectMarketplacePlugin()`
  previously used a flat OR across settings files (any file saying
  `enabledPlugins["antislop@antislop-marketplace"] === true` meant "enabled"),
  which silently left projects with ZERO hook registrations if they explicitly
  opted OUT at the project level while the plugin was enabled globally. The
  detector now resolves `enabledPlugins["antislop@antislop-marketplace"]` using
  Claude Code's documented settings precedence — Local (`.claude/settings.local.json`)
  > Project (`.claude/settings.json`) > User (`~/.claude/settings.json`) — so
  an explicit project-level false correctly overrides a global true. This
  refines the 0.13.2 coexistence guard. Fixes #71.

## [0.13.2] - 2026-07-17

### Fixed
- **Standalone installer now detects and guards against duplicate hook
  registration when `antislop@antislop-marketplace` is already enabled.**
  `bin/cli.js` scaffolds now detect if the marketplace plugin is already
  active for a project by checking for `enabledPlugins["antislop@antislop-marketplace"]`
  across project `.claude/settings.json`, project `.claude/settings.local.json`,
  and `~/.claude/settings.json`. When detected, the installer skips the
  duplicate `${CLAUDE_PROJECT_DIR}` hook registration for the `claude` target,
  preventing Stop/SubagentStop/PreToolUse/etc hooks from being registered
  twice. A new `--force-hooks` flag is available to override this detection
  and register the hooks anyway. The same guard is present on the `cursor`
  and `codex` targets as a documented no-op (no marketplace/plugin-enable
  distribution exists for those ecosystems, so it can never fire there).
  Fixes #67, #68, #69.

## [0.13.1] - 2026-07-16

### Fixed
- **`.claude-plugin/plugin.json`'s `skills` field was an invalid shape,
  breaking `/plugin install`.** Claude Code's plugin manifest schema expects
  `skills` to be a directory path/glob (`"./skills/"`) used only to remap
  the default skill-discovery location — not a list of skill names. The
  manifest had a flat array of 17 skill names (`code-review`,
  `codebase-design`, etc.), which Claude Code's installer rejected with
  `Validation errors: skills: Invalid input`, breaking installation via
  `/plugin install antislop@antislop-marketplace` for every user. The field
  is also redundant: Claude Code auto-discovers skills from the plugin's
  `skills/` directory without needing them declared in the manifest at all.
  Removed the field entirely; confirmed nothing else in this repo's own
  tooling (`bin/cli.js`, `tests/validate.sh`, CI) reads or depends on it.

## [0.13.0] - 2026-07-16

### Added
- **Signal-gated sonnet on the reviewer's authoritative PASS/FAIL gate (amends
  ADR-0004).** The gate defaults to opus and may run on sonnet for
  demonstrably-mechanical units, never on fable. See ADR-0006
  (docs/adr/0006-reviewer-gate-sonnet-for-mechanical-units.md) for the full
  decision, conjunctive conditions (haiku-tagged lead-programmer AND not
  heavy-unit-trigger AND no prior `.fail`), escalation protocol, and impact on
  the core Writer/Reviewer safety property.

## [0.12.1] - 2026-07-16

### Fixed
- **`.claude-plugin/plugin.json`'s marketplace/install description still
  named the old `hivemind` persona.** `hivemind` was split into
  `spec-master` + `task-master` back in v0.10.0 (see
  `docs/adr/0003-hivemind-split-spec-master-task-master.md`), but the
  plugin manifest's `description` field — shown in the Claude Code plugin
  marketplace/install UI — was never updated to match. The optional-personas
  list now reads `spec-master/task-master/scribe/reviewer/researcher/
  milestone-auditor`.

## [0.12.0] - 2026-07-15

### Added
- **12 `mattpocock/skills` vendored first-party** into `skills/` (verbatim,
  with provenance headers and a pinned upstream SHA): `grill-me`, `grilling`,
  `handoff`, `to-spec`, `to-tickets`, `tdd`, `diagnosing-bugs`,
  `improve-codebase-architecture`, `codebase-design`, `domain-modeling`,
  `implement`, `code-review` — see `skills/THIRD-PARTY-NOTICES.md` for the
  full MIT notice and per-skill upstream paths. `to-spec`/`to-tickets`/
  `code-review` are documented repoints (their `/setup-matt-pocock-skills`
  reference replaced with antislop's native `install-antislop` setup;
  otherwise byte-verbatim).
- `docs/maintenance/resync-vendored-skills.md` + `scripts/resync-vendored-
  skills.sh --check`, an actionable periodic re-sync runbook/drift-check
  against the pinned upstream SHA.

### Removed
- **The `<MATTPOCOCK:slot>` substitution machinery** in `bin/cli.js`
  (`MATTPOCOCK_RE`, `applyMattpocockSubs`, `deriveMattpocockSubsForFile`,
  `hasMattpocockResidue`, the `substitutions.mattpocockSkills` backfill/map,
  the `--with-mattpocock`/`--only-mattpocock` install path) and the matching
  `bin/install-deps.sh` branch. Every persona reference that used to resolve
  through a slot (`spec-master`, `milestone-auditor`, `task-master`, `scribe`,
  `lead-programmer`) now points directly at the vendored `antislop:<name>`
  skill. `skills/install-antislop`'s mattpocock-selection step and
  `update-fallback.md`'s unresolved-slot recovery path are dropped
  accordingly; the issue-tracker capture the wizard used to seed is now a
  native `install-antislop` step (`issueTracker` in `persona-config.json`).
- **Capability loss (intentional, recorded per Constitution P4/OQ1):**
  removing the machinery removes the extension point for wiring an
  arbitrary *unported* mattpocock skill via a `<MATTPOCOCK:slot>` +
  `persona-config.json` map entry — that indirection no longer exists. A
  consumer who wants a new mattpocock (or any third-party) skill now adds it
  as a first-party `skills/<name>/` entry instead, the same pattern already
  used for `pathfinder`/`fail-triage`/the 12 skills above. See
  `docs/adr/0005-vendor-mattpocock-skills.md`.

## [0.11.0] - 2026-07-15

### Added
- **`handoff` skill** wired as the 7th `<MATTPOCOCK:slot>` passthrough
  substitution, preloaded into `lead-programmer` only and available
  project-wide as the `/handoff` slash command. Compacts a cut-off unit's
  conversation into a resumption doc (OS temp dir) for a fresh session to
  pick up. Complements, never replaces, the WIP sentinel — a resumption aid,
  not a turn-end permission signal; changes no gate.
- **`fail-triage` skill** (first-party, `skills/fail-triage`), a tailored
  derivative of `mattpocock/skills`' `triage` scoped only to the post-FAIL
  path (2-FAIL-cap / debug-spec escalation, not every FAIL). Wired into
  `spec-master`'s existing debug-spec step to sharpen its root-cause
  diagnosis with an explicit verify/reproduce + categorize front-half, before
  the existing revised-step format. Drops `triage`'s issue/PR state machine,
  label roles, external-PR request surface, `/grilling` +
  `/domain-modeling` deps, and `AGENT-BRIEF.md`/`OUT-OF-SCOPE.md` companion
  docs — same relocation pattern `pathfinder` used for `wayfinder`. The
  reviewer PASS gate and normal first-FAIL→`lead-programmer` route are
  unchanged; `orchestrator.md`/`persona-protocol.md` are not touched.

## [0.10.0] - 2026-07-15

### Changed
- **`repo-historian` renamed to `scribe`** throughout the plugin source,
  adapted copies, adapters (cursor/codex), install-antislop, and living docs
  (Track 1). `agents/repo-historian.md` → `agents/scribe.md`; frontmatter
  `name: repo-historian` → `name: scribe`; "Historian updates"/"Historian
  update hint" → "Scribe updates"/"Scribe update hint" in prose.
- **`hivemind` split into `spec-master` + `task-master`** (Track 3).
  `spec-master` keeps the 9-category ambiguity taxonomy, grill-me
  interrogation, Clarifications log, Constitution check, and Goal/Context/
  Steps spec authoring (now published via `to-spec`, see below), plus the
  debug-spec artifact for the 2-FAIL-cap escalation. `task-master` owns
  ticket-slicing (`to-issues`/`to-tickets`), per-unit `Suggested model`
  tagging (including advisory `Roast pass: fable` markers on heavy units),
  retrieval-contract statements, and per-unit dispatch prompts for
  `lead-programmer`/`scribe`. Neither persona re-plans on its own: a
  mid-flight spec gap discovered by `task-master` routes back up to
  `spec-master`, mirroring `lead-programmer`'s existing "report up" rule.
  `hivemind.md` is retired (both plugin-source and adapted copies).

### Added
- **`to-spec` wired into `spec-master`** via the existing
  `<MATTPOCOCK:slot>` substitution mechanism (Track 2) — the published
  `mattpocock/skills` skill that synthesizes the current conversation into a
  spec and publishes it to the project issue tracker. Its own PRD template
  (Problem Statement / Solution / User Stories / Implementation Decisions /
  Testing Decisions / Out of Scope) is layered on top of the existing
  spec-kit format rather than replacing it; `spec-master` still saves the
  full spec to `docs/plans/` in addition to `to-spec`'s tracker publish.
- **`pathfinder` skill** (first-party, `skills/pathfinder`), wired into
  `task-master` for slicing a finalized spec into dispatch-ready units —
  sizing, naming, and ordering guardrails adapted from
  `mattpocock/skills`' `wayfinder` for reliable, unambiguous
  lead-programmer/scribe dispatch.
- **`roast-work` skill** (first-party, `skills/roast-work`), wired into
  `reviewer` as a supplementary, advisory critique pass — never a PASS/FAIL
  gate. Surfaces contradictions, missing parts, logic gaps, and security
  vulnerabilities beyond the reviewer's existing materiality filter, and
  routes heavy review units to a `fable`-tier model for the extra pass.
- **`LEGACY_PERSONA_MAP` migration entries** in `bin/cli.js` for both
  renames above: `planner` → `hivemind` → `spec-master` + `task-master`
  (a two-hop chain — `resolveLegacyToken` now recurses through intermediate
  legacy tokens) and `repo-historian` → `scribe`. A project adapted at an
  older plugin version that still selects a legacy token gets migrated
  automatically on `--update`, with a logged note explaining the rename.

## [0.9.0] - 2026-07-14

### Added
- **Four spec-kit-inspired additions** to the plan/review/audit loop, per
  `docs/specs/2026-07-14-speckit-ports.md`:
  - An opt-in, per-project `.claude/constitution.md` (versioned
    project-specific principles), offered by a new `install-antislop`
    section 6.5 and consulted by `hivemind` (Constitution check), `reviewer`
    (MUST-violation FAIL reason), and `milestone-auditor` (premise grilling)
    when present.
  - A 9-category ambiguity taxonomy scorecard in `hivemind`, run before
    `grill-me`, plus a dated `## Clarifications` log capped at 5 questions
    per plan.
  - A pre-handoff requirements self-check in `hivemind` — "unit tests for
    the spec" — that revises the plan once before converting unresolved
    failures to Open Questions.
  - A named `unconverged-requirement` finding category in
    `milestone-auditor`'s existing audit pass, with append-only follow-up
    steps routed back to `hivemind` (never actioned by the auditor itself).

### Verification methodology
- Grep-checked against the spec's own acceptance criteria (all pass), but
  static text checks only confirm the prose is *present*, not that a real
  dispatch *follows* it — so this round also ran three live-dispatch
  simulations, each via a Fable-model "overseer" agent that built a fresh
  dummy project and used the `Agent` tool to actually invoke the real,
  freshly-edited `hivemind`/`reviewer`/`milestone-auditor` personas against
  it (not a hypothetical read-through):
  - **Round 1** (small dummy CLI project): found all four features
    textually correct but behaviorally degraded under real dispatch — the
    Clarifications scorecard and Self-check list collapsed into free prose,
    and `reviewer`'s constitution citation dropped its version number.
  - **Round 2** (harder multi-module dummy REST API, `fable`-tier dispatch):
    confirmed the gap sharply — all four literal formats failed outright
    under `fable`, and even `opus` reached only partial compliance on the
    two hardest ones (Clarifications' two-part shape, Self-check's itemized
    list). Isolated the cause: the prose described the required *shape* but
    never *showed* it.
  - **Round 3** (third dummy project, `fable`-only, no opus escalation):
    after adding a concrete fenced-code worked example for each literal
    format directly into `agents/hivemind.md`, `agents/reviewer.md`, and
    `agents/milestone-auditor.md`, all four features reliably produced
    their exact required shape under `fable` — closing the gap rounds 1-2
    identified. Two remaining cosmetic blemishes (a dropped `Q ... →` clause
    on one self-resolved line; a `P<n>` numeral folded into a principle-name
    citation) were fixed with one wording tweak each and re-verified clean.
  - Net effect: every literal-format requirement added this release ships
    with a worked example, not just a structural instruction — empirically
    necessary for reliable compliance at the `fable` tier, not a style
    preference.

## [0.8.0] - 2026-07-14

### Added
- **Codex port (MVP): the always-on subagent-orchestrator loop now ships for
  Codex CLI** alongside the existing Claude Code and Cursor plugins, under a
  new self-contained `adapters/codex/` tree. Implements
  `docs/specs/codex-plugin.md` in full (a design pass that itself supersedes
  the Codex column of `docs/specs/codex-cursor-plugin.md`, re-verifying its
  research live against `learn.chatgpt.com/docs/*`). Delivered:
  - **Four persona definitions** in Codex's native TOML format
    (`adapters/codex/agents/{orchestrator,explorer,lead-programmer,reviewer}.toml`)
    — persona *body* prose ported verbatim into `developer_instructions` as a
    literal (non-escape-processing) multi-line string, since the bodies'
    shell/printf examples contain literal backslash sequences a TOML *basic*
    multi-line string would have silently reinterpreted. `explorer.toml`
    keeps **per-agent MCP scoping** for the Code Review Graph — the one
    primitive Codex preserves that the Cursor port had to give up (Cursor's
    subagents inherit all parent MCP tools; Codex's do not).
  - **Enforcement hooks** as `adapters/codex/hooks/hooks.json` (confirmed
    live to use the SAME nested `{matcher?, hooks:[{type,command}]}` shape as
    Claude's, not Cursor's flatter list) plus five scripts: protected-paths,
    graph-update, lint-on-edit, stop-gate, and reviewer-route-gate. Each
    keeps the Claude/Cursor version's decision logic and swaps in a Codex
    payload-extraction preamble (`.cwd` for the project dir, `.agent_id`/
    `.agent_type` for identity, `.session_id` for the baseline). Protected-
    paths/graph-update/lint-on-edit additionally parse OpenAI's documented
    `apply_patch` patch-header format (`*** Add/Update/Delete File: <path>`)
    as a fallback when no single-file `tool_input` key is present, since
    Codex's canonical edit tool can touch multiple files in one call, unlike
    Claude/Cursor's one-file-per-invocation tools. `stop-gate.sh` also
    implements a self-tracked loop guard (no Codex-native
    `stop_hook_active`/`loop_count` equivalent was found) and keys the
    pending-review flag off `agent_id`, which — if that field is genuinely a
    stable per-spawn-instance id — fixes the Cursor port's known
    concurrent-same-type-subagent limitation outright.
  - **The shared persona-protocol** inlined directly into the project's
    `AGENTS.md` (`adapters/codex/agents-md-fragment.md`, upserted between
    version-agnostic marker comments) since Codex's AGENTS.md has no
    `@import`/include mechanism (confirmed) — unlike Cursor's separate
    always-apply rule file. Also inlined as a backstop digest into every
    persona's `developer_instructions`, since whether AGENTS.md content
    empirically reaches spawned subagents is doc-stated but not yet
    confirmed against a live build.
  - **Plugin packaging** (`adapters/codex/.codex-plugin/{plugin.json,
    marketplace.json}`) — deliberately does NOT bundle agent definitions via
    the plugin manifest, since Codex's documented plugin components are
    skills/mcpServers/apps/hooks only with no confirmed `agents` pointer;
    the four persona TOMLs are instead delivered by the scaffolder copying
    them straight into the project, same as the Claude/Cursor paths already
    do.
  - **Scaffolder support**: `bin/cli.js --target=codex` scaffolds all of the
    above into a project's `.codex/`, plus a new `upsertMarkedBlock` helper
    for the AGENTS.md inlining and a new `applyMcpTomlPlaceholder`/
    `renderMcpTomlBlock` pair (used by `--wire-graph-mcp --target=codex`) for
    rescoping the Code Review Graph into `explorer.toml`.
  - **`docs/codex-port-notes.md`** documenting what ported cleanly, which
    `docs/specs/codex-plugin.md` §12 open questions resolved vs. remain
    unverified (no `codex` CLI was available to probe live against), what
    was dropped, and two TOML-substitution bugs this port's own end-to-end
    scaffold test caught and fixed before they shipped.
- `tests/validate.sh` gained a Codex-artifacts section (bash syntax on hook
  scripts, JSON parse on hooks/plugin/marketplace manifests, TOML parse +
  required-field check on the four agent TOMLs, and a check that the
  AGENTS.md fragment source never bakes in the scaffold-time-only markers).

### Degraded / dropped on Codex (loud, not silent — see docs/codex-port-notes.md)
- **AGENTS.md-reaches-subagents is doc-stated but empirically unverified** —
  every persona TOML also inlines the load-bearing protocol digest as a
  backstop, same mitigation the Cursor port used for its own (weaker) version
  of this same open question.
- **reviewer-route-gate's "lead-programmer must not spawn the reviewer
  directly" half is instruction-only** — no confirmed field exposes the
  *calling* agent's identity on `SubagentStart`, only the spawned agent's own
  `agent_id`/`agent_type`. The pending-review dispatch-block half is
  mechanical regardless.
- Per-agent **tool allowlist** (beyond `sandbox_mode`), **`maxTurns` caps**,
  and **`memory: project`** all degrade to instruction-only/file-convention,
  matching the Cursor port's equivalents. Agent-teams mode, the
  `TaskCompleted`/task-gate (Codex has no such event), and structured
  user-question prompts are dropped, same as Cursor.
- **No `--update` support for the Codex target** — matches the Cursor port's
  own scope; only fresh-scaffold and `--overwrite` are implemented.
- The reviewer ships `sandbox_mode = "workspace-write"`, not `read-only` —
  a deliberate deviation from this port's own spec, decided rather than left
  open: Codex's sandbox is a real OS-level filesystem restriction (unlike
  Cursor's IDE-level tool gate), so `read-only` would almost certainly block
  the reviewer's Bash-invoked PASS/FAIL marker write.

## [0.7.2] - 2026-07-14

### Changed
- **Renamed the `setup-personas` skill to `install-antislop`** (directory
  `skills/setup-personas/` -> `skills/install-antislop/`, frontmatter
  `name:` field, and every source/doc/hook reference to it, including the
  `<REAL_LAUNCH_COMMAND_FROM_SETUP_PERSONAS_STEP_*>` placeholder tokens,
  which are now `..._INSTALL_ANTISLOP_...`). The command moves from
  `/antislop:setup-personas` (bare `/setup-personas` on the no-plugin CLI
  route) to `/antislop:install-antislop` (bare `/install-antislop`).
  Pre-v0.7.2 CHANGELOG entries below still say `setup-personas` — that was
  the name at the time and is left as-is rather than rewritten.

### Fixed
- **`stop-gate.sh`'s pending-review flag no longer clobbers a `defer:`/`skip:`
  reason on a repeat `SubagentStop`.** A gated agent resumed multiple times
  for check-ins on one long-running unit (not just its final, genuinely
  finished stop) re-triggers `SubagentStop` each time, and the flag write at
  step 2.5 was an unconditional overwrite — so a `defer: <reason>` the main
  session had written into the flag (the documented escape hatch at step
  0.75) got wiped back to a bare `agent=...` timestamp on the very next
  check-in, forcing the same block/defer cycle to repeat on every resume of
  that unit. The flag write is now idempotent: it only creates the flag if
  one doesn't already exist, so a defer/skip reason survives later
  `SubagentStop`s from the same `agent_id`, while a genuinely new unit (new
  `agent_id`) still gets a fresh flag. Applied to both the Claude Code hook
  (`hooks/scripts/stop-gate.sh`) and the Cursor port
  (`adapters/cursor/hooks/scripts/stop-gate.sh`).

## [0.7.1] - 2026-07-13

### Fixed
- **The v0.6.4 "`--update` is a deterministic script" fix didn't actually
  reach every project.** Any project adapted before v0.6.4 (missing
  `persona-config.json`'s `substitutions`/`fileHashes`) still hard-failed
  `bin/cli.js --update` straight into the old LLM-driven full re-derivation —
  the exact 100K-token, ~15-minute flow the script was supposed to replace,
  and a broad condition (every pre-v0.6.4 project), not a rare edge case.
  `bin/cli.js --update` now auto-backfills both fields deterministically from
  whatever's already on disk (zero LLM cost): `substitutions.mattpocockSkills`
  is reverse-derived by diffing the plugin's own source persona files against
  the project's already-substituted copies (a generic per-line diff —
  handles both the `skills:` frontmatter cases and `lead-programmer.md`'s
  body-prose placeholders with one algorithm); `substitutions.graphMcpLaunch`/
  `arxivMcpLaunch` are reverse-parsed from the already-rendered `mcpServers:`
  block in `explorer.md`/`researcher.md`; `fileHashes` adopts current on-disk
  content as the trusted baseline (logged loudly, since this is a one-time
  transitional gap for anyone with genuine pre-existing hand-edits). A single
  file/slot that still can't be determined (e.g. prose reworded across
  several plugin versions) no longer aborts the whole run — it's now
  collected and reported per-file, non-fatally, with a specific remediation,
  while every other file still updates normally in the same run. New test
  coverage: `tests/cli-backfill.test.js`, wired into `tests/validate.sh`,
  round-trips the new derivation logic against the real shipped `agents/*.md`
  content.
- **Every product-facing nudge pointed at the expensive path anyway.**
  `hooks/scripts/session-start.sh`'s version-drift warning and
  `hooks/scripts/task-gate.sh`'s two legacy-marker messages all told users to
  run `/antislop:setup-personas --update` (the 568-line LLM skill,
  invoked directly, bypassing the script entirely) instead of
  `/antislop:update-antislop` (the cheap command). Repointed all three.
- `skills/setup-personas/SKILL.md`'s own `--update` handling (section 11) was
  descriptive ("you only land here when the script says to") rather than
  imperative, so a direct `/antislop:setup-personas --update` invocation had
  nothing actually forcing it to run the script first. Section 11 now runs
  `bin/cli.js --update` as its explicit first action and only proceeds
  further based on the specific exit condition.
- Split `SKILL.md`'s two largest, least-often-needed sections out of the
  always-loaded file: the section 10 sandboxed hook-verification probe
  script moved to `skills/setup-personas/hook-verification.md` (read only by
  the delegated subagent that actually runs it); the old section 11 manual
  re-derivation flow was replaced with a much shorter
  `skills/setup-personas/update-fallback.md` scoped to resolving the one
  specific gap `bin/cli.js --update` names, not a full re-adapt. `SKILL.md`
  itself shrank from 568 to 491 lines.
- Updated `commands/update-antislop.md` and `README.md`'s update section to
  describe the narrower fallback surface, and fixed two stale in-code error
  messages (`applyMattpocockSubs`/`applyMcpPlaceholder` in `bin/cli.js`) that
  told users to re-run the very flow that had just failed to derive their
  value, instead of pointing at manual resolution or `--wire-graph-mcp`/
  `--wire-arxiv-mcp`.

## [0.7.0] - 2026-07-13

### Added
- **Cursor port (MVP): the always-on subagent-orchestrator loop now ships for
  Cursor** alongside the existing Claude Code plugin, under a new self-contained
  `adapters/cursor/` tree (kept separate so none of the Claude-only artifacts
  change). Implements the spec's §5 MVP milestone from
  `docs/specs/codex-cursor-plugin.md` — the Codex half is deliberately NOT
  built here. Delivered:
  - **Four persona definitions** in Cursor's native format
    (`adapters/cursor/agents/{orchestrator,explorer,lead-programmer,reviewer}.md`)
    — markdown + `name`/`description`/`model`/`readonly` frontmatter. The
    persona *body* prose is ported faithfully from `agents/*.md`; only the
    frontmatter and platform-specific mechanics changed.
  - **Enforcement hooks** as `adapters/cursor/hooks/hooks.json` (`version: 1`,
    camelCase events `preToolUse`/`afterFileEdit`/`subagentStart`/`stop`/
    `subagentStop`) plus five scripts: protected-paths, graph-update,
    lint-on-edit, stop-gate, and reviewer-route-gate. Each script keeps the
    Claude version's decision logic and swaps in a thin Cursor payload-
    extraction preamble (project dir from `.workspace_roots[0]`,
    `subagent_type` for caller identity, `.loop_count` for the loop guard,
    `.conversation_id` for the baseline).
  - **The shared persona-protocol** as an `alwaysApply: true` Cursor rule
    (`adapters/cursor/rules/persona-protocol.mdc`).
  - **Plugin packaging** (`adapters/cursor/.cursor-plugin/{plugin.json,
    marketplace.json}`).
  - **Scaffolder support**: `bin/cli.js --target=cursor` scaffolds all of the
    above into a project's `.cursor/`, reusing the existing "merge, never
    clobber" discipline (hooks.json is deep-merged; `--overwrite` preserves the
    judgment-driven persona-config fields).
  - **`docs/cursor-port-notes.md`** documenting what ported cleanly, what
    degraded (per spec §2A/§2D), which §6 open questions were resolved vs. left
    as loud unverified assumptions, and what was explicitly dropped.
- `tests/validate.sh` gained a Cursor-artifacts section (JSON parse of the
  hooks/plugin/marketplace manifests, frontmatter check on the Cursor agents,
  bash syntax check on the Cursor hook scripts).

### Degraded / dropped on Cursor (loud, not silent — see cursor-port-notes.md)
- **Rule cascade into subagents is UNVERIFIED** (spec §6 open q #1). Because
  the protocol *is* the safety system, its load-bearing invariants (review
  ownership, structural-questions-to-explorer, FAIL cap, WIP sentinel) are
  inlined into each subagent body as a guaranteed-delivery backstop in addition
  to the alwaysApply rule.
- **reviewer-route-gate's "lead-programmer must not spawn the reviewer" half is
  instruction-only** — Cursor's `subagentStart` payload carries the spawn
  target but not the caller (spec §6 open q #5). The pending-review half (block
  the next gated dispatch while a unit awaits review) is still mechanical.
- Per-agent **tool allowlist** (beyond `readonly: true`), **maxTurns caps**,
  **per-agent MCP scoping** (graph goes project-wide), and **`memory: project`**
  all degrade to instruction-only / file-convention, matching spec §2A–§2E.
  Agent-teams mode, the `TaskCompleted`/task-gate, and structured
  user-question prompts are explicitly dropped (spec Tier 3).
- This Cursor pass intentionally does NOT do the spec §4 shared-body refactor
  (splitting `agents/*.md` into `*.body.md` + per-platform wrappers), so the
  Cursor persona bodies and hook logic are hand-ported copies — a
  duplication-drift risk that §4's architecture would remove once Codex also
  exists.

## [0.6.5] - 2026-07-13

### Changed
- **Trimmed token bloat across every always-loaded prompt file** — the
  persona bodies (`agents/*.md`), `templates/persona-protocol.md` (imported
  into every persona's and the main session's context via CLAUDE.md, every
  turn), `templates/protocol-digest.md` (re-injected on every resume/compact),
  `skills/coding-discipline/SKILL.md` (preloaded on most lead-programmer/
  reviewer turns), `skills/setup-personas/SKILL.md`, and
  `commands/start-feature-team.md`. Found via a dedicated review pass: the
  same rule or rationale was frequently stated 2-4 times (a comment, then
  body prose, then again in `persona-protocol.md` which is already in every
  persona's context) — cut the redundant restatements, kept the single
  clearest instance. Net ~111 lines removed across 10 files. Did not touch
  anything encoding an actual constraint, a non-obvious gotcha, or a
  confirmed-bug fix (frontmatter-first-bytes, `mcpServers` list-vs-map,
  empty-sentinel-bypass, SKILL.md section 10's regression tests, etc.) — those
  earned their length and stay as-is.

## [0.6.4] - 2026-07-13

### Changed
- **`--update` is now a deterministic script, not an LLM skill invocation.**
  `/antislop:update-antislop` and the npx bare route both now shell straight
  out to `bin/cli.js --update`, which regenerates each version-stamped file
  directly from the plugin's own source plus the substitution values
  recorded in `persona-config.json` at ADAPT time, and only touches a file
  once it's byte-identical to the last known-clean baseline. This was
  previously implemented as `skills/setup-personas/SKILL.md` section 11,
  which meant loading the entire ~530-line, multi-thousand-token skill file
  to do work that section 11 itself only needed ~40 lines of — every
  `--update` run paid for reading the whole fresh-install flow (persona
  wizard, third-party installs, MCP wiring, CLAUDE.md pruning, hook
  verification) it never executed. The common case (no local edits) now
  costs no meaningful tokens; a file only escalates to a *human* decision
  (never an LLM one) when it's genuinely diverged from a fresh copy, via new
  `--accept=<paths>`/`--keep=<paths>` flags (`=all` for both). `--keep`
  deliberately does not "rebase" a file's clean-baseline hash to the kept
  content — doing so would let a later version bump that happens to leave
  the upstream file unchanged silently overwrite the very customization
  `--keep` was asked to preserve; instead the file is re-flagged for a
  decision on every future drift, by design.
- `persona-config.schema.json` gained two fields backing the above:
  `substitutions` (the `mattpocockSkills` slot map, `graphMcpLaunch`,
  `arxivMcpLaunch` — the values ADAPT resolved, so a script can re-derive a
  byte-identical file without guessing at them) and `fileHashes` (the
  known-clean baseline per stamped file). `setup-personas` steps 3-6 now
  record both as they resolve each substitution. Projects adapted before
  this field existed fall back once to the old LLM-driven flow (now section
  11's sole remaining job), which backfills both fields so every later
  update runs through the script.
- Added `bin/cli.js --wire-graph-mcp` and `--wire-arxiv-mcp=<server-key>`:
  read a tool-generated project-wide `.mcp.json` entry, inline its launch
  command into `explorer.md`/`researcher.md`'s `mcpServers:` frontmatter,
  remove the project-wide entry, and record it in `persona-config.json`'s
  `substitutions` — mechanizing the copy/rescope half of `setup-personas`
  steps 4-5 (verifying the connection actually works is still a judgment
  call left to the LLM/human).

## [0.6.3] - 2026-07-13

### Added
- **`commands/update-antislop.md`**: dedicated `/antislop:update-antislop`
  command for plugin-installed projects — a named entry point into
  `skills/setup-personas/SKILL.md`'s section 11 (`--update` mode), instead of
  only being reachable via the `--update` flag on `/antislop:setup-personas`.
  `/antislop:setup-personas --update` still works identically; this is an
  additive alias, not a replacement. npx-scaffolded projects (which don't get
  project-local plugin commands) keep using bare `/setup-personas --update`.
  README, CONTRIBUTING.md, docs/design.md, templates/persona-protocol.md, and
  the bug report template now point at `/antislop:update-antislop` as the
  primary plugin-path instruction. Hardened after an Opus critic pass found
  two gaps: it now checks for `.claude/persona-config.json` first and stops
  with a clear "run `/antislop:setup-personas` instead" message on a
  never-adapted project, rather than delegating straight into section 11
  against a missing file; and it invokes the `/antislop:setup-personas` skill
  itself (letting Claude Code resolve the plugin-root path) instead of
  telling the agent to read `skills/setup-personas/SKILL.md` by a
  project-relative path, which doesn't resolve on a plugin install.

## [0.6.2] - 2026-07-13

### Added
- **`bin/install-deps.sh`**: idempotent installer for the two conditional
  third-party dependencies (Code Review Graph, mattpocock/skills). Skips
  whichever is already present (checks `code-review-graph` on `PATH`, and
  `~/.agents/.skill-lock.json` for a `mattpocock/skills` source entry), so
  it's safe to run repeatedly and works from either install path
  (marketplace or npx), not just the npx CLI. Supports `--only-graph` /
  `--only-mattpocock` to run a single step. Referenced from the README
  Requirements section.

### Changed
- `bin/cli.js`'s `--with-mattpocock` and `--with-graph` flags now delegate
  to `install-deps.sh` instead of duplicating the pipx/npx install calls
  inline, so re-running them no longer unconditionally reinstalls/reopens
  the picker when the dependency is already satisfied.

## [0.6.1] - 2026-07-13

### Fixed
- **No persona had `SendMessage` in its `tools:` list** (#9), so in
  agent-teams mode a named teammate's `idle_notification` — a lifecycle
  signal only, never a report payload — was the team lead's only signal that
  a teammate was done, and its only lever to check further was re-invoking
  `Agent` with the teammate's existing name. That doesn't resume the
  teammate; it silently spawns an unrelated `<name>-2` sibling, so the
  original teammate's actual report never reached the lead through any
  channel its tools exposed. Added `SendMessage` to `orchestrator.md`,
  `lead-programmer.md`, `hivemind.md`, `repo-historian.md`, `reviewer.md`,
  `explorer.md`, and `researcher.md.tmpl`'s `tools:` lines, and documented
  both directions of the fix: `orchestrator.md` and
  `commands/start-feature-team.md` now tell the lead to `SendMessage` an
  idle teammate by name to resume/retrieve its report instead of
  re-invoking `Agent`; `lead-programmer.md`'s ready-for-review handoff and
  `templates/persona-protocol.md`'s agent-teams section now tell a teammate
  to push its report to the lead via `SendMessage` on finishing a unit,
  since plain turn-text isn't visible to other agents. Not a duplicate of
  #5 (`TaskStop`/`TaskOutput` for subagent-orchestrator-mode liveness) or #8
  (same "fresh dispatch instead of resume" symptom, but scoped to
  backgrounded-Bash races in subagent-orchestrator mode) — this is the
  agent-teams-mode named-teammate resume path specifically.
- `package.json`'s version had drifted behind `.claude-plugin/plugin.json`
  since the 0.6.0 release (stuck at 0.5.5) — resynced both to 0.6.1.

## [0.6.0] - 2026-07-13

**Upgrade caveat (read first if you have an adapted project):** the PASS
marker format changed (v1 → v2, see below) and `task-gate.sh` now enforces
it. A project whose copied `agents/reviewer.md` predates this version still
writes the old bare `touch` marker. **A two-week grace period softens the
cutover**, through 2026-07-27: until then, a legacy marker gets a loud
warning (logged to `.claude/review-audit.log`) but is still allowed to
complete; on or after 2026-07-27, `task-gate.sh` BLOCKS it unconditionally at
`TaskCompleted`. Run `/antislop:setup-personas --update` before that date to
refresh the copied persona files and avoid the block.

### Added
- **PASS marker format v2** (`hooks/scripts/task-gate.sh`,
  `agents/reviewer.md`, `commands/start-feature-team.md`,
  `templates/persona-protocol.md`): the reviewer (and the no-reviewer
  fallback lead) now write `PASS <task-id> <UTC ISO-8601 timestamp> criteria:
  <acceptance-criteria command(s) run>` as the marker's first line via
  `printf`, instead of a bare `touch`. `task-gate.sh` validates the format
  and content, not just existence, and logs accepted markers to the new
  `.claude/review-audit.log`. A malformed/legacy marker is rejected with an
  instructive block message naming the exact `printf` command and pointing
  at `--update` as the likely remedy — see the upgrade caveat above.
  **Two-week grace period:** before 2026-07-27, a legacy marker is warned
  about (`legacy-marker-grace-period-warning` in `.claude/review-audit.log`)
  but still allowed; on or after that date the rejection above is
  unconditional. One-time softening of this v1→v2 cutover, not a standing
  feature.
- **Pending-review gate** (`hooks/scripts/stop-gate.sh`,
  `hooks/scripts/reviewer-route-gate.sh`): the default (subagent-orchestrator)
  mode gains its first mechanical backstop for "done = reviewer PASS,"
  mirroring what `TaskCompleted` already enforced in agent-teams mode. A
  gated agent's un-reviewed `SubagentStop` (not honoring a WIP sentinel)
  writes `.claude/.pending-review.<agent_id>`; a reviewer's own stop clears
  all such flags and logs to `.claude/review-audit.log`. While a flag stands,
  `stop-gate.sh` blocks main-session turn-end and
  `reviewer-route-gate.sh` blocks dispatching another gated-agent unit,
  with a `defer:`/`skip:` escape hatch mirroring the existing WIP-sentinel
  pattern. Honest limit: this cannot force the orchestrator's next action —
  it blocks turn-end/dispatch and leaves an audit trail, same as the
  sentinel; `rm` via Bash remains possible.
- **`reviewed-path-gate.sh`** (new `PreToolUse`/`Bash` hook): gates Bash
  writes to `.claude/reviewed/` by caller `agent_type` (reviewer allowed;
  lead-programmer and other writer personas blocked; main session allowed
  only under the documented no-reviewer fallback). Built and scoped against
  an empirically-probed payload shape (`docs/experiments/2026-07-probe-hook-payloads.md`)
  — its known attribution limits (a `cat`-of-a-marker is collateral-blocked;
  a sufficiently obfuscated write can dodge the string match, in which case
  `task-gate.sh`'s content validation is the second layer) are recorded in
  README's "Known limitations."
- **`hivemind` and `milestone-auditor` gain orchestrator-decided Opus|Fable
  dispatch routing** (`agents/orchestrator.md`'s "Per-unit model routing"
  section, new `### Opus|Fable routing for hivemind and milestone-auditor`
  subsection): `hivemind` dispatches on `fable` only when scope is already
  enumerated, the change rides existing seams, and no interrogation is
  needed (all three, conjunctively); `milestone-auditor` dispatches on
  `fable` only when the milestone was mechanical end-to-end (every unit
  `haiku`-tagged, no first-pass FAIL, no human challenge at the pre-audit
  checkpoint). Frontmatter `model: opus` stays the default for both —
  fable is per-dispatch only, never the standing tier. **Cost framing,
  honestly:** this is a routing heuristic, not a structural saving — worst
  case is unchanged from today (both personas can still run on Opus every
  time); the common case is cheaper only when the orchestrator's heuristic
  actually routes well-scoped work to Fable. A wrong-cheap dispatch
  escalates to `opus` on retry, mirroring the existing haiku-unit
  escalation rule.
- **Pre-audit human-grilling checkpoint** (`agents/orchestrator.md`'s
  "Milestone audit gate" section): before every `milestone-auditor`
  dispatch, the orchestrator now fetches the plan's Goal/assumptions/Open
  Questions and surfaces them to the human via `AskUserQuestion` as a quick
  confirm/challenge pass. A material human challenge routes back to
  `hivemind` for a re-plan instead of spending an Opus audit run on an
  already-invalidated plan; a clean checkpoint still requires the full
  audit — it is not a substitute for it.
- **Durable FAIL record** (`agents/reviewer.md`, `templates/persona-protocol.md`):
  on a FAIL verdict the reviewer now also writes
  `.claude/reviewed/<task-id>.fail` (defect list + timestamp, both modes) —
  not for any hook gate (none needed changing), but as a standing warning
  for a future `hivemind` or orchestrator spawn with no memory of this
  session. `agents/orchestrator.md`'s per-unit and Opus|Fable routing rules
  both treat an existing `.fail` record as a hard disqualifier for
  haiku/fable dispatch on that unit; `agents/hivemind.md` checks for one
  before retagging or re-scoping.

### Changed
- **`planner` renamed `hivemind` repo-wide** (display name "HiveMind" in
  unbackticked README prose only; the machine-facing slug stays lowercase
  everywhere else): `agents/planner.md` → `agents/hivemind.md`, every
  routing-table/prose/eval-variant reference, `bin/cli.js`'s
  `OPTIONAL_PERSONAS`/wizard labels, `templates/persona-config.schema.json`,
  `templates/persona-protocol.md`, `templates/researcher.md.tmpl`,
  `commands/start-feature-team.md`, `skills/setup-personas/SKILL.md`,
  `tests/validate.sh`, `eval/harness/scaffold.sh`, and
  `.claude-plugin/plugin.json`'s description. `bin/cli.js --personas=` and
  the `--overwrite`-reuse-selection path both accept the legacy `planner`
  token, map it forward to `hivemind`, and print a deprecation note instead
  of silently dropping it (the pre-rename intersection filter would have
  dropped an unrecognized token with no error). `skills/setup-personas/SKILL.md`
  section 11 (`--update` mode) gained an explicit migration rule: a project
  whose recorded `personaSelection` still says `planner` gets its copied
  agent file renamed/re-derived, its `personaSelection` rewritten, and the
  migration reported. `milestone-auditor` was NOT folded into `hivemind` —
  it stays a separate, memory-less persona; its deliberate absence of a
  `memory:` field (fresh-eyes isolation) is unchanged.
- README's "Cost" section reworded for the dual-model routing above,
  honestly: the smaller-standing-roster savings argument belonged to a fold
  that was proposed and explicitly rejected (see Open Questions in the
  source plan) and does not appear here in any form — `hivemind`,
  `reviewer`, and `milestone-auditor` all still DEFAULT to the pricier tier
  and remain the real spend drivers; the cheaper model is an
  orchestrator-routed discount on top, not a lowered baseline.
- README's orchestrator-drift-surface bullet updated: the main session is
  still deliberately uncapped, but the pending-review gate above gives it
  its first mechanical backstop — "biggest open drift surface" becomes
  "partially closed," not fully closed.

### Reviewed, not changed
- lead-programmer's TDD-first mandate was reviewed for a conditional
  (haiku-tagged-step / no-reviewer-project) carve-out and deliberately kept
  **unconditional**, exactly as written before this release
  (`agents/lead-programmer.md` and its eval-variant twin are untouched) —
  recorded here so the question isn't re-litigated from silence.

## [0.5.5] - 2026-07-13

### Added
- `agents/planner.md`: plan steps now carry a `Suggested model:
  haiku|sonnet` tag (mechanical/low-judgment work → haiku, anything needing
  design judgment, cross-file reasoning, or hard-bug diagnosis → sonnet,
  default to sonnet when unsure), carried unchanged through `to-issues` into
  each unit.
- `agents/orchestrator.md`: new "Per-unit model routing" section — reads a
  unit's `Suggested model` tag and passes it as the dispatch's `model`
  parameter when spawning `lead-programmer`, relying on Claude Code's
  documented per-invocation model override (env var > per-call param >
  frontmatter); omitted tags fall back to lead-programmer's own `model:
  sonnet` default. Added an escalation rule: a haiku-run unit that FAILs
  review re-dispatches on sonnet rather than haiku again, still counting
  against the existing 2-FAIL cap.

## [0.5.4] - 2026-07-12

### Fixed
- `skills/setup-personas/SKILL.md` step 3: mattpocock skill substitution no
  longer trusts hardcoded assumed names (`to-issues`, `diagnose`) — it now
  resolves each `<MATTPOCOCK:*>` placeholder from the actually-installed
  skill's discovered `name:` frontmatter (the real names are `to-tickets`
  and `diagnosing-bugs`), with a new step 3b fail-fast check right after
  substitution. (#1)
- `skills/setup-personas/SKILL.md` step 12: added a mandatory placeholder
  sweep (`grep -rEn '<[A-Z0-9_]+(:[a-zA-Z0-9_-]+)?>' ...`) that must return
  zero matches before the skill can report an adapt run done. (#2)
- `skills/setup-personas/SKILL.md` step 6: `testAndLintCommand` is now run
  once against the clean tree before being written into
  `persona-config.json`; a failing command is surfaced to the human as an
  explicit choice instead of silently becoming a permanently-red stop-gate.
  (#3)
- `hooks/scripts/stop-gate.sh`: `gatedAgents` scoping now also applies to
  the main-session `Stop` event (previously only `SubagentStop`), keyed off
  `settings.json`'s configured main agent. Removes redundant WIP-sentinel
  churn on every orchestrator turn-end while a gated subagent is mid-flight.
  (#4)
- `agents/explorer.md`, `templates/researcher.md.tmpl`: fixed `mcpServers`
  frontmatter from an invalid flat map to the correct list-of-single-key-
  dicts-with-`type:` schema — the flat form silently failed to connect,
  falling back to grep/WebSearch with no visible error anywhere.
  `setup-personas` steps 4-5 now require the verification query's answer to
  self-report MCP-derived vs. fallback-derived provenance, since a
  plausible-looking answer isn't proof the connection is live. (#7)
- `agents/orchestrator.md`: granted `TaskStop`/`TaskOutput` (previously
  missing from its `tools:` allowlist, which replaces rather than extends
  the inherited toolset) plus a new "Managing a long-running background
  dispatch" section instructing it to poll via `TaskOutput(block=false)`
  before ever reaching for `TaskStop`. Root-cause investigation found the
  originally-reported harness gap (no cancel/liveness primitive for a
  background Agent task) was already closed upstream as of Claude Code
  2.1.187; the actual cause of the reported session failure was this
  missing tool grant. (#5)

### Added
- `skills/setup-personas/SKILL.md` new section 0.5: when
  `.claude/persona-config.json` already exists and the invocation isn't
  `--update`, the skill now runs an explicit `AskUserQuestion` decision
  tree (resume / patch gaps only / full restart) instead of silently
  falling through to a fresh 12-section run. (#6)
- `templates/researcher.md.tmpl`: added a `Fallback` self-report bullet
  mirroring `explorer.md`'s existing one, so a broken arXiv MCP connection
  has a chance to be reported rather than silently absorbed by
  `WebFetch`/`WebSearch`.

## [0.5.3] - 2026-07-12

### Added
- `bin/cli.js` gained an `--overwrite` flag: re-copies agents/hooks/skills/
  protocol unconditionally even over an existing install, instead of always
  refusing (previously the only path forward was the LLM-driven
  `/setup-personas --update` diff flow). Preserves `persona-config.json`'s
  judgment-driven fields (`testAndLintCommand`, `protectedPaths`, etc.)
  exactly as recorded — only `personaSelection` and `pluginVersion` refresh.
  With no `--personas=`/`--yes` alongside it, reuses the project's
  already-recorded persona selection rather than silently changing which
  personas are installed.

## [0.5.2] - 2026-07-12

### Added
- `templates/persona-protocol.md` gained two cross-cutting rules, both
  proposed by `persona-improver` (`~/claude_trace`) from a real telemetry
  review of production usage, not written on assumption:
  - A name-collision warning: Claude Code's built-in `Explore` subagent can
    silently shadow this project's own `explorer` persona via
    description-based auto-delegation, since the built-in has no Code
    Review Graph MCP access and falls back to weaker grep-derived answers.
    Personas should spawn `explorer` by name, not rely on auto-delegation.
  - A "scope Bash output before it enters context" rule — pipe verbose
    commands through `head`/`tail`/`grep`/quiet flags before the output
    lands in context, rather than after.
  Both findings and patches are recorded in
  `~/claude_trace/.scratch/telemetry-review/telemetry_review_20260712_052612.md`
  and `~/otel/improvements.duckdb`.

## [0.5.1] - 2026-07-11

### Changed
- `lead-programmer` gained `maxTurns: 30` (previously uncapped — the last
  cost-bounding gap noted in 0.2.0's `maxTurns` rollout). `reviewer`'s
  verdict output contract was rewritten to be strictly terse — verdict-only
  final message, no restated context/summary. Both changes were validated
  against a real, controlled pilot (N=5 reps each vs. a matching N=5
  baseline) before shipping, not applied on assumption: maxTurns cap cut
  cost -10.4%/turns -38.1%/wall -15.4%; the terse contract cut cost
  -17.7%/turns -42.9%/wall -20.1%. Neither regressed the pilot's
  independent defect-catch check (18/18 held across the full pilot,
  including both these variants) — see `docs/experiments/pilot-2026-07-11.md`
  for the full experiment log and the `eval/` harness that produced it.

## [0.5.0] - 2026-07-11

### Changed
- Renamed the plugin from `seb-personas` to `antislop` — package name
  (`package.json`), CLI bin name, plugin id (`.claude-plugin/plugin.json`,
  `marketplace.json`), skill-namespace prefix
  (`seb-personas:coding-discipline` → `antislop:coding-discipline`), and all
  prose references across `README.md`, `CONTRIBUTING.md`, the bug report
  template, `setup-personas/SKILL.md`, `session-start.sh`, `validate.sh`,
  and `bin/cli.js`'s runtime strings and version-stamp comment format.
  Directory path (`~/seb_claude_setup`) intentionally left unchanged — this
  is an identity rename, not a relocation, so `~/claude_trace`'s
  `persona-improver.md`/`protected-paths.sh` references to that path still
  resolve.

## [0.4.2] - 2026-07-10

### Fixed
- `bin/cli.js`'s `copyStamped()` and `setup-personas/SKILL.md` step 2 both
  prepended the `<!-- seb-personas vX.Y.Z ... -->` version-stamp comment
  *before* the frontmatter's opening `---`. Confirmed via a live probe
  (`AWS_Learning`) that Claude Code's subagent discovery requires the file
  to start with `---` as its very first bytes — a leading comment silently
  breaks discovery, so every copied persona (`orchestrator`, `planner`,
  etc.) never registered as an invocable agent type, while a comment-free
  probe file worked fine. The stamp now lands immediately after the closing
  `---` in both the CLI and the skill instructions. Projects already
  scaffolded before this fix have the broken layout in their existing
  `.claude/agents/*.md` files and need those files' leading comment moved
  after the frontmatter (or re-run `setup-personas`/the CLI) to pick up the
  fix.

## [0.4.1] - 2026-07-10

Prompted by walking a real project (`AWS_Learning_Sim`) through install and
catching drift between this repo's design assumptions and how its two
third-party dependencies actually behave today.

### Added
- `seb-personas-setup` runnable npm package (`package.json` + `bin/cli.js`,
  `"private": true` — not published to the npm registry, clone + run via
  `npx /path/to/clone`): scaffolds the mechanical half of ADAPT
  (`.claude/agents/`, hooks, settings.json merge, protocol/digest copy,
  CLAUDE.md wiring, `.gitignore`), replacing `/plugin marketplace add` +
  `/plugin install` with one `npx` call for the file-scaffolding part (same
  clone/collaborator/git-auth prerequisites still apply). Deliberately stops
  short of the judgment-driven half (repo-scan for test/lint commands,
  graph/MCP wiring, hook verification) — copies `setup-personas`/
  `coding-discipline` in project-scoped and tells the user to run
  `/setup-personas` next to finish. Refuses to run over an existing
  `persona-config.json` rather than risk clobbering local edits. Also
  optionally launches the `mattpocock/skills` and `code-review-graph`
  installers itself (`--with-mattpocock`/`--with-graph`, inherited stdio so
  their own interactive prompts work normally) — it stops short of the
  `.mcp.json`→`explorer.md` rescoping (see Fixed below), leaving that to
  `/setup-personas` step 4 since it needs to inspect what the installer
  actually wrote, not a guessed schema.

### Fixed
- README's "real install" instructions used a generic `<owner>/<repo>`
  placeholder and a hardcoded local `~/seb_claude_setup` path in the
  `--plugin-dir` example; now names the actual GitHub slug
  (`Storreslara/My_Claude_Stuff`, which does not match the local clone
  directory name) and generalizes the local path.
- `setup-personas/SKILL.md` step 3: `npx skills@latest add mattpocock/skills`
  opens an interactive terminal picker with no documented non-interactive
  mode. The ADAPT skill previously had the agent attempt to drive this
  itself, which can hang or silently take defaults in a non-interactive
  shell and leave stale `<MATTPOCOCK:*>` placeholders with no error
  surfaced. Now the agent tells the human which skills to pick and asks
  them to run it, then verifies the installed skill list itself afterward.
- `explorer.md` and `setup-personas/SKILL.md` step 4 assumed the Code Review
  Graph installs as a bare-named project skill queried conversationally. Its
  real current install (`code-review-graph install --platform claude-code`)
  is an MCP server that registers itself PROJECT-WIDE in `.mcp.json` by
  default (every persona would inherit it — the exact context-bloat problem
  this system was designed to avoid) plus three unrelated build-graph/
  review-delta/review-pr workflow skills. `explorer.md` now carries its own
  scoped `mcpServers:` frontmatter (the same trick `researcher.md` uses for
  its arXiv MCP) and step 4 explicitly re-scopes the connection there
  instead of leaving the tool's project-wide registration in place.

## [0.4.0] - 2026-07-09

### Added
- `milestone-auditor` persona: an adversarial auditor of the *plan*, not the
  code — runs at milestone boundaries once every unit in it has already
  reviewer-PASSed, hunting for premise gaps and goal drift the reviewer
  structurally can't see. No PASS/FAIL, no override authority, no Write/Edit
  — only a findings list relayed to the human. Wired into README, the
  `persona-config` schema, and `setup-personas`'s selection/placeholder-
  substitution/mattpocock-skill steps.
- `orchestrator.md`: a Plan Mode gate. The harness's built-in Plan Mode ships
  its own Explore/Plan workflow that silently overrides the persona routing
  table and bypasses the Writer/Reviewer split for the whole turn; the
  orchestrator now recognizes this, exits Plan Mode, and re-routes through
  the normal pipeline instead.

### Fixed
- `commands/start-feature-team.md`: closed several gaps found in review —
  the `impl:<slug>` task-naming convention the `TaskCompleted` gate depends
  on was never actually instructed; the no-reviewer/crashed-reviewer path
  could deadlock the task list permanently; the reviewer was never told the
  exact task id needed for its PASS marker to match; FAIL routing didn't
  reference the shared protocol's 2-FAIL cap; the explorer-teammate
  framing contradicted the file's own header comment about subagent
  spawning; the native-plan-approval gate was unverifiable and is now
  secondary to the always-available prose rule.

### Changed
- Trimmed redundant/restated prose in `orchestrator.md` and
  `lead-programmer.md` (behavior unchanged, token cost per spawn reduced).

## [0.3.0] - 2026-07-09

Behavioral-drift hardening, prompted by an audit of which shared-protocol
rules were mechanically enforced vs. instruction-only, reviewed and
reprioritized by a second model pass.

### Added
- `templates/protocol-digest.md`: a short (~15-line) reminder of the
  highest-drift-risk rules (explorer routing, review ownership, the 2-FAIL
  cap, WIP sentinel legitimacy, the memory-grant caveat). `setup-personas`
  copies it to `.claude/protocol-digest.md`, version-stamped like
  `persona-protocol.md`, but does NOT import it into CLAUDE.md.
- `session-start.sh` now re-injects that digest via `additionalContext`, but
  only when the hook's `source` field is `resume` or `compact` — never
  `startup`/`clear`, where the full protocol is already freshly in context.
  This targets the exact moments a long-running session (the orchestrator's
  uncapped main session especially) is most likely to have summarized the
  protocol away. Mechanical timing of when the rules reappear, not more
  static prose to hope survives compaction.
- `hooks/scripts/reviewer-route-gate.sh`: a `PreToolUse` hook (matcher
  `Agent`) mechanically blocking lead-programmer from spawning the reviewer
  directly, closing the payload-attribution question this same section
  previously deferred (see below). Confirmed empirically, not assumed: a
  nested `Agent`-tool call's `PreToolUse` payload carries the calling
  subagent's `agent_type`/`agent_id` alongside the call's own
  `tool_input.subagent_type`, the same attribution `stop-gate.sh` already
  relies on for `SubagentStop`. Registered in `hooks.json` alongside
  `protected-paths.sh`. Only covers a direct `Agent`-tool spawn attempt, not
  `SendMessage` to an existing reviewer teammate in agent-teams mode — a
  different tool with a different payload shape, out of scope here.

### Changed
- `lead-programmer.md`: `tdd` and `diagnose` moved out of the `skills:`
  frontmatter (which preloads a skill's full body into every spawn
  regardless of whether the task needs it) and are now invoked on demand via
  the `Skill` tool instead — the body's "TDD-first" bullet is the trigger.
  `coding-discipline` stays preloaded (small, applies to every task). This
  was the largest identified per-spawn token cost on the system's
  highest-frequency persona; a one-line fix doesn't need the full TDD/diagnose
  choreography resident before it's asked for. The review-ownership bullet is
  now one sentence instead of six lines, since `reviewer-route-gate.sh` (see
  Added) backs it mechanically instead of by instruction alone. A
  maintainer-facing comment explaining the old `skills:`/`tools:` rationale
  was cut from the body (see this entry instead) now that the rationale it
  described no longer applies. Added a short "keep memory bounded" bullet
  (index file + topic files + periodic pruning) since `memory: project` notes
  otherwise accumulate with nothing pruning them.
- `setup-personas` step 3's placeholder-substitution instructions updated:
  `lead-programmer.md`'s `<MATTPOCOCK:tdd>`/`<MATTPOCOCK:diagnose>`
  placeholders now live in its body prose instead of its `skills:`
  frontmatter (per the change above); `planner.md`/`repo-historian.md` are
  unaffected. Step 10's hook-verification list gained a
  `reviewer-route-gate.sh` dry-run check matching the pattern used for the
  other hooks.
- The WIP sentinel (`.claude/wip-handoff.<agent-id>`) now requires non-empty
  content. A bare `touch` used to bypass the stop-gate silently and
  invisibly; `stop-gate.sh` now rejects empty sentinels (deletes but doesn't
  honor them, falling through to the normal check) and logs the stated
  reason plus a timestamp to `.claude/wip-audit.log` before honoring a valid
  one. Closes a silent escape hatch from the system's one blocking gate.
  `.claude/wip-audit.log` is gitignored by `setup-personas` like the other
  runtime-only files.

### Confirmed unchanged / deliberately deferred
- The payload-attribution probe from this section's earlier draft is
  resolved (see `reviewer-route-gate.sh` under Added) — `PreToolUse` does
  carry caller `agent_type`. That unblocks a spawn-matrix hook for review
  ownership (shipped) but a per-persona write-path allowlist is a separate,
  larger follow-up not attempted here.
- The 2-FAIL cap stays instruction-only in subagent-orchestrator mode for
  now; the proposed fix (reviewer writes a `.fail` marker mirroring the
  existing PASS-marker pattern) needs a stable per-unit key that
  subagent-orchestrator mode doesn't currently have.
- No `maxTurns` cap was added to `lead-programmer` yet, despite being the
  other uncapped, long-running persona alongside the orchestrator.

## [0.2.1] - 2026-07-04

### Fixed
- The orchestrator relayed the planner's "Open Questions" as plain
  conversational text with no structured mechanism, even though it runs as
  the main session (not a subagent) and can actually use `AskUserQuestion`.
  Confirmed via docs that subagents (including the planner itself) can never
  use `AskUserQuestion` regardless of tools list — this was the correct
  place to wire it in, and wasn't. Added `AskUserQuestion` to
  `orchestrator.md`'s tools and updated its relay instruction to use it for
  questions that reduce to discrete choices.

### Confirmed unchanged (a deliberate choice, not an oversight)
- `planner.md`'s grill-me trigger stays gated on "for any non-trivial task"
  rather than becoming unconditional — the orchestrator's routing table
  already filters out trivial work before it reaches the planner, so the
  gate is mostly redundant in practice but intentionally left as a second
  line of defense.

## [0.2.0] - 2026-07-04

Bug fixes plus a modularity/update-mechanism rebuild, prompted by a
follow-up review that read the shipped files fresh and asked two questions:
how to make the system more modular, and what's still missing.

### Fixed
- `task-gate.sh` never checked for `.claude/persona-config.json` and nothing
  ever created `.claude/reviewed/`, so the reviewer's PASS-marker `touch`
  would fail on the very first agent-teams completion. Now guarded on config
  presence, and `setup-personas` pre-creates the directory.
- `protected-paths.sh` case-matched project-root-relative glob patterns
  against typically-absolute file paths, so directory-anchored patterns
  (e.g. `supabase/migrations/*`) never matched anything. Paths are now
  normalized against `CLAUDE_PROJECT_DIR` before matching.
- `graph-update.sh` and `lint-on-edit.sh` interpolated the (untrusted) edited
  file path into a string passed to `eval`, allowing command injection via a
  crafted filename. Both now pass the file path as a positional parameter to
  `bash -c` instead.
- All five hook scripts assumed the working directory was the project root;
  they now anchor to `${CLAUDE_PROJECT_DIR:-.}` explicitly.
- `agent_id`/`task_id` values from hook JSON payloads are now sanitized
  before being used to build filesystem paths.
- `stop-gate.sh`'s `SubagentStop` scoping moved from a hardcoded
  `lead-programmer` matcher in `hooks.json` to a config-driven `gatedAgents`
  list in `persona-config.json` (confirmed empirically that the
  `SubagentStop` payload carries `agent_type`), so adding a future
  code-writing persona is a config edit, not a plugin file edit.
- `stop-gate.sh` now also checks whether `HEAD` moved since the session's
  baseline commit (recorded by the new `session-start.sh`), closing a gap
  where a lead-programmer that commits per-step (clean tree at handoff) would
  otherwise never actually trigger the check.
- `planner.md`, `lead-programmer.md`, and `reviewer.md` were missing `Skill`
  in their tools list, so they silently lost their preloaded skills
  (grill-me/to-issues, tdd/diagnose/coding-discipline, coding-discipline
  respectively) when run as agent-teams teammates. `repo-historian.md` had
  the same gap and is fixed too.

### Added
- Persona opt-out: `orchestrator`, `explorer`, `lead-programmer` are the
  minimum viable loop; `planner`, `repo-historian`, `reviewer`, `researcher`
  are now selected per-project by `setup-personas`' persona-selection wizard.
  Cross-references to optional personas are phrased conditionally throughout
  so skipping one degrades gracefully instead of hard-erroring. Skipping
  `reviewer` requires an explicit typed confirmation.
- Version-stamp comments on every ADAPT-copied file, plus a `--update` mode
  in `setup-personas` that re-syncs an already-adapted project against a
  newer plugin version — diffing before overwriting, never silently
  clobbering a local edit.
- A `SessionStart` hook (`session-start.sh`) that warns when a project's
  stamped plugin version is behind the installed plugin's current version.
- A 2-FAIL cap on the reviewer FAIL→fix→re-review loop — the orchestrator
  escalates to the user instead of re-delegating a third time.
- `maxTurns: 30` on `planner.md` and `reviewer.md` (the two Opus-tier
  personas), matching the cost-bounding pattern already used by
  `explorer.md`'s `maxTurns: 10`.
- `tests/validate.sh` + a GitHub Actions workflow validating the plugin's own
  files (bash syntax, JSON validity, agent frontmatter, cross-reference
  consistency).
- `CONTRIBUTING.md` and a bug-report issue template.
- README sections: removing/uninstalling, adding your own persona, and a
  cost-guidance paragraph.

## [0.1.0] - 2026-07-03

Initial release. Six-persona system (orchestrator + explorer/planner/
lead-programmer/repo-historian/reviewer as plugin agents, researcher as a
project-scoped template), coding-discipline skill, enforcement hooks, and the
setup-personas ADAPT skill. Built through two adversarial-critique passes and
one empirical smoke test confirming plugin agents are namespaced and the
mandatory agent-copy fix this required.
