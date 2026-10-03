# Skill-access audit remediation (F1-F5, G1-G8)

Status: FINALIZED 2026-09-30 (all four Open Questions answered by the user with
the recommended defaults). Path: task-master-bound (standard path, 9 units) -
do NOT use the <=5 fast path.

## Goal

Close every finding from the independent skill-access audit of the persona
system: make the shipped `explorer` plugin agent parse (F1), stop misdirecting
users when the installed plugin is older than the adapted project (F2, repo
half), make `agent-auditor` usable in adapted projects (F3), give the Codex and
Cursor ports the skill content their Claude counterparts preload (F4), fix a
stale skill name (F5), mechanize `skills/` <-> `.claude/skills/` mirror parity
(G1), and apply the skill-wiring recommendations G2-G8.

## Context

Audit verdict (given): every skill a persona declares resolves and loads.
Already done, NOT re-specced: `.claude/skills/install-antislop/SKILL.md`
resynced from `skills/install-antislop/SKILL.md` (uncommitted at spec time;
`diff -rq` confirms SAME on 2026-09-30). U1 lands that commit.

Evidence re-verified 2026-09-30:

- **F1**: `agents/explorer.md:11` is the bare line
  `      <REAL_LAUNCH_COMMAND_FROM_INSTALL_ANTISLOP_STEP_4>` under
  `- code-review-graph:` / `type: stdio`, which is a plain scalar with no `:`
  inside a mapping, so the YAML is invalid. `templates/researcher.md.tmpl:11` has the same
  shape with `..._STEP_5>`. `tests/validate.sh:163-167` skips explorer.md from
  the YAML-parse check on purpose. Live symptom: this session's agent registry
  lists `antislop:explorer` as "Tools: All tools", meaning the plugin agent's
  frontmatter was not parsed, so it gets no tool allowlist, no `maxTurns: 10` and no
  `model: haiku`. `applyMcpPlaceholder` (`bin/cli.js:379-392`) matches
  `^([ \t]*)<TOKEN>` by line regex. Callers: `bin/cli.js:1039-1050`
  (`renderCleanBody`, `--update`) and `bin/cli.js:1670-1677` (`--wire-*-mcp`,
  guarded by `body.includes(placeholder)`). `PLACEHOLDER_RE`
  (`bin/cli.js:63`) and the unresolved-placeholder scan (`bin/cli.js:1594`)
  match the token itself, not the line shape. `applyArxivFallback` strips the
  block with `\nmcpServers:\n(?:[ \t]+\S.*\n?)+`, and so does
  `deriveMcpLaunchFromDisk` (`bin/cli.js:430`). A `#`-prefixed indented line
  still matches `[ \t]+\S.*`. `adapters/codex/agents/explorer.toml:56` holds the
  token inside a TOML string, which is already valid and out of scope. Tests pin the
  shape at `tests/cli-backfill.test.js:332-373`.
