# Git-based install convergence + install-instruction cleanup

Date: 2026-07-17
Author: spec-master
Slug: git-based-install-convergence

## Goal

Converge AntiSlop's install story onto a single, clean, **public-git-based**
model, and replace the current verbose/stale install prose with three short,
parallel per-target quickstarts (Claude Code, Codex, Cursor).

## Context

Two user asks:
1. "Let's converge on install methods, let's have it be git based."
2. "Let's also clean up the instructions. They are way too verbose, I want
   clear Install Instructions for Claude, Codex, and Cursor."

**Key finding — the convergence is already mostly done at the config level;
the real remaining work is documentation.** Verified this session:

- `Storreslara/AntiSlop` is **PUBLIC** (`gh repo view` → `isPrivate:false`).
  The README's "private repo, requires collaborator access + git auth"
  framing (lines 42, 96-102, 113) is therefore **stale**.
- `.claude-plugin/marketplace.json` already uses a clean, standard
  `"source": "./"` (repo-local directory source) — no change needed there.
- The only non-standard `"source":"github"` + `repo` + local `path` **hybrid**
  registration lives in the developer's personal `~/.claude/settings.json`
  (`extraKnownMarketplaces.antislop-marketplace`). That is machine-local state,
  **not a repo file** — out of repo scope (see OQ5).
- Three real install surfaces exist today:
  - **Claude Code**: marketplace plugin (`/plugin marketplace add
    Storreslara/AntiSlop` + `/plugin install antislop@antislop-marketplace`),
    a `claude --plugin-dir <clone>` local-clone alternative, and the
    standalone scaffold (`bin/cli.js` / `/antislop:install-antislop`). The
    just-shipped issues #66-77 made the marketplace and standalone paths
    **coexist safely** rather than converge into one.
  - **Codex**: `node bin/cli.js --target=codex` → scaffolds `.codex/`
    (MVP four personas; `scaffoldCodex`, bin/cli.js:1178).
  - **Cursor**: `node bin/cli.js --target=cursor` → scaffolds `.cursor/`
    (`scaffoldCursor`, bin/cli.js:784).
- **Cursor and Codex appear ZERO times in README.md** (verified by grep),
  despite both being real, actively-maintained CLI targets. `adapters/codex/`
  and `adapters/cursor/` exist but have no install doc of their own.
- The README "## Install" + "## First-time setup" region is ~104 lines of
  verbose prose (dated grace-period notes, deep caveats, etc.).

Net: "git based" is realized by (a) the repo already being public, (b)
marketplace.json already clean; the outstanding change is to **stop
documenting the old private/hybrid world** and present clean, concise,
git-based per-target quickstarts. No install-mechanics rearchitecture is
required under the recommended defaults — unless the user picks the
"deprecate a Claude path" fork (OQ1).

## Clarifications

1. Functional scope & success criteria: Partial
2. Domain entities / data model: Clear
3. User interaction flow: Clear
4. Non-functional attributes (perf, security, scale): Clear
5. External dependencies & integrations: Clear
6. Edge cases / failure handling: Partial
7. Technical constraints & tradeoffs: Partial
8. Terminology consistency: Clear
9. Completion / acceptance signals: Partial

- 2026-07-17 Functional scope & success criteria: Q Does "converge on install
  methods, git based" mean deprecating a Claude install path, or standardizing
  the *source* as public-git across all methods while keeping the paths? → A:
  deferred to Open Question 1 (recommended default: keep both Claude paths,
  standardize source + docs on public git).
- 2026-07-17 Non-functional attributes: Q What makes the cleaned-up
  instructions "clean" in a checkable way? → A (self-resolved): a line-count
  ceiling on the combined Install + First-time-setup region (currently ~104
  lines) plus presence/absence grep assertions; conciseness becomes
  machine-checkable, see Step 1 AC4.
- 2026-07-17 External dependencies & integrations: Q Is the repo still private
  requiring collaborator access? → A (self-resolved): repo is PUBLIC (verified
  `gh repo view Storreslara/AntiSlop` → isPrivate:false); README's private/
  collaborator framing is stale. Intent-to-remain-public deferred to Open
  Question 2.