- **F2**: `~/.claude/plugins/installed_plugins.json` records
  `antislop@antislop-marketplace` at 0.31.63 (user scope), while the repo and
  the adapted `pluginVersion` are at 0.31.104. Repo-side defect found:
  `hooks/scripts/session-start.sh:50-52` emits "antislop plugin is vX but this
  project was adapted at vY - run /antislop:update-antislop" on ANY inequality,
  whichever way it points. When installed < adapted (this repo's state), that remedy is
  wrong: `--update` refuses a downgrade (`bin/cli.js:1138-1148`, #102). The
  correct remedy is the human-only `claude plugin update
  antislop@antislop-marketplace --scope <scope>` (already named in
  `skills/install-antislop/SKILL.md:519`). No test covers this message (`git
  grep 'adapted at' tests` finds nothing).
- **F3**: `agents/agent-auditor.md` invokes `bash scripts/agent-audit.sh` 6
  times. `package.json` `files` ships no `scripts/`, and `bin/cli.js` never
  copies it, so the persona is dead in every adapted project.
  `scripts/agent-audit.sh:14-18` sets `PROJECT_DIR=$SCRIPT_DIR/..` and sources
  `$PROJECT_DIR/hooks/scripts/lib/agent-identity.sh`, which only works in this
  repo's layout. Precedent: reviewer-invoked helpers that are not registered as
  hooks (`version-stamp-check.sh`, `heavy-trigger.sh`, `reviewer-tier.sh`) live
  in `hooks/scripts/`. `buildHookScriptSpecs()` (`bin/cli.js:612-620`)
  enumerates that directory at runtime, so a file placed there is shipped
  (`files: ["hooks"]`), scaffolded to `.claude/hooks/scripts/`, and
  hash-tracked by `--update` with no new cli.js code. Path references:
  `agents/agent-auditor.md` (6), `.claude/agents/agent-auditor.md` (6,
  generated), `commands/audit-agents.md` (1), `tests/agent-auditor.test.sh`
  (49), `CONTEXT.md` (1), `docs/harness-glossary.md` (2),
  `docs/adr/0020-...md` (1), `scripts/spend-accounting.sh` (1). Agent-memory
  files also reference it; they are historical and not edited.
- **F4**: `adapters/{codex,cursor}/agents/{lead-programmer,reviewer}` carry
  only one-line paraphrases ("TDD-first", "surgical diffs"), not skill content.
  `docs/specs/codex-cursor-plugin.md` row 11 mapped skills to a port concept
  that was never filled. Codex prompts are TOML literal `'''` strings
  (`lead-programmer.toml:18,79`). None of `skills/{tdd,coding-discipline,
  roast-work}/SKILL.md`, `skills/tdd/{tests,mocking}.md` contain `'''`, so
  verbatim inlining is TOML-safe. `bin/cli.js` copies the ports verbatim, and
  parity is test-enforced only (precedent: `tests/adapter-protocol-parity.test.js`).
- **F5**: `skills/pathfinder/SKILL.md:5` says `to-issues`. `CONTEXT.md:54`
  (task-master's glossary entry, "owns `to-issues` slicing") is the same stale
  name.
- **G1**: only `install-antislop` and `coding-discipline` are scaffold-copied
  (`bin/cli.js:2470-2471`). `.claude/skills/` also holds 4 graph-generated
  dirs with no `skills/` source. `docs/harness-glossary.md:300-312` states
  parity is "enforced only by process". The model check is the hook mirror at
  `tests/validate.sh:330-338` (`diff -rq`).
- **G2**: CONFLICT with a documented decision. `skills/install-antislop/
  SKILL.md:167-171` says the graph-generated skills "are just not what the
  explorer calls ... don't wire them into `explorer.md`". Also,
  `tests/validate.sh:212-224` only resolves `antislop:`-prefixed tokens, so a
  bare `explore-codebase` preload would go unchecked, and in a project where
  code-review-graph never generated the dir, it would dangle. Resolved: declined (see "G2 disposition").
- **G3**: `agents/reviewer.md` preloads `roast-work`, `ubiquitous-language`
  and pins `effort: high`. `antislop:code-review` fans out 2 sub-agents
  (Standards + Spec axes).
- **G4**: `skills/ubiquitous-language/SKILL.md` Prose mode names
  `spec-master` as its only consumer. `tests/ubiquitous-language.test.js`
  requires the Prose section to contain "quoted span" and NOT "file:line".
- **G5**: task-master has `maxTurns: 40` and no cutoff handoff guidance.
  lead-programmer's "Handoff on cutoff" bullet (`agents/lead-programmer.md:
  51-55`) is the pattern to mirror.
- **G6**: scribe is haiku, slim tier, and preloads `domain-modeling` only.
  `codebase-design` is 115 lines.
- **G7**: `agents/spec-master.md:251` ends "No new mattpocock slot is added
  for this". That is slot-era wording that ADR-0005 superseded (vendored
  `antislop:<name>` references are not slots), so referencing
  `antislop:diagnosing-bugs` is legal but the sentence must be amended.
- **G8**: `CONTEXT.md` "version-stamp discipline" says mechanization covers
  only the version-bump half, and the CHANGELOG half is reviewer-inspection-only. Two units
  (reviewer-changes-examples-lean-1/-2, 2026-09-23) FAILed on P3.
  `agents/lead-programmer.md:71-80` already carries the procedure inline.

Prior-FAIL / NOTE screen: NOT performed. The `.claude/reviewed/` listing was
refused by `reviewed-path-gate.sh` for this persona's Bash (the command text
spelled the path), and the turn budget ran out before `bash
bin/marker-audit.sh . --notes --surface=<path>` could run. **Assumption A1:** no
prior `.fail` record exists for any unit id in this plan. The ids are new, but
earlier FAILs on the same SURFACES (reviewer.md, lead-programmer.md, P3) are
known from memory: lean-1 and lean-2 FAILed on the P3 bump. task-master must run the
marker-audit sweep per touched surface before dispatch and record any
`NOTE[spec]` disposition. The sweep is best-effort. An empty result is not proof.

## Clarifications
1. Functional scope & success criteria: Partial
2. Domain entities / data model: Clear
3. User interaction flow: Clear
4. Non-functional attributes (perf, security, scale): Partial
5. External dependencies & integrations: Partial
6. Edge cases / failure handling: Partial
7. Technical constraints & tradeoffs: Missing
8. Terminology consistency: Partial
9. Completion / acceptance signals: Clear

- 2026-09-30 Functional scope & success criteria: Q Is G2 in scope given
  install-antislop's explicit "don't wire them into explorer.md"? → A: decline;
  the install-antislop decision stands (per user, 2026-09-30). No unit.
- 2026-09-30 Non-functional attributes: Q Should G6's `codebase-design` be
  preloaded (115 lines on every haiku scribe spawn) or referenced on demand?
  → A: on demand (per user, 2026-09-30).
- 2026-09-30 External dependencies & integrations: Q How is the stale
  user-level plugin cache (F2) remedied? → A: repo-side direction-aware
  session-start message (U4) plus human-only `claude plugin update` (H1), per
  user, 2026-09-30.
- 2026-09-30 Edge cases / failure handling: Q Must F1's new placeholder form
  still be recognized in already-adapted projects whose on-disk explorer.md
  carries the OLD bare-token line? → A (self-resolved): yes. The regex accepts
  both forms, and U2 tests both.
- 2026-09-30 Technical constraints & tradeoffs: Q F3 ship route: relocate
  into `hooks/scripts/`, a new `.claude/scripts/` scaffold family, or
  `${CLAUDE_PLUGIN_ROOT}`? → A: relocate to `hooks/scripts/agent-audit.sh`
  (per user, 2026-09-30).
- 2026-09-30 Technical constraints & tradeoffs: Q F4, should tdd's companion
  files `tests.md`/`mocking.md` be inlined too? → A (self-resolved): no. Inline
  `SKILL.md` bodies verbatim only, plus one loud port-degradation note that the
  companions are not shipped. This matches the Claude preload, which loads
  SKILL.md only.
- 2026-09-30 Technical constraints & tradeoffs: Q G8, should
  lead-programmer's existing inline P3 procedure (lines 71-80) be replaced by
  the skill? → A (self-resolved): no. Keep it and add the skill reference
  (minimal diff, no loss of the `unknown`-verdict guidance).
- 2026-09-30 Terminology consistency: Q `to-issues` vs `to-tickets`? → A
  (self-resolved): `to-tickets` is canonical (ADR-0005, skills/to-tickets).
  Fix both stale sites (U6).

## Risks / dependencies

- **R1 P3 version collisions.** U2, U3, U7, U8, U9 each touch
  `agents/*.md` or `templates/`, so each needs its own patch bump
  (`.claude-plugin/plugin.json` + `package.json`, kept in sync by validate.sh)
  and CHANGELOG entry **in the same commit** (per-commit semantics, constitution
  v1.1.0). Dispatch these units SERIALLY. Each derives its next version at
  execution time from `.claude-plugin/plugin.json` and never hard-codes one
  from this plan.
- **R2 Generated mirrors.** Every `agents/*.md` edit requires `node bin/cli.js
  --update` to regenerate `.claude/agents/<x>.md` and refresh `fileHashes`.
  Every `hooks/scripts/**` edit requires the same for `.claude/hooks/scripts/`.
  Never hand-edit a generated mirror (constitution P2).
- **R3 Gates.** `.claude/persona-config.json` is harness-integrity-gate Set A:
  agents never write it directly, and only `node bin/cli.js --update` may change
  it. Observed: even a read-only Bash command whose TEXT names it is refused.
  Use the Read tool to inspect it. Bash text spelling `.claude/reviewed/` is
  refused by reviewed-path-gate for non-reviewers. No unit touches a Set B
  literal (`hooks/hooks.json`, `.claude/settings.json`,
  `harness-integrity-gate.sh`). `protectedPaths` is `[]`. **No unit requires a
  human step except F2's plugin update** (Human action H1).
- **R4 Four-copy hand-sync.** No unit edits a protocol section that has
  persona-local or adapter copies (`templates/persona-protocol.md` is
  untouched). F4 creates a NEW hand-maintained copy relationship (SKILL.md ->
  ports), and its parity is made mechanical in U5, not left to process.
- **R5 Prior P3 FAILs on reviewer.md / lead-programmer.md surfaces**
  (lean-1, lean-2). Treat U8 and U9 as at least the Implementer-tier ratchet's
  floor. They are not cheaper-tier candidates.
- **R6 F1 behavioural change.** Once `antislop:explorer` parses, the plugin
  explorer gets its declared tools, haiku and `maxTurns: 10` (intended). Its
  `mcpServers` entry will have `type: stdio` with no command. Plugin agents
  ignore `mcpServers` (explorer.md:15-21 comment), so this is assumed harmless.
  **Assumption A2**, verified only by the in-session probe after the plugin cache
  is updated (H1).
- **R7 Dependency order.** U1 -> (U2, U5, U6 may start) ; U2 -> U3 -> U7 ->
  U8 -> U9 (serial P3 chain, R1) ; U4 independent (no P3) ; U5, U6
  independent after U1. U9 after U8 because both edit `agents/reviewer.md`.

## Constitution check (.claude/constitution.md v1.1.0)
- P1 "Verify, don't assume": satisfied. Every unit carries a runnable
  criterion, and F1/G1 each carry a mutation proof.
- P2 "Prefer deterministic scripts over LLM re-derivation": satisfied. Mirrors
  and `fileHashes` change only via `node bin/cli.js --update`. F3 reuses the
  existing hook-script spec family instead of hand-copying.
- P3 "Version-stamp discipline": satisfied, with per-unit bump + CHANGELOG in the
  same commit for U2, U3, U7, U8, U9, checked by
  `hooks/scripts/version-stamp-check.sh`. U1, U4, U5, U6 touch no
  version-stamped path (P3 not triggered). They still add a CHANGELOG line per repo
  habit, which is not a P3 obligation.
- P5 "`tests/validate.sh` is the merge gate": satisfied. Every unit's
  criteria include `bash tests/validate.sh` exit 0, and U2 REMOVES the
  explorer.md exemption from the YAML check.
(P4 is SHOULD, not MUST: new persona prose naming optional personas must be
conditionally phrased. U7's milestone-auditor/ubiquitous-language line is
the one at risk, and validate.sh's optional-persona check covers it.)

## Steps

Every unit's criteria implicitly include: `bash tests/validate.sh` exits 0
(timeout 600000). Also, `git status --porcelain` is empty after the unit's final
commit (agent-memory paths excepted per ADR-0037). Suggested model tags are
advisory input to task-master, which owns the final tag.

### U1 (G1): `.claude/skills/` <-> `skills/` parity check  [Suggested model: sonnet]
Affected files: `tests/validate.sh` (new section beside the hook-mirror check
~line 330); `.claude/skills/install-antislop/SKILL.md` (commit the existing
resync as the unit's first commit, with no new edit); `CHANGELOG.md`;
`docs/harness-glossary.md:300-312` (the "enforced only by process" sentence becomes
"enforced by tests/validate.sh").
Edit: for every directory `d` in `.claude/skills/` for which `skills/$d`
exists, `diff -rq skills/$d .claude/skills/$d`. Dirs with no source (the
graph-generated four) are skipped and printed as `SKIP`. FAIL names the dir and the
remedy.
Acceptance:
- `bash tests/validate.sh | grep -E '^OK .*\.claude/skills/(install-antislop|coding-discipline)'` prints 2 lines.
- Mutation proof: `printf x >> .claude/skills/coding-discipline/SKILL.md; bash tests/validate.sh >/dev/null; rc=$?; git checkout -- .claude/skills/coding-discipline/SKILL.md; test $rc -ne 0`.
- `git log -1 --format=%H -- .claude/skills/install-antislop/SKILL.md` names a commit on this unit's range.
P3: not triggered.

### U2 (F1): YAML-valid MCP placeholder  [Suggested model: opus]
Affected files: `agents/explorer.md:11`, `templates/researcher.md.tmpl:11`,
`bin/cli.js` (`applyMcpPlaceholder` 379-392), `tests/validate.sh:157-176`
(drop the explorer skip and its NOTE comment; extend the YAML loop to
`templates/*.md.tmpl` that have frontmatter), `tests/cli-backfill.test.js`
(new cases), `CONTEXT.md` "Substitution" entry (the placeholder is now a comment
line), generated `.claude/agents/{explorer,researcher}.md` via `--update`,
`.claude-plugin/plugin.json`, `package.json`, `CHANGELOG.md`.
Edit: the placeholder line becomes a YAML comment, keeping the token byte-identical:
`      # <REAL_LAUNCH_COMMAND_FROM_INSTALL_ANTISLOP_STEP_4>` (and `_STEP_5`).
`applyMcpPlaceholder`'s regex becomes `^([ \t]*)(?:#[ \t]*)?<TOKEN>\r?\n?`,
which accepts both the new comment form and the legacy bare form found in
already-adapted projects. `PLACEHOLDER_RE`, the `body.includes` guards,
`applyArxivFallback` and `deriveMcpLaunchFromDisk` are unchanged. Assumption A3:
each still behaves identically because the token and the indented-line shape
are preserved, and the new tests below pin it.
Acceptance:
- `python3 -c "import re,yaml;[yaml.safe_load(re.match(r'^---\n(.*?)\n---\n',open(f).read(),re.S).group(1)) for f in ['agents/explorer.md','templates/researcher.md.tmpl']]"` exits 0.
- `grep -c 'explorer.md" ] && continue' tests/validate.sh` prints 0.
- `node tests/cli-backfill.test.js` exits 0 and contains NEW checks that (a) render
  the comment form and the legacy bare form of both tokens to identical output,
  (b) show the rendered explorer frontmatter parses as YAML with `mcpServers[0]
  ['code-review-graph'].command` equal to the launch command, (c) show
  `PLACEHOLDER_RE` still matches the comment-form line, and (d) show
  `applyArxivFallback` removes the comment-form block.
- Mutation proof: revert only the `bin/cli.js` regex change, and `node
  tests/cli-backfill.test.js` exits non-zero.
- `bash hooks/scripts/version-stamp-check.sh <baseline>..HEAD` reports `ok`
  (never `violation`/`unknown`). `git diff <baseline>..HEAD -- CHANGELOG.md`
  adds a line containing the new version.
P3: YES (agents/, templates/).

### U3 (F3): make agent-auditor reachable downstream  [Suggested model: sonnet]  [route per user decision 2026-09-30]
Affected files (default route): `git mv scripts/agent-audit.sh
hooks/scripts/agent-audit.sh`. The script resolves the lib as
`$SCRIPT_DIR/lib/agent-identity.sh` and resolves PROJECT_DIR correctly in both
layouts (`<repo>/hooks/scripts/` and `<project>/.claude/hooks/scripts/`), for
example by stepping over a `.claude` parent. Also: `agents/agent-auditor.md` (6
refs -> `bash .claude/hooks/scripts/agent-audit.sh`, which exists in both this
repo's mirror and adapted projects), `commands/audit-agents.md:14`,
`tests/agent-auditor.test.sh` (49 refs), `scripts/spend-accounting.sh` (1),
`CONTEXT.md` (1), `docs/harness-glossary.md` (2); generated
`.claude/agents/agent-auditor.md` + new `.claude/hooks/scripts/agent-audit.sh`
+ its `fileHashes` entry via `--update`; version files; `CHANGELOG.md`. Do NOT
touch `docs/adr/0020-*.md` (accepted ADR, historical) or agent-memory files.
Acceptance:
- `bash tests/agent-auditor.test.sh` exits 0.
- `git grep -n 'scripts/agent-audit.sh' -- agents commands tests scripts CONTEXT.md | grep -v 'hooks/scripts/agent-audit.sh'` prints nothing.
- `npm pack --dry-run --json | python3 -c "import json,sys;assert any(f['path']=='hooks/scripts/agent-audit.sh' for f in json.load(sys.stdin)[0]['files'])"` exits 0.
- Downstream layout proof: `d=$(mktemp -d) && mkdir -p $d/.claude/hooks/scripts && cp -r .claude/hooks/scripts/. $d/.claude/hooks/scripts/ && (cd $d && AGENT_AUDIT_ROOT=$d/none bash .claude/hooks/scripts/agent-audit.sh --format-probe | grep -q FORMAT-NO-STORE)` exits 0. That shows the lib sourced and the script ran outside the repo layout.
- `diff -q hooks/scripts/agent-audit.sh .claude/hooks/scripts/agent-audit.sh` exits 0.
- version-stamp-check `ok` + CHANGELOG line (as U2).
P3: YES (agents/agent-auditor.md).

### U4 (F2, repo half): direction-aware plugin-version message  [Suggested model: sonnet]  [scope per user decision 2026-09-30]
Affected files: `hooks/scripts/session-start.sh:44-52`; new
`tests/session-start-version-direction.test.sh` wired into `tests/validate.sh`;
generated `.claude/hooks/scripts/session-start.sh` + `fileHashes` via
`--update`; `CHANGELOG.md`.
Edit: compare with `sort -V`. Installed > adapted keeps the existing
`/antislop:update-antislop` message. Installed < adapted emits a distinct
message saying the installed plugin is OLDER, that `--update` will refuse the
downgrade, and that the remedy is the human-run `claude plugin update
antislop@antislop-marketplace --scope <scope>`. Equal emits nothing.
Acceptance:
- New test drives the hook with a fixture `CLAUDE_PLUGIN_ROOT` (plugin.json
  version V1) and a fixture config (`pluginVersion` V2) for three cases:
  V1>V2 output contains `update-antislop`, V1<V2 output contains `claude plugin
  update` and NOT `update-antislop`, V1=V2 output contains neither. Exits 0.
- Mutation proof: restore the old unconditional message, and the test exits non-zero.
- `diff -q hooks/scripts/session-start.sh .claude/hooks/scripts/session-start.sh` exits 0.
P3: not triggered.
Human action H1 (not a unit, not dispatchable): the user runs `claude plugin
update antislop@antislop-marketplace --scope user`, then confirms
`installed_plugins.json` records >= the repo version, then re-probes that
`antislop:explorer` lists its declared tools (closes A2).

### U5 (F4): inline skill content into Codex/Cursor ports + parity test  [Suggested model: sonnet]
Affected files: `adapters/codex/agents/lead-programmer.toml`,
`adapters/cursor/agents/lead-programmer.md` (inline `coding-discipline` and
`tdd` SKILL.md bodies), `adapters/codex/agents/reviewer.toml`,
`adapters/cursor/agents/reviewer.md` (inline `roast-work` body). Each block is
delimited by `<!-- BEGIN inlined-skill: <name> -->` / `<!-- END inlined-skill:
<name> -->` in both ports; these are plain text lines inside the TOML `'''`
string. After the tdd block, add a one-line loud degradation note that
`tests.md`/`mocking.md` are not shipped with the port. New
`tests/adapter-skill-parity.test.js` wired into `tests/validate.sh`;
`docs/specs/codex-cursor-plugin.md` row 11 (note it is filled by inlining);
`CHANGELOG.md`.
Body = SKILL.md content after the closing frontmatter `---`, including the
vendored provenance/MIT header comment (the attribution travels with the text).
Acceptance:
- `node tests/adapter-skill-parity.test.js` exits 0. It asserts, for each
  (port, skill) pair in a frozen 6-row table, that the text between the
  sentinels is byte-equal to the SKILL.md body, and it fails closed if a
  sentinel is missing.
- Mutation proof: `UL=1`-style or temp-copy mutation (append a byte to a copied
  SKILL.md body) makes the test exit non-zero without touching tracked files.
- `bash tests/validate.sh` Codex TOML-validity and Cursor frontmatter sections still print OK.
- `node tests/adapter-protocol-parity.test.js` exits 0.
P3: not triggered (adapters/ and skills/ are not version-stamped paths).
Assumption A4: the ports are not version-stamped files and `--update` does not
manage them. They are copied verbatim at scaffold time, so consumers pick this up on
re-scaffold only.

### U6 (F5): `to-issues` -> `to-tickets`  [Suggested model: haiku (scribe-shaped)]
Affected files: `skills/pathfinder/SKILL.md:5`, `CONTEXT.md:54`, `CHANGELOG.md`.
Acceptance:
- `git grep -n 'to-issues' -- skills agents templates adapters commands CONTEXT.md` prints nothing.
- `node tests/context-glossary-links.test.js` exits 0.
P3: not triggered.

### U7 (G4+G5+G6+G7): on-demand/preload skill wiring, four personas  [Suggested model: sonnet]
One commit, one bump. Affected files:
- G4 `agents/milestone-auditor.md`: add `antislop:ubiquitous-language` to
  `skills:`, plus one body line saying it is used in prose mode on the plan under
  audit, advisory only, never a verdict. `skills/ubiquitous-language/SKILL.md`
  Prose mode `**Consumer:**` line: add "`milestone-auditor` (if present),
  auditing a plan's prose". The Prose section must keep "quoted span" and must
  not gain "file:line".
- G5 `agents/task-master.md`: add a "Handoff on cutoff" bullet mirroring
  `agents/lead-programmer.md:51-55`, invoking `antislop:handoff` on demand (not
  preloaded). It complements the WIP sentinel and changes no gate.
- G6 `agents/scribe.md` (on demand, per user decision): add a body line saying
  to invoke `antislop:codebase-design` when documenting a module-design
  decision or ADR. Do NOT add it to `skills:`; assert
  `! grep -q '^skills:.*codebase-design' agents/scribe.md`.
- G7 `agents/spec-master.md` debug-spec part 1: add "invoke
  `antislop:diagnosing-bugs` on demand when reproducing/narrowing a failure
  whose category may be a code defect". Replace the sentence "No new mattpocock
  slot is added for this." with "It is referenced as a vendored `antislop:`
  skill per ADR-0005, not preloaded."
- Generated `.claude/agents/{milestone-auditor,task-master,scribe,spec-master}.md`
  via `--update`; version files; `CHANGELOG.md`.
Acceptance:
- `grep -q '^skills:.*antislop:ubiquitous-language' agents/milestone-auditor.md`
- `grep -q 'antislop:handoff' agents/task-master.md`
- `grep -q 'antislop:codebase-design' agents/scribe.md`
- `grep -q 'antislop:diagnosing-bugs' agents/spec-master.md && ! grep -q 'No new mattpocock slot' agents/spec-master.md`
- `grep -q 'milestone-auditor' skills/ubiquitous-language/SKILL.md && node tests/ubiquitous-language.test.js`
- `for p in milestone-auditor task-master scribe spec-master; do grep -q antislop:ubiquitous-language\|antislop:handoff\|antislop:codebase-design\|antislop:diagnosing-bugs .claude/agents/$p.md || exit 1; done` (mirrors regenerated).
- validate.sh "skills: frontmatter tokens resolve" section prints `OK agents/milestone-auditor.md: antislop:ubiquitous-language`.
- version-stamp-check `ok` + CHANGELOG line.
P3: YES.

### U8 (G3): reviewer, advisory `antislop:code-review` on demand  [Suggested model: opus]
Affected files: `agents/reviewer.md` (body paragraph only; frontmatter
UNCHANGED), generated `.claude/agents/reviewer.md`, version files,
`CHANGELOG.md`.
Paragraph content: MAY invoke `antislop:code-review` only AFTER the verdict is
decided, and only when the unit names an originating spec/issue. The output is
ONE clearly-demarcated advisory section appended after the verdict line,
following the same rules as the ubiquitous-language diff-mode section. It never flips
PASS/FAIL, never adds a FAIL ground, never substitutes for running the
acceptance-criteria command, and findings go to the `.pass` notes. Under
`reviewGating.mode: off` it is advisory as well.
Acceptance:
- `git diff <baseline>..HEAD -- agents/reviewer.md | grep -E '^[-+](model|effort|tools|skills|maxTurns):'` prints nothing (frontmatter untouched).
- `grep -c '^effort: high' agents/reviewer.md` prints 1.
- `awk '/antislop:code-review/,/^$/' agents/reviewer.md | grep -q 'never flips'` and `... | grep -qi 'after the verdict'`.
- `node tests/effort-tier-consistency.test.js` exits 0.
- version-stamp-check `ok` + CHANGELOG line.
P3: YES.

### U9 (G8): new `version-stamp-discipline` skill  [Suggested model: opus]
Affected files: new `skills/version-stamp-discipline/SKILL.md` (frontmatter
`name`, `description`; body covers: trigger = any commit touching
`agents/*.md` or `templates/*`; the per-commit rule (constitution P3 v1.1.0);
the check `bash hooks/scripts/version-stamp-check.sh <range>` with the meanings of
`ok`/`violation`/`unknown`; the CHANGELOG half as a runnable command, e.g.
`git show <sha> -- CHANGELOG.md | grep -q "^+.*$(jq -r .version
.claude-plugin/plugin.json)"`; and an applicability note (only repos shipping
version-stamped files)). `agents/lead-programmer.md` adds
`antislop:version-stamp-discipline` to `skills:` and keeps lines 71-80 as-is.
`agents/reviewer.md` gets an on-demand body reference (not a preload, to keep the
reviewer's context budget), with frontmatter untouched. `CONTEXT.md`
"version-stamp discipline" entry gets one clause naming the skill. Generated
mirrors via `--update`; version files; `CHANGELOG.md`.
Acceptance:
- `bash tests/validate.sh | grep -q 'OK   skills/version-stamp-discipline/SKILL.md'` (frontmatter check) and `... | grep -q 'antislop:version-stamp-discipline -> skills/version-stamp-discipline/SKILL.md'`.
- `grep -q 'version-stamp-check.sh' skills/version-stamp-discipline/SKILL.md && grep -q 'CHANGELOG' skills/version-stamp-discipline/SKILL.md && grep -q 'unknown' skills/version-stamp-discipline/SKILL.md`.
- The skill's CHANGELOG command, run against this unit's own final commit, exits 0. Mutated against a commit with no CHANGELOG change (e.g. U6's parent), it exits non-zero.
- `grep -c '^effort: high' agents/reviewer.md` prints 1; `grep -q 'antislop:version-stamp-discipline' agents/reviewer.md`.
- version-stamp-check `ok` + CHANGELOG line.
P3: YES. Depends on U8 (same file).

### G2 disposition: DECLINED (no unit)
Per user decision 2026-09-30: `skills/install-antislop/SKILL.md:167-171`'s
decision stands - the explorer calls the code-review-graph MCP tools directly;
the graph-generated `.claude/skills/{explore-codebase,debug-issue}` have no
`skills/` source (a preload would dangle in projects without code-review-graph
and escape validate.sh's `antislop:`-only resolve check) and add nothing to a
haiku / 10-turn persona. U9's CHANGELOG entry records "G2 declined" in one line.

## Open Questions
None. OQ1-OQ4 were answered 2026-09-30 with the recommended defaults (see
Clarifications): OQ1 relocate to hooks/scripts/; OQ2 U4 + human action H1;
OQ3 decline G2 (no unit); OQ4 codebase-design on demand.

## Self-check
- CHK1: Does every finding F1-F5, G1-G8 map to a unit or a recorded disposition? PASS (F1->U2, F2->U4+H1, F3->U3, F4->U5, F5->U6, G1->U1, G2->declined disposition, G3->U8, G4-G7->U7, G8->U9).
- CHK2: Do R1's serial chain and each unit's P3 line agree on which units bump? PASS (U2, U3, U7, U8, U9 in both).
- CHK3: Is F3's route decided? FAIL (missing), converted to Open Question 1; answered 2026-09-30, now PASS.
- CHK4: Is F2's repo-side scope decided? FAIL (missing), converted to Open Question 2; answered 2026-09-30, now PASS.
- CHK5: Is G2's conflict with install-antislop SKILL.md:167-171 resolved? FAIL (conflicting), converted to Open Question 3; answered 2026-09-30, now PASS.
- CHK6: Is G6 preload-vs-on-demand defined? FAIL (ambiguous), converted to Open Question 4; answered 2026-09-30, now PASS.
- CHK7: Does U2 define behaviour for legacy bare-token files in adapted projects? PASS (regex accepts both; test (a)).
- CHK8: Do U8 and U9 agree that reviewer frontmatter/effort stays untouched? PASS (both assert `^effort: high` count 1; U8 asserts no frontmatter diff).
- CHK9: Was the prior-FAIL / NOTE sweep performed? FAIL (missing), revised in place. Recorded as Assumption A1 with a task-master pre-dispatch obligation (the gate refused this persona's listing; not a user question).
- CHK10: Does every unit have a runnable criterion plus, where a test is added, a mutation proof? PASS (U1, U2, U4, U5 carry mutation proofs; U9 carries a negative case).

Ubiquitous-language prose check (advisory): lens 1, none. Lens 2: "to-issues"
is a stale synonym for `to-tickets` (Context, F5), handled by U6. Lens 3:
"inlined-skill sentinel" (U5) is a new load-bearing term, a candidate for
scribe to add to `docs/harness-glossary.md` (harness vocabulary, not CONTEXT.md).

## Scribe update hint
After U5: glossary entry "inlined-skill sentinel" (harness-glossary). After
U1: amend the "scaffold-only mirror" entry (harness-glossary:300-312) to note
the new mechanical parity check. After U3: CONTEXT.md agent-auditor entry path.
After U9: CONTEXT.md version-stamp discipline entry names the skill.

## Publish
>=6 units: published via `to-spec` as an umbrella `[spec]` issue labelled
`ready-for-agent`: issue #483 (https://github.com/Storreslara/AntiSlop/issues/483). This document
remains the canonical artifact; task-master slices it with `to-tickets` under
`plan/2026-09-30-skill-access-audit-remediation`.