- 2026-07-17 Edge cases / failure handling: Q What is the documented Cursor/
  Codex install method, given no marketplace equivalent exists? → A: git clone
  the public repo, then `node bin/cli.js --target=cursor|codex` from the
  project root — deferred to Open Question 3 for confirmation.
- 2026-07-17 Technical constraints & tradeoffs: Q Deprecate the standalone CLI
  path for Claude, or keep both marketplace + standalone as documented
  alternatives? → A: deferred to Open Question 1 (recommended default: keep
  both — matches the #66-77 coexistence work, and the CLI is the *only*
  Cursor/Codex path so it can't be deprecated wholesale).
- 2026-07-17 Completion / acceptance signals: Q What are the machine-checkable
  done signals for a docs change? → A (self-resolved): grep-based presence/
  absence assertions on README plus `bash tests/validate.sh` exit 0, per step
  ACs below.

## Risks / dependencies

- **Scope creep into a full README rewrite.** The user scoped cleanup to
  *install instructions*; the default keeps other sections intact (OQ4).
- **The "deprecate a path" fork (OQ1) is a much larger change** than a docs
  cleanup — it would touch `orchestrator.md`/skill prose and re-trigger
  constitution P3 (version-stamp). The recommended default avoids this.
- **Dev-machine hybrid config (`~/.claude/settings.json`) is out of repo
  scope** — flag it to the maintainer as a manual cleanup, don't try to fix a
  personal-machine file from a repo change (OQ5).
- Depends on nothing in flight; this is documentation-only under the defaults.

## Constitution check (.claude/constitution.md v1.0.0)

- P1 "Verify, don't assume" (MUST): satisfied — repo visibility, marketplace
  source shape, and Cursor/Codex README absence were each verified directly
  (gh / grep / file reads), not assumed from README; all step ACs are runnable
  checks, not prose.
- P2 "Prefer deterministic scripts over LLM re-derivation" (MUST): satisfied —
  no script-driven file (`fileHashes`, `substitutions`, `--wire-*` targets) is
  hand-edited; `marketplace.json` source stays `"./"`. README is not
  script-driven.
- P3 "Version-stamp discipline" (MUST): satisfied under the recommended
  defaults — no version-stamped file (`agents/*.md`, templates) is touched, so
  no `plugin.json` bump is required for a README-only change. NOTE: if OQ1 is
  redirected toward changing install *mechanics* (CLI/agent/skill prose), P3
  re-triggers and a `plugin.json` bump + CHANGELOG entry become mandatory.
- P4 "Optional personas degrade gracefully" (SHOULD): satisfied — install docs
  don't present opt-in personas as required.
- P5 "tests/validate.sh is the merge gate" (MUST): satisfied — every step's
  acceptance criteria include `bash tests/validate.sh` exit 0.

## Steps

### Step 1 — Restructure README "## Install" into three per-target quickstarts; trim "## First-time setup"

Affected files: `README.md` (Install section ~L94-118; First-time setup
~L125-183).

Replace the single Claude-only Install section with a "## Install" section
containing three parallel `###` subsections, each end-to-end (obtain →
install → per-project setup):

- `### Claude Code`
  - Marketplace (recommended): `/plugin marketplace add Storreslara/AntiSlop`
    then `/plugin install antislop@antislop-marketplace` — note it is a
    **public** repo, no collaborator access or git auth needed.
  - Local-clone alternative (one line): `claude --plugin-dir /path/to/clone`
    — reframed as a plain alternative, NOT a "no collaborator access"
    workaround.
  - Per-project setup: `/antislop:install-antislop` (one line + pointer to
    `skills/install-antislop/SKILL.md` for the full flow).
- `### Codex`
  - `git clone https://github.com/Storreslara/AntiSlop.git`
  - `node AntiSlop/bin/cli.js --target=codex` from your project root →
    scaffolds `.codex/` (note: MVP four personas).
- `### Cursor`
  - `git clone https://github.com/Storreslara/AntiSlop.git`
  - `node AntiSlop/bin/cli.js --target=cursor` from your project root →
    scaffolds `.cursor/`.

Trim the verbose "## First-time setup" prose: keep the essentials (which
personas it asks about, the reviewer-skip confirmation, the two "does NOT do
silently" items) and the `/antislop:update-antislop` pointer; move deep
caveats and the dated grace-period note behind a one-line pointer to
`skills/install-antislop/SKILL.md` rather than inlining them.

Acceptance criteria (machine-checkable):
- AC1: all three headings exist —
  `grep -qE '^### Claude Code' README.md && grep -qE '^### Codex' README.md && grep -qE '^### Cursor' README.md`
  (exit 0).
- AC2: each target's canonical command is present —
  `grep -q 'plugin marketplace add Storreslara/AntiSlop' README.md && grep -q 'target=codex' README.md && grep -q 'target=cursor' README.md`
  (exit 0).
- AC3: `bash tests/validate.sh` exits 0.
- AC4: conciseness — the combined "## Install" + "## First-time setup" region
  is ≤ 85 lines (currently ~104). Check:
  `test "$(awk '/^## Install/{f=1} /^## Using AntiSlop/{f=0} f' README.md | wc -l)" -le 85`.
  (Ceiling raised from 70 to 85 on 2026-07-22 to accommodate the install-scope
  subsection folded in as Step 4 below; the three quickstarts alone should
  still land well under the original 70.)

### Step 2 — Purge stale "private / collaborator access" framing from README

Affected files: `README.md` (L42 "packaged as a private, reusable plugin";
L96-102 private-repo + collaborator prerequisites; L113 "No collaborator
access yet?").

Remove the private-repo prerequisite block and collaborator-access language;
reframe any surviving local-clone mention per Step 1. Ensure Step 1 and Step 2
agree that the `--plugin-dir` local-clone path is **kept** (as a plain
alternative), not deleted.

Acceptance criteria:
- AC1: zero collaborator references — `! grep -qiE 'collaborator' README.md`
  (exit 0).
- AC2: zero stale private-repo references —
  `test "$(grep -ic 'private' README.md)" -eq 0` (exit 0).
- AC3: `bash tests/validate.sh` exits 0.

### Step 3 — Confirm the git-based marketplace source; document the canonical add command; flag the dev-machine hybrid

Affected files: `README.md` (Claude quickstart, from Step 1); verify-only on
`.claude-plugin/marketplace.json` (no change expected — `"source": "./"` is
already correct).

Add a maintainer note (in the filed issue, not README) that the developer's
personal `~/.claude/settings.json` `extraKnownMarketplaces.antislop-marketplace`
uses a non-standard `github`+`path` hybrid and should be re-registered against
the clean public source manually — this is machine-local and out of repo scope
(see OQ5).

Acceptance criteria:
- AC1: `python3 -m json.tool .claude-plugin/marketplace.json >/dev/null`
  exits 0.
- AC2: README contains the exact string
  `/plugin marketplace add Storreslara/AntiSlop`.
- AC3: no non-standard hybrid source introduced into marketplace.json —
  `! grep -q '"path"' .claude-plugin/marketplace.json` (exit 0).

### Step 4 — Document install-scope precedence and stale-registration recovery

> Folded in on 2026-07-22 from the publish-readiness remediation plan
> (`docs/plans/2026-07-22-publish-readiness-audit-remediation.md`, finding
> **M3**) per the user's OQ4 decision to merge the scope-precedence
> documentation into THIS plan rather than land it as a standalone subsection
> in the remediation plan. This step is the single owner of that requirement;
> the remediation plan carries only a thin cross-reference, no duplicate
> acceptance criteria.

Affected files: `README.md` (a `### Install scope (local / project / user)`
subsection inside the "## Install" section restructured in Step 1 — depends on
Step 1 having established that section).

Add a subsection documenting: (a) the three Claude Code plugin install scopes
(`local`, `project`, `user`) and their precedence; (b) how to check which scope
a project is currently pinned to; and (c) how to recover from a stale scope
registration that has frozen a project at an old plugin version — via
`claude plugin update antislop@antislop-marketplace --scope <local|project|user>`.
This is the exact gap behind the real v0.7.1-vs-0.13.x drift incident (two
projects pinned at a stale `local`/`project` scope). Keep the recovery command
string identical to the one B1's `--update` downgrade guard points at, so the
docs and the CLI error agree verbatim.

Acceptance criteria (machine-checkable):
- AC1: the scope subsection exists —
  `grep -qiE '^### Install scope' README.md` exits 0.
- AC2: all three scope names are documented in-context —
  `grep -q 'local' README.md && grep -q 'project' README.md && grep -q 'user' README.md`
  exits 0.
- AC3: the recovery command is present and matches B1's guard pointer —
  `grep -q 'claude plugin update antislop@antislop-marketplace' README.md`
  exits 0.
- AC4: `bash tests/validate.sh` exits 0.

## Open Questions

All carry a recommended default; the spec is buildable as written on these
defaults (confirm-or-redirect, non-blocking).

1. **Claude convergence shape** (highest impact). Does "converge, git based"
   mean: (a) **[RECOMMENDED]** keep both Claude paths (marketplace + standalone
   CLI) and standardize the *source* + docs on clean public git; (b) deprecate
   the standalone `bin/cli.js` path for Claude in favor of marketplace-only; or
   (c) make the standalone CLI itself always git-clone-based? Default (a):
   matches the just-shipped #66-77 coexistence work, and the CLI is the only
   Cursor/Codex path so it can't be deprecated wholesale. (b)/(c) enlarge scope
   beyond docs and re-trigger constitution P3.
2. **Repo visibility intent.** Verified the repo is currently PUBLIC. Confirm
   it is meant to stay public so the private/collaborator framing can be
   removed (Step 2). **[RECOMMENDED: yes, public.]** If it will return to
   private, Step 2 reverses and the collaborator framing stays.
3. **Cursor/Codex documented method.** Confirm the one documented method for
   these tools is: git clone the public repo, then `node bin/cli.js
   --target=cursor|codex` from the project root. **[RECOMMENDED: yes]** — it is
   the only mechanism that exists.
4. **README cleanup blast radius.** (a) **[RECOMMENDED]** restructure only
   "## Install" + "## First-time setup" into the three quickstarts, leaving
   Personas / Requirements / Using / Removing / Credits intact; or (b) a full
   README rewrite. Default (a): the user scoped cleanup to *install
   instructions*.
5. **Scope boundary.** Are (i) fixing the dev-machine `~/.claude/settings.json`
   hybrid registration and (ii) adding per-adapter READMEs under
   `adapters/{codex,cursor}/` in scope this pass? **[RECOMMENDED: both out of
   scope]** — (i) is personal-machine state, not a repo file (handled as a
   maintainer note, Step 3); (ii) is covered by the main-README quickstart.

## Self-check

- CHK1: Is a concrete install method defined for each of the three named tools
  (Claude/Codex/Cursor)? — PASS (Step 1 defines all three).
- CHK2: Do Steps 1 and 2 agree on whether the `--plugin-dir` local-clone path
  is kept or removed? — PASS (both keep it as a plain alternative; stated
  explicitly in Step 2).
- CHK3: Is "way too verbose → clean" given a machine-checkable threshold? —
  PASS (Step 1 AC4, ≤ 70-line ceiling).
- CHK4: Is "converge, git based" defined concretely enough to verify? — FAIL
  (ambiguous) — converted to Open Question 1.
- CHK5: Does the spec say what happens to the dev-machine hybrid marketplace
  config? — PASS (Step 3 maintainer note + Open Question 5, explicitly scoped
  out).
- CHK6: Is the repo's intended public/private status resolved for the person
  approving? — FAIL (missing user intent) — converted to Open Question 2.
- CHK7: Does every step carry a runnable acceptance check (constitution P5)? —
  PASS (each step includes `bash tests/validate.sh` plus grep/json assertions).
- CHK8: Is constitution P3 (version-stamp) correctly scoped? — PASS (no
  version-stamped file touched under the default; re-trigger noted if OQ1
  redirects to mechanics).
- CHK9: Does the folded-in Step 4 (install-scope docs) carry its own
  machine-checkable acceptance criteria, and is its README-region growth
  reconciled with Step 1's conciseness ceiling? — PASS (Step 4 AC1–AC4 are
  runnable grep/exit-code checks; Step 1 AC4 ceiling raised 70→85 on 2026-07-22
  to absorb the subsection). NOTE: Step 4 depends on Step 1 having created the
  "## Install" section, so it is NOT parallel with Step 1 within this plan.

## Scribe update hint

This changes the *documented* install story only (repo already public,
marketplace.json already clean). If a wiki/CONTEXT page describes AntiSlop as
a "private plugin requiring collaborator access," it needs the same
public-git update. No architectural change to record.
