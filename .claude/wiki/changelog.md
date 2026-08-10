# Changelog (lead-programmer digest log)

Dated log of persona-driven work in this repo. Distinct from the project's
own `CHANGELOG.md` (which tracks plugin version releases for consumers).

## 2026-08-10
- **Closed issue #318** (scribe post-PASS duties) — microworld dashboard D5 step.
  Unit #318 (`feat(gh318)` commits `f0c7b46`/`f64c46c` original build,
  `15e4938`/`955a009` fix pass, PASS marker `.claude/reviewed/gh318.pass`)
  implemented Step D5 of the microworld dashboard plan, rewriting `bin/dashboard/index.html`
  from D2 placeholder into the real static single-file browser client (inline
  `<script type="module">`, no framework/build step/CDN). **Client features:** Left rail
  with one entry per microworld bundle, live status indicator (pass/fail/timeout/unknown)
  polled every 5s via `setInterval`. Nested tabs: group tier → function tier within
  selected group; bundles with no `functions[]` show status + "no function entries declared"
  note. Input form generated from `inputs[]` (string/number/json/file), `default` prefills
  (fixed to handle falsy defaults `0`/`false`/`""` via `!== undefined` check, not truthy
  check), `description` labels. Output pane: stdout/stderr/exit code/duration, explicit
  banners for `timedOut`/`truncated`. Exit code rendered neutrally (no verdict color).
  Empty state distinguishes genuine no-bundles from auth-error state. **HTML escaping
  hardening:** `escapeHtml()` now also escapes `"`/`'`, applied to `data-*` id attribute
  interpolations for bundle/function ids (manifest-author-controlled, not a security issue
  given manifest is in trust domain, but the convention is now captured). **Routing:**
  consumes only existing `GET /api/bundles` and `POST /api/invoke` endpoints; no new
  server routes. Version: 0.31.12 (no version bump on fix pass). **Review arc
  (FAIL→fix→PASS):** First review (opus, mandatory tier): FAILed on 8 real defects:
  (1) no group tab tier despite "nested tabs" being the headline requirement (computed
  `groups` map built and never used); (2) no polling (left-rail status static);
  (3) zero-input functions un-invokable (no form/button); (4) `default` prefill broken
  (JSON-quoting bug + truthy-check dropping falsy defaults); (5) exit code rendered
  in error-red styling regardless of value, violating "never as a verdict" spec;
  (6) fetch/auth failure rendered identically to empty bundle list; (7) incomplete
  empty-state copy; (8) false CHANGELOG claim about "nested tabs...". Non-blocking:
  `escapeHtml` didn't escape `"`/`'`, allowing attribute injection (manifest-author-controlled,
  not scored as FAIL). Fix pass (sonnet, per haiku-escalates-on-first-FAIL policy):
  commits `15e4938` (fix all 8 defects + escapeHtml quote-escaping hardening) +
  `955a009` (docs: CHANGELOG). Added regression tests: (e) group-tab rendering,
  (f) default-prefill. Mutation-proved both — reverting either fix turns the suite red.
  Second review (opus, mandatory — prior `.fail` record, 2-FAIL cap attempt 2 of 2):
  PASSed. All 8 defects independently re-verified fixed by executing the client's
  actual inline script against a stub DOM (not diff-reading). **Non-blocking advisory
  findings (institutional record, not defects):** (1) CHANGELOG's "Fixed" bullet overstates
  coverage — only tab construction + default-prefill gained test coverage, not the full
  rendering layer (output pane, empty state remain untested); awkward "shipped in this
  release had 8 defects" framing in same entry as Added bullet. (2) Polling-failure
  blind spot: `refreshBundles`'s error state only fires on initial load; if poll fails
  after rail is populated, stale `bundles` array keeps non-empty render branch active,
  so a dead server looks healthy forever — error state never shown mid-session. Suggested
  fix: render staleness banner when `fetchError` set regardless of `bundles.length`.
  (3) `groups` is bare object literal — manifest group literally named `constructor` or
  `__proto__` would throw or silently break group lookup (prototype pollution, not a
  security issue since manifests are trust domain, but a real crash bug). Suggested:
  `Object.create(null)` or `Map`. (4) `setInterval` polling has no in-flight guard — an
  overlapping poll can fire if a single fetch takes >5s. (5) Three raw (unescaped)
  manifest-controlled interpolations remain: `selectedBundle.timeoutSeconds`,
  `result.exitCode`, `result.durationMs` into innerHTML — not scored (manifest author
  already has code exec via `entry`; same threat model as flagged in D2's gh315 and
  D5's first review), but `timeoutSeconds` in particular is manifest-controlled and
  unescaped, worth folding into future hardening unit (D4's gh317 path-traversal note
  already flagged this follow-up candidate). (6) Ubiquitous-language drift: empty-state's
  use of "microworld bundle" now matches CONTEXT.md glossary (one of the original FAIL's
  fixes); remaining minor drift — left rail's entries labeled "microworld bundles" in
  code/comments where CONTEXT.md's glossary calls the rail entry "microworld" (the bundle
  is the directory behind it). Not required to fix; flagged as glossary-clarification
  candidate if scribe judges it load-bearing (optional). Issue #318 closed with PASS
  marker and commit reference.

- **Closed issue #317** (scribe post-PASS duties) — microworld dashboard D4 step.
  Unit #317 (`feat(gh317)` commit `0238ae6226173bd6d0052fbcd0ef9fb28cf93273`,
  PASS marker `.claude/reviewed/gh317.pass`) implemented Step D4 of the
  microworld dashboard plan, adding the `POST /api/invoke` security-sensitive
  endpoint spawning one **function entry** invocation with human-supplied inputs.
  **New API and execution contract:** `POST /api/invoke` with request
  `{ id, functionId, inputs: {<name>: <value>} }`, response
  `{ ok, exitCode, stdout, stderr, durationMs, timedOut, truncated }`.
  Same token-auth contract as other dashboard routes. Execution via
  `child_process.spawn()` (argv array, no shell), inputs serialized to JSON on
  stdin (never command-line), `MICROWORLD_BUNDLE_DIR` env var set to bundle
  path, process-group kill with SIGKILL escalation on `timeoutSeconds` (manifest
  value, default 60), stdout/stderr capped at 1 MiB each with `truncated` flag.
  **Path-resolution fix:** `discover.js` now emits a `dirSlug` field (canonical
  directory slug) used by `server.js` for path resolution, instead of the
  manifest's self-declared `unit` field — closes a discovery/invocation
  path-mismatch defect caught on first review. **Files changed:**
  `bin/dashboard/invoke.js` (new), `bin/dashboard/server.js` (new route),
  `bin/dashboard/discover.js` (added `dirSlug` field), `tests/dashboard-invoke.test.js`
  (new, 8 cases a-h), `tests/validate.sh` (registered). G1 quad version bumped
  0.31.10 → 0.31.11 (original build only; fix pass added no version bump).
  **Review arc (FAIL→fix→PASS):** First review (opus): FAILed on three
  real, reproducible defects: (1) timeout didn't bound the request or kill
  descendant processes (sleep 10 grandchild survived, reparented to init, response
  hung ~10s not returning promptly); (2) unhandled EPIPE on child stdin crashed
  the entire server — human-input-triggerable DoS; (3) bundle path resolution
  used manifest's `unit` field instead of canonical `dirSlug`, causing discovery
  and invocation to resolve different directories. Plus two vacuous test
  assertions: criterion (c)'s timeout case had no pid-liveness check; criterion
  (h)'s concurrency case both fixtures printed the same literal string (no
  cross-talk detection). Fix pass (sonnet): fixed all 5 defects — process-group
  kill with SIGKILL escalation, `child.stdin.on('error', ...)` EPIPE handler,
  added canonical `dirSlug` field used for path resolution, added real pid-liveness
  check to test (c), changed test (h) fixture to echo its own stdin for
  detectable cross-talk. Second review (opus, mandatory due to prior FAIL):
  PASSed. Reviewer independently re-reproduced all three original defects and
  confirmed each now behaves correctly (own `ps` check confirmed no leftover
  processes; tried ~8MB multibyte payload as additional EPIPE probe; confirmed
  `dirSlug` resolves correctly and is immune to hostile `manifest.unit`).
  Confirmed cases (c) and (h) non-vacuous via mutation testing (removing stdin
  error handler re-crashes server; removing pid-liveness check or changing
  test-fixture stdin causes assertion failures). **Four advisory findings from
  PASS review (institutional record, not defects requiring fix):** (1) **Shutdown
  gap (non-blocking):** because child is now `detached: true`, terminal Ctrl-C
  during invocation no longer kills it via SIGINT propagation — orphaned until
  timeout fires or server exits. Cheap mitigation: track live child pids and
  group-kill from `process.on('exit')`/SIGINT handler in `server.js`. (2) **SIGKILL
  escalation race (non-blocking):** 500ms SIGKILL escalation doesn't guard against
  direct child already exited and pid recycled — `process.kill(-pid)` lacks
  `child.kill()`'s reaped-pid guard. Mitigation: `if (child.exitCode === null)`
  guard before escalation. (3) **SECURITY — path traversal via `manifest.entry`
  (non-blocking but explicit follow-up candidate, not merely cosmetic):** manifest
  `{"entry": "../../../../tmp/x.sh"}` resolves and spawns OUTSIDE `microworlds/`
  and project root (measured: stdout `OUTSIDE_PROJECT_ROOT`). Pre-existing at
  pre-fix commit a794fe8 (not introduced by this unit). Judged a note not a FAIL:
  manifest.json is agent-authored local input inside repo's trust domain, so
  control of it implies ability to drop executable in bundle dir (no privilege
  escalation over feature's intended capability). Spec guardrail 6 is worded for
  reads and names `location.file` (D7 surface, not D4's). Flag prominently as
  follow-up: `fs.realpathSync` the resolved entry and reject anything not under
  bundle's directory. (4) **Ubiquitous-language note:** `discover.js` pre-existing
  loop variable `unitSlug` actually holds directory slug (canonical per CONTEXT.md).
  Now sits beside correctly-named new `dirSlug` field — mild misnomer. Optionally
  rename in future pass; not required now. **Acceptance:** all test criteria pass
  (dashboard-invoke.test.js, validate.sh, no shell, no execSync/exec, cli-backfill,
  git status byte-identical). Issue #317 closed with PASS marker and commit
  reference.
- **Closed issue #132** (scribe post-PASS duties) — microworld-rerun hook Step 3b.
  Unit #132 (`feat(gh132)` commit `ba8ebc84e906b23b41cf96c6d1043e1996a9665b`,
  PASS marker `.claude/reviewed/gh132.pass`) implemented Step 3b of the
  microworlds ubiquitous-language plan
  (`docs/plans/2026-07-28-microworlds-ubiquitous-language-human-review.md`),
  adding the reactive `PostToolUse(Edit|Write)` hook `hooks/scripts/microworld-rerun.sh`
  + hand-adapted mirrors in `adapters/cursor/` and `adapters/codex/` +
  registration in all three `hooks.json` files + fixture-driven test
  `tests/microworld-rerun.test.sh`. **New conventions introduced:**
  (1) **Reporter vs Gate distinction:** `microworld-rerun.sh` is a reporter
  hook (observes/logs without blocking), not a gate — exit 2 for genuine bundle
  failure (surfaces stderr, no block); exit 0 for no match or infrastructure
  breaks (fail-open). Formal antonym of **Gate**; added to CONTEXT.md glossary.
  (2) **Microworld audit log** (`.claude/microworld-audit.log` + adapters):
  append-only fourth sibling of review/wip audit logs, line format
  `<ts> unit=<slug> result=pass|fail|timeout file=<path>` for runs,
  `<ts> unit=<slug> result=error ... reason=<...> file=<path>` for infrastructure
  failures (malformed manifest, missing run.sh, absent jq, etc.). Added to
  CONTEXT.md glossary. (3) **Relocatable run.sh proof:** microworld bundle's
  `run.sh` must behave identically invoked from inside `microworlds/` or copied
  elsewhere (future D8 escalation). File paths injected safely (single positional
  param, never eval-interpolated). Proven executably by test cases (f)/(f2),
  not assumed — dependency for D8 step. Added to CONTEXT.md glossary.
  **Files changed:** `hooks/scripts/microworld-rerun.sh` (new), adapter mirrors
  `adapters/cursor/hooks/scripts/microworld-rerun.sh` and
  `adapters/codex/hooks/scripts/microworld-rerun.sh` (new), registration in
  3 `hooks.json` files, `tests/microworld-rerun.test.sh` (new),
  `tests/validate.sh` (edited — added test call), G1 quad version bumped
  0.31.8 → 0.31.9, 13 `.claude/` mirrors restamped. **Review outcome:**
  Single-pass PASS on opus review (commit `ba8ebc84`). Reviewer actively
  probed injection guard with `;`, `$(...)`, backticks in filenames — no
  injection. **Accepted non-blocking gaps:** (1) CHANGELOG:6 documents result
  as `pass|fail|timeout` (accurate but incomplete re: `result=error` variant);
  (2) Adapter mirrors exit 0 on absent jq without logging (canonical logs it —
  asymmetry in audit trail only); (3) Bash syntax errors in run.sh take fail
  branch not fail-open (defensible); (4) Newline in filename can forge audit
  line (non-material, nothing gates on log). Terminology note: "microworld rerun
  hook" / "microworld breakage" in test/CHANGELOG vs glossary's "microworld
  bundle" — minor drift, worth future cross-reference. Issue #132 closed with
  PASS marker and commit reference. Updated CONTEXT.md with three new glossary
  entries and .claude/wiki/changelog.md with this digest.

- **Closed issue #316** (scribe post-PASS duties) — microworld dashboard D3 step.
  Unit #316 (`feat(gh316)` commit `4febc8ab`, PASS marker `.claude/reviewed/gh316.pass`)
  implemented Step D3 of the microworld dashboard plan, adding live status tailing of the
  audit log with cross-language contract test and mutation proof. **New API and files:**
  `bin/dashboard/audit-log.js` (new, Node.js parser for `.claude/microworld-audit.log`,
  returns `Promise<Map>` keyed by unit slug; handles both `result=pass|fail|timeout` and
  `result=error ... file=<path> reason=<...>` variants). Modify `bin/dashboard/discover.js`
  to load audit status and attach `status: {...} | null` to each bundle, plus add
  `fs.watch` on `microworlds/` directory. Modify `bin/dashboard/server.js` to add
  `GET /api/status` endpoint (same token-auth contract as `/api/bundles`). New test
  suite `tests/microworld-audit-contract.test.js` (cross-language contract test exercising
  the REAL hook, REAL audit log, and REAL parser against a fixture bundle failure, with
  mutation proof: changing the hook's separator format breaks the test). **Status-tailing
  mechanism:** cases (g)-(j) in dashboard-server.test.js verify that audit log tailing
  works correctly — most-recent line per unit, missing log → null status, appended lines
  reflected on next request, new bundle directories discovered without restart. The
  `fs.watch` on `microworlds/` is inert (callback empty); structural liveness comes
  from `discover()` re-reading the filesystem on every HTTP request, not from watcher
  events. **Review outcome:** single-pass PASS on opus (commit `4febc8ab`). Reviewer
  advisory findings (institutional record): (1) CHANGELOG.md:7 overclaims that case (j)
  and fs.watch "prove" liveness — liveness actually comes from discover() re-reading per
  request. (2) CHANGELOG.md:7 incorrectly cites fs.watch location as `discover.js` when
  it is actually in `server.js:22`. (3) No `.on('error')` handler on FSWatcher (inotify
  exhaustion under `recursive:true` could crash); watcher is never closed/unref'd (leaks
  handle per `startServer()`, though production `process.exit(0)` masks this). (4) Space
  in audit-log path silently dropped by regex `file=(\S+)`. (5) `parseAuditLog` returns
  plain object not Map. (6) `GET /api/status` returns full bundle list rather than
  status summary. **Ubiquitous-language findings:** (1) Fixed CONTEXT.md:96 to document
  error-variant format with `reason` LAST, matching actual hook emission (pre-existing
  drift from unit #132). (2) Added glossary entry **consumed interface** for the new
  domain term (hooks/scripts/microworld-rerun.sh:10), defining bidirectional coupling
  between emitter and parser with contract test as the proof mechanism. Issue #316 closed
  with PASS marker and commit reference.

- **Closed issue #315** (scribe post-PASS duties) — microworld dashboard D2 step.
  Unit #315 (`feat(gh315)` commit `49296a7`, PASS marker `.claude/reviewed/gh315.pass`)
  implemented Step D2 of the microworld dashboard plan (`docs/plans/2026-08-10-microworld-dashboard.md`),
  adding HTTP API server, discovery of microworld bundles, loopback-only bind, and
  per-launch crypto-token auth. New files: `bin/dashboard/server.js` (HTTP server,
  `node:http` only, auth via `?t=` query or `X-Antislop-Token` header),
  `bin/dashboard/discover.js` (enumerates `microworlds/*/manifest.json`, fail-soft on
  malformed/missing entries), `bin/dashboard/index.html` (placeholder client).
  New CLI surface: `node bin/cli.js --dashboard` / `--dashboard-port=<n>` dispatches early
  in `main()` alongside `--update`, prints exactly one line (`http://127.0.0.1:<port>/?t=<token>`),
  runs in foreground until SIGINT. New HTTP API: `GET /` (placeholder HTML), `GET /api/bundles`
  → `[{ id, unit, source, description, disabled, disabledReason, functions: [...], status }]`.
  Every route requires launch token; missing/wrong → 401 empty body. New id convention:
  bundle ids namespaced `working:<unit-slug>` (directory slug, not manifest's declared `unit`
  field — stored separately to avoid collision with forward-looking `packet:<task-id>` namespace).
  Added 2 glossary entries to `CONTEXT.md`: **bundle source** (`source: "working"` origin value),
  **bundle id namespace** (`working:` / `packet:` distinction). Went through one review cycle:
  first attempt FAILed on 5 defects (stale `.claude/` mirror restamp regression, unauthenticated
  crash-the-process bug on malformed request-target, client auth-token missing making empty-state
  unreachable, half-asserted bidirectional test criterion, id-construction inconsistency) — all fixed
  and re-verified by mutation testing in second pass. Reviewer non-blocking notes flagged: unescaped
  innerHTML interpolation of bundle fields in `bin/dashboard/index.html:45-47` (safe at D2 with
  `source: "working"` trust boundary, escape before D5 ships real client and D8 adds foreign sources).
  Acceptance: all test criteria pass (dashboard-server.test.js, cli-backfill.test.js, validate.sh,
  G4-no-deps check, dashboard hook absence, token regex, npm pack dry-run, SIGINT exit). Full
  history: `.claude/reviewed/gh315.fail` and `.claude/reviewed/gh315.pass`. Issue #315 closed
  with PASS marker and commit reference.

- **Closed issue #314** (scribe post-PASS duties) — microworld bundle terminology
  rename and protocol section completion. Unit #314 (`feat(gh314)` commit `6d53eb1`,
  PASS marker `.claude/reviewed/gh314.pass` at commit `7f3e5f5`) added the canonical
  protocol section "Microworld bundles (format and the check contract)" to
  `templates/persona-protocol.md`, defining the bundle format (`manifest.json` with
  `functions[]`, `location`, `watch`, `timeoutSeconds`, `inputs/`, `expected/`,
  `README.md`) and entry execution contract, plus hand-ported adapter sections and
  updates to `agents/lead-programmer.md`/`agents/reviewer.md`. Terminology renamed:
  "microworld" now means the dashboard entry a human explores (D2+ work); the
  gitignored directory + its `run.sh` is now "microworld bundle." Added 4 glossary
  entries to `CONTEXT.md`: **microworld bundle** (gitignored directory), **microworld**
  (forward-looking dashboard entry), **function entry** (named executable in
  bundle's `functions[]`), **the dashboard** (forward-looking UI). Reviewer advisory
  items noted: (1) `agents/reviewer.md:62` garbled duplicated clause (prose only, not
  blocking); (2) New section `drop`-classified for spec-master/task-master/milestone-auditor
  (design question for future unit). `bin/cli.js` `PROTOCOL_SECTIONS_BY_PERSONA` matrix
  updated; G1 version triple bumped to 0.31.6. Acceptance: all 24 grep/count criteria
  from issue #314 pass; adapter-protocol-parity test, validate.sh, cli-backfill test,
  ubiquitous-language test all pass; 3 mutation proofs verified. Issue #314 closed
  with PASS marker and commit reference. Affected files: `CONTEXT.md`,
  `templates/persona-protocol.md`, adapters (2 files), `agents/lead-programmer.md`,
  `agents/reviewer.md`, `bin/cli.js`, `tests/adapter-protocol-parity.test.js`,
  `tests/cli-backfill.test.js`, `tests/ubiquitous-language.test.js`.

## 2026-08-08
- **Closed issue #227** (scribe dispatch) — replay-stamp staleness check fix.
  Unit #227 PASSed review and was closed with commit bf6f41c. Institutional
  note recorded: this is the **second fix** to this exact staleness-window
  logic (first: issue #220). Both fixes discovered via the "roast-work advisory
  pass → authoritative reviewer materiality ruling → tracked follow-up issue"
  pipeline, neither caught at original review time. Pattern's discovery
  mechanism is now confirmed by two independent instances. Updated
  `.claude/wiki/modules/hooks.md` to document this finding.

## 2026-07-14
- Ran `install-antislop` (fresh ADAPT) on this repo — previously had a
  broken partial/manual setup (no `persona-config.json`; `explorer.md`'s
  frontmatter contained an unresolved placeholder in an invalid YAML
  position, silently breaking its agent registration entirely). Full
  persona selection: all optional personas included (spec-master,
  task-master, scribe, researcher, milestone-auditor, reviewer — explicit
  confirmation given for reviewer, the system's core safety property).
- Wired Code Review Graph MCP to `explorer` only and arXiv MCP
  (`arxiv-mcp-server` via `uvx`) to `researcher` only — both verified live
  in-session (self-reported `PROVENANCE: graph-derived` /
  `PROVENANCE: mcp-derived`, not a grep/WebFetch fallback).
- Set `.claude/settings.json`'s `"agent": "orchestrator"` — this repo's
  main session was running as plain default Claude Code before this,
  despite the plugin being enabled; personas were invocable as subagents
  but nothing routed the main session through the orchestrator.
- Ratified `.claude/constitution.md` v1.0.0 (5 principles, seeded from
  `CONTRIBUTING.md`/`README.md`/`install-antislop`'s own "verify, don't
  assume" theme).
- Seeded this wiki, `CONTEXT.md`, and `docs/adr/0001-mcp-scoped-to-single-persona.md`.

## 2026-07-15
- **Completed Track 1 — Persona rename:** `repo-historian` → `scribe` across all references (plugin source + adapted copies, templates, adapters, shared prose, tests, CLI). Added `'repo-historian': 'scribe'` to `bin/cli.js` `LEGACY_PERSONA_MAP` so existing adapted projects migrate on `--update`.
- **Completed Track 2 — Skills for planning personas:** wired `to-spec` (existing published mattpocock skill) into `spec-master` via `<MATTPOCOCK:to-spec>` slot (complements `grill-me` — sequential not overlapping); authored new first-party `pathfinder` skill (tailored derivative of mattpocock's `wayfinder`, not a passthrough) for `task-master` to build reliable dispatch instructions; resolved OQ6 (to-spec template LAYERS on top of v0.9.0 spec-kit, not replace).
- **Completed Track 3 — Persona split:** `hivemind` → `spec-master` (spec authoring, grilling, .fail check, debug spec on 2-FAIL-cap) + `task-master` (dispatch-instruction authoring, `to-issues` slicing outright, per-unit model routing, upstream signal on spec gaps); added `'hivemind': ['spec-master', 'task-master']` one-to-two mapping to `LEGACY_PERSONA_MAP`; updated orchestrator routing (two-stage pipeline, FAIL → lead-programmer, 2-FAIL-cap → spec-master debug spec → task-master re-derive).
- **Completed Track 4 — Reviewer critique skill:** authored new first-party `roast-work` skill for `reviewer` (detail-driven critique: contradictions, missing parts, logic gaps, security vulnerabilities, actionable feedback); Tension 1 resolved advisory-only (never gates, appends after verdict); Tension 2 resolved opus default + fable for heavy lifting (≥8 files, ≥400-line diff, structural, or security-sensitive) via non-authoritative advisory dispatch.
- **Final consolidation:** version bumped to 0.10.0 across plugin and package manifests; all version-stamped files re-stamped; CHANGELOG.md updated with full release notes; fileHashes regenerated via deterministic `node bin/cli.js --update`.

## 2026-07-30
- **Completed #139 Step 9 (Probe C) — Live end-to-end re-probe:** scripted
  `eval/harness/probe-namespaced-dispatch.sh` to provision a fixture with
  marketplace plugin enabled, exercised both bare and namespaced persona
  dispatch, captured raw hook payloads proving the wire identity includes the
  namespace prefix (verbatim), recorded sha256 provenance assertions for the
  executing plugin scripts, and verified all six acceptance criteria
  (P-C1–P-C6). No production code changed; captures findings in
  `docs/experiments/2026-07-probe-hook-payloads.md` Probe C section. Commit
  ac29a3c.
- **Scribe update (item 2/4 from plan hint):** recorded lesson from Probe A
  gap as `.claude/wiki/probe-methodology.md` — the generalized finding that
  hook-payload probes must enumerate a field's **value space**, not just its
  presence. This becomes a durable methodology guide for future empirical
  verifications, addressing why the defect was discovered post-ship.

## 2026-08-07 (continued: Pass 3 programme completion)
- **Completed unit #244 (Step 15, scribe dispatch) — Efficiency audit remediation Pass 3 institutional record:**  Recorded the Pass 3 findings (F9, F11, F10-rejection) in new [ADR 0013](../../docs/adr/0013-fable-removed-from-roast-work-advisory-pass.md). The ADR documents: (1) Supersession of ADR-0004 § Decision Tension 2 (fable roast-work advisory pass removed, replaced by inline roast-work at reviewer's measured tier); (2) Fable's niche narrowed to milestone-auditor on ≥8-unit condition only, never spec-master/reviewer/task-master; (3) Amends ADR-0009 with 2026-08-03 re-measurement (sonnet 8/60 = 13.3%, inside predicted band, thresholds unchanged per ruling); (4) Preserves ADR-0006 reviewer-gate invariant (implementer-tier ratchet expires on PASS, reviewer-gate ratchet permanent); (5) F10 (milestone audit) assessed and rejected with full provenance. Also records F9 and F11 conventions (resume-same-reviewer on INSUFFICIENT-CONTEXT; reuse-over-re-derivation for role-matched personas). Updated CONTEXT.md to: fix the dangling ADR-0007 reference (no such file exists or is planned; the audit-logging hardening it referred to is already shipped at `hooks/scripts/lib/agent-identity.sh:107-184`, and the ADR-0007 number is simply unused/retired per OQ-CF1), add new vocabulary entries for implementer-tier ratchet, reviewer-gate ratchet, F9 convention (unit #241), and F11 convention (unit #242). Updated .claude/wiki/changelog.md and README.md to point at ADR-0013 and record Pass 3 completion. Acceptance: all acceptance criteria passed (0013 file exists, all required elements present, 0012 untouched, 0004 Decision section byte-identical to baseline, "Roast-work routing" vocabulary retired, "inline-only" confirmed in CONTEXT.md, new vocabulary ratchet entries added, dangling link fixed, `bash tests/validate.sh` pass).

## 2026-08-07
- **Completed unit #253 (Step 6 of skills-library remediation spec) — scribe dispatch:** recorded institutional knowledge and closed issue #253. Unit implemented Step 6 of the skills-library-remediation spec (`docs/plans/2026-08-04-skills-library-remediation.md`, Revision 4), fixing inaccuracies in `skills/install-antislop/SKILL.md`. Changes: (1) rewrote §4 bullets falsely claiming the Code Review Graph installer generates `build-graph`/`review-delta`/`review-pr` directories — corrected to name the four real shipped directories (`debug-issue`, `explore-codebase`, `refactor-safely`, `review-changes`); (2) dropped the false "third-party skill installs" scope claim from frontmatter `description:`; (3) inserted a 7-line Markdown blockquote "Numbering note" (verbatim mandated text per Revision 4 spec) in §2 to explain why heading numbering skips §3 deliberately (stable-labels-with-gaps convention matching existing `## 0.5` / `## 6.5`). Sub-steps 6b renumbering and 6c were withdrawn by Revision 3 — no heading numbers or cross-references changed elsewhere (verified byte-identical for 48 cross-reference occurrences across 19 forms). Commits `1c0aaa3` (initial, reviewer FAILed on first attempt due to missing blockquote markers) and `318a618` (fix, restoring exact formatting per spec, reviewer PASSed on re-review). Reviewer advisory: `skills/install-antislop/SKILL.md:152` now describes the four shipped directories as "(all query interfaces, not workflow commands)" — an unmandated editorial characterization that arguably mischaracterizes them as workflow-shaped numbered procedures; worth a follow-up if the file is re-touched. Affected files: `skills/install-antislop/SKILL.md` only. PASS marker: `.claude/reviewed/253.pass`. Issue #253 closed.

## 2026-08-01
- **Completed plan 2026-08-01-lead-programmer-haiku-default, issue #215 Step 9 (scribe) — version 0.21.0** — recorded the implementer-tier default change and institutional-knowledge updates. Created ADR-0010, documenting that `lead-programmer`'s model now defaults to `haiku` (was `sonnet`), that `task-master` escalation is now purely reactive (no pre-emptive tagging), and the judgment has moved into an enforced dispatch contract. ADR-0010 explicitly states the accepted tradeoff: a mis-called cheap unit costs one haiku attempt plus sonnet re-run plus two reviews. Cites ADR-0009 to explain why the review gate is unaffected — it measures the actual diff at dispatch time, independent of implementer tier, so a haiku-written large or risky diff still draws opus review. Makes sharp the distinction between implementer tier (flat default, no pre-emptive escalation) and reviewer tier (post-implementation measurement), preventing a repeat of finding F2 where two model-selection axes were conflated. Fixed a staleness statement in CONTEXT.md (lines 123–125): changed "no unit in this repo is tagged haiku" from present to past tense, clarifying it's ADR-0009's historical rationale measured at issue #190, not a current property. Documented the new H4 dispatch-hygiene check (structure audit of heading labels, not content) and the `requireContract` config key in `.claude/wiki/modules/hooks.md`, alongside the existing H1–H3 entries. ADR-0010 is accepted; implementer tier and reviewer tier are now explicitly two different mechanisms. Affected files: `docs/adr/0010-implementer-haiku-default.md` (new), `CONTEXT.md`, `.claude/wiki/modules/hooks.md`, `.claude/wiki/changelog.md`.

## 2026-08-06 (ad-hoc: orchestrator nested-dispatch guard)
- **Completed ad-hoc unit — orchestrator nested-dispatch guard:** incident remediation and institutional knowledge capture. Incident: during this session, orchestrator dispatched `spec-master` for a 2-FAIL-cap debug spec on unit #240, and `spec-master` itself spawned `task-master` as a nested background `Agent` call with no assigned name. Orchestrator repeatedly resumed the intermediate `spec-master` to poll for completion — three turns of zero-value asks — before correctly requesting the grandchild's `name` and reaching it directly via `SendMessage`. User flagged this passive-waiting antipattern as needing a guard. **Resolution:** added new `### Nested dispatches (a persona spawning its own subagent)` subsection to `agents/orchestrator.md`'s "Managing a long-running background dispatch" section, codifying guidance: (1) Don't repeatedly resume an intermediate persona to ask if a grandchild is done — each resume costs a full turn; (2) Ask at most once for the grandchild's assigned `name` (never its `agentId`); (3) A persona naming its nested `Agent` dispatch makes that grandchild directly `SendMessage`-able from anywhere in the session; (4) When dispatching a persona for 2-FAIL-cap/debug-spec work that may spawn a nested call, require it to assign the nested call a name up front; (5) Fallback: if the grandchild turns out unnamed/unreachable after the single ask, don't ask again — wait for the intermediate persona's natural completion instead. **FAIL/fix history:** Commit `5df1b8a` (initial) FAILed on false citation of non-existent "metadata-secrecy rule" in defect text. Commit `c6283dc7f9d99e8ff6821f90ec216aa47f68692f` (fix) removed false citation, stated directive plainly, fixed grammar "rounds is" → "rounds are", added anonymous-grandchild fallback sentence. Reviewer PASS marker: `.claude/reviewed/adhoc-2026-08-06-orchestrator-nested-dispatch-guard.pass`. **Reviewer advisory notes (institutional memory):** (1) Fallback sentence's "wait for the intermediate persona's own natural completion **or resume**" is in mild tension with the subsection's "don't repeatedly resume" opening — recoverable from context, but future edit could tighten to "wait for its natural completion, then resume once to collect the result." (2) Unaddressed edge case: what if the INTERMEDIATE persona itself never completes (wedged, not slow)? The existing `TaskStop`-on-the-intermediate escape hatch elsewhere in "Managing a long-running background dispatch" applies, but this subsection doesn't cross-reference it. (3) The claim "internal agentIds are never surfaced in a user-facing reply" is now an uncontradicted assertion but not explicitly grounded in the repo — worth tying to a concrete constraint in a future pass, or noting it as a self-evident tool-behavior fact. No GitHub issue exists for this ad-hoc unit — orchestrator dispatch in response to live incident, not from spec-master/task-master pipeline.

## 2026-08-07 (release v0.24.0 + unit #255 terminal verification)
- **Completed unit #251 (Step 9 of skills-library remediation spec) — scribe dispatch:** recorded institutional knowledge and closed issue #251. Unit released the skills-library remediation spec completion (docs/plans/2026-08-04-skills-library-remediation.md, Step 9, terminal release tying together all prior units #246, #247, #248, #249, #250, #252, #253). Version bump: 0.23.0 → 0.24.0 across `package.json` and `.claude-plugin/plugin.json`; 16 files committed in `53a61f9`. Validated P2 (no hand-editing generated mirrors) and P3 (version-stamp discipline) via forced re-render in isolated worktree — content unchanged, confirming pure generator output. Confirmed zero `to-issues` references remain; confirmed `antislop:grilling` and `antislop:domain-modeling` now correctly wired into spec-master and scribe mirrors respectively. Acceptance: all 16 files version-stamped `antislop v0.24.0`, CHANGELOG.md new `## [0.24.0]` section, `bash tests/validate.sh` pass, `bash scripts/resync-vendored-skills.sh --check` pass, `node tests/adapter-protocol-parity.test.js` pass. PASS marker: `.claude/reviewed/251.pass`. Advisory notes (for future reference, not defects to fix now): (1) CHANGELOG.md:9 wording frames "disable-model-invocation ... now unreachable in all modes" as behaviour change — actually a documentation correction of pre-existing platform behaviour; (2) Pre-existing false positive: `node bin/cli.js --update` warning about unresolved placeholder in orchestrator.md — PLACEHOLDER_RE matches literal `<HEAD>` git ref at line 261, legitimate prose, present before this unit; (3) spec-master.md:37 contains awkward parenthetical "run the `grill-me` (the skill invoked is grilling) session next" from unit #250's source edit — should be cleaned up source-side.
- **Completed unit #255 (Step 10 of skills-library remediation spec) — scribe institutional knowledge:** skills-library-remediation plan is now **fully complete** with live post-restart reachability verification. This human-gated terminal unit refreshed the installed antislop plugin cache to v0.25.0 and verified all four previously-unreachable skills now load correctly in their respective personas' contexts (to-spec, to-tickets, handoff, improve-codebase-architecture count = 0 in `disable-model-invocation`; grill-me count = 1 as intentional anti-vacuity floor; domain-modeling present in scribe context; grilling present in milestone-auditor context; `Skill(antislop:to-tickets)` invocation succeeded). Cache gitCommitSha trails HEAD by two commits (immaterial, neither touched skill/persona files). **Key scribe digest:** (1) Steps 4/5's reachability claims are now verified **live at runtime**, not merely by file-content grep — the distinction matters for a plugin-cache-sourced system where repo edits don't reach agents until cache refresh + session restart. (2) **Reviewer process learning (recorded in project memory):** unit #255's first-pass reviewer marker reinterpreted a literally-failing machine-checkable criterion (c7, tree cleanliness at `git status --porcelain | wc -l` → 2, not 0) as passing "by intent" because the dirt was pre-existing #254 housekeeping, not unit #255's work. The human operator caught this, required literal re-verification after commit 72d612e (tree cleanup), and the reviewer self-reported this first-pass process error in the rewritten marker. Standing lesson: machine-checkable criterion failures are absolute; no "intent" reinterpretation. Updated CHANGELOG.md 0.24.0 entry to note live verification; updated CONTEXT.md to record plan completion. Affected repo files: `CHANGELOG.md`, `CONTEXT.md`, `.claude/wiki/changelog.md` (this entry). PASS marker: `.claude/reviewed/255.pass`. Issue #255 closed.

## 2026-08-06 (continued: unit #240 — Milestone 2 release, three-attempt saga with nested-dispatch and spec-gap incidents)
- **Completed unit #240 (Step 10, Milestone 2 release) — lead-programmer + spec-master + task-master + scribe** after THREE reviewer cycles with escalation to debug-spec and nested-dispatch incident. Version bump: 0.24.0 → 0.25.0; mirror regeneration; CHANGELOG.md entry naming F6 and F7 (spec-master ceremony conditional on measured ambiguity; ≤2-unit fast path). Full saga: **Attempt 1** (`e788127`, FAILed opus review) introduced two defects: (1) `.claude/protocol-digest.md` was cherry-picked out of the commit, leaving a stale version stamp; (2) CHANGELOG.md's F6 bullet cited spec risk labels "R-A, R-B, R-D" describing a different spec section, not F6 itself. **Fix-up** (`eb45cd8`) corrected both, but surfaced a NEW defect undetected by first-review: the F6 bullet's opening sentence falsely claimed "Grilling is now optional when scope is already enumerated," a plausible-sounding paraphrase contradicting reality. Unit #238 (commit `6a58dff`) only conditioned three things in `agents/spec-master.md:1383-1392` (dated `Q…→A…` lines, `CHKn` self-check, `to-spec` publication); grilling/interrogation itself remained unconditional. Original acceptance criterion 6 was substring-only (`grep -q 'F6'`), unable to catch plausible fabrication. **Attempt 2 FAILed** on this defect. **2-FAIL cap triggered:** orchestrator dispatched `spec-master` to produce debug spec, and `spec-master` spawned `task-master` directly as a nested background `Agent` call (no assigned name). Orchestrator repeatedly resumed the intermediate `spec-master` for status — three turns of zero-value replies — before correctly requesting the grandchild's `name` and reaching it directly. **Nested-dispatch incident:** user flagged the passive-waiting antipattern; this cascaded into the ad-hoc orchestrator-guard unit (committed separately, already PASSed, see 2026-08-06 entry above). `spec-master`'s debug spec (issue #240 comment) diagnosed the root cause (substring-only criterion 6) and prescribed: replace F6's false sentence verbatim with correct text from spec lines 1383-1392 (identifying the three real conditional elements); add new mechanical criterion 8 with three sub-checks (8a forbids claiming grilling/interrogation became conditional, 8b requires stating interrogation stays unconditional, 8c pins exact sentence via grep -F). **Second spec-gap:** fresh `task-master` dispatch (now routed directly, not nested) found a self-contradiction in debug-spec criterion 8 itself: "unconditional" contains "conditional" substring, and the original regex lacked word boundaries, causing 8b (stating "unconditional") to false-trigger 8a (forbidding "conditional"). `task-master` proved this empirically against a scratch copy — got n=1 where 0 was required — and correctly declined to patch locally, routing spec gap back up. `spec-master` dispatched again to fix ONLY criterion 8: added `\bconditional\b` word boundaries so "unconditional" no longer false-triggers 8a; fixed 8c to check normalized (newline-collapsed) text matching 8a/8b instead of raw multi-line grep -F (which also failed due to spec-mandated sentence wrapping). `spec-master` empirically verified the fix against four fixtures including exact line-wrap case. **Attempt 3** (`4c1530b`) PASSed after substantive reviewer verification: confirmed corrected F6 bullet accurately describes commit `6a58dff`'s actual changes; cross-checked against spec lines 1383-1392 real "Becomes CONDITIONAL" list; confirmed grilling genuinely remains unconditional in live `agents/spec-master.md:35-37`. **Three institutional findings for the record:** (1) Criterion-8 text originally posted to issue #240 tracker (during debug-spec) is stale/broken — first buggy version before word-boundary fix, literally unsatisfiable (grep -F line-orientation + conditional/unconditional substring collision); correct version now in issue #240's task-master comment. (2) Even the FIXED criterion 8(a) has subtle regression: dropped `-i` (case-insensitive) flag during word-boundary fix, vacuous against attempt 1's capital-G "Grilling is now optional..."; didn't affect PASS verdict (reviewer verified substance independently) but should be restored if pattern is reused. **Correct institutional form:** `s=$(sed -n '/F6 — spec-master/,/F7 —/p' CHANGELOG.md | sed '$d' | tr '\n' ' ' | tr -s ' '); n=$(printf '%s' "$s" | grep -incE '(grilling|interrogation) (is|becomes|now)?[^.]*?(optional|\bconditional\b)'); [ "$n" -eq 0 ]; n=$(printf '%s' "$s" | grep -ncE 'interrogation.{0,40}unconditional'); [ "$n" -ge 1 ]; n=$(printf '%s' "$s" | grep -F -c "Grilling/interrogation itself is unchanged and remains unconditional"); [ "$n" -ge 1 ]`. (3) Commits `5df1b8a`/`c6283dc` (separate orchestrator-guard unit) left `.claude/agents/orchestrator.md` and `.claude/persona-config.json` dirty relative to source — expected per that unit's changelog, not a defect. Commit `4c1530b` unaffected (touches only CHANGELOG.md). PASS marker: `.claude/reviewed/240.pass`. Issue #240 closed. **Affected files:** `CHANGELOG.md`, `package.json`, `.claude-plugin/plugin.json`, `.claude/agents/*.md` (9), `.claude/persona-protocol.md`, `.claude/persona-protocol-slim.md`, `.claude/persona-config.json`. Commits: `e788127` (attempt 1, FAIL), `eb45cd8` (fix, hidden defect → FAIL attempt 2), `4c1530b` (attempt 3, PASS).

## 2026-07-15 (continued)
- **Completed Track A (Step A.3) — Vendor the 3 repointed mattpocock skills:** vendored `to-spec`, `to-tickets`, and `code-review` from mattpocock/skills @ SHA e9fcdf95b402d360f90f1db8d776d5dd450f9234 as first-party `skills/` entries (provenance headers added). Each references `/setup-matt-pocock-skills` in upstream body — repointed to antislop's native mechanism (`install-antislop` + `.claude/persona-config.json` `issueTracker` field + retrieval contract) per plan design. No breaking changes to body prose besides the repoints. All 12 mattpocock-dependency skills now on disk (Track A complete): 9 byte-verbatim + 3 repointed. Acceptance: `grep -rniI 'setup-matt-pocock-skills' skills/to-spec skills/to-tickets skills/code-review` returns 0 matches; repoint recorded in each skill's provenance header; `bash tests/validate.sh` passes; `bash scripts/resync-vendored-skills.sh --check` exit 0 (0 drift on the pinned SHA).
- **Completed plan 2026-07-15-vendor-mattpocock-skills (all tracks A–F):** vendored the full 12-skill mattpocock dependency closure (grill-me, grilling, handoff, to-spec, to-tickets, tdd, diagnosing-bugs, improve-codebase-architecture, codebase-design, domain-modeling, implement, code-review) first-party into `skills/` under MIT license (© Matt Pocock), pinned at SHA e9fcdf95b402d360f90f1db8d776d5dd450f9234 (Track A complete: 9 byte-verbatim + 3 with documented repoints of /setup-matt-pocock-skills refs). Deleted the `<MATTPOCOCK:slot>` substitution machinery entirely (MATTPOCOCK_RE, applyMattpocockSubs, deriveMattpocockSubsForFile, hasMattpocockResidue, the substitutions map, --with-mattpocock/--only-mattpocock install paths, TDD-first test rewrite: Tracks B–C complete). Simplified install/adapt flow (mattpocock-selection step removed; issue-tracker capture moved to install-antislop native step: Track D complete). Documented periodic re-sync process (docs/maintenance/resync-vendored-skills.md + scripts/resync-vendored-skills.sh --check: Track E complete). Bumped version to 0.12.0, re-stamped all affected agent files, recorded capability loss (no more <MATTPOCOCK:slot> extension point; add new skills as first-party skills/<name>/ instead) in CHANGELOG.md [0.12.0] and new ADR-0005 (Track F complete). Acceptance: all Tracks landed reviewer-PASSed; plugin.json/package.json version equal at 0.12.0; all 12 skills `[OK]` under resync check; `bash tests/validate.sh` exit 0. ADR-0005 supersedes ADR-0003's slot-wiring language; deps.md and architecture.md updated to reflect final state (mattpocock/skills is one-time pinned source, not runtime dependency). Full plan: docs/plans/2026-07-15-vendor-mattpocock-skills.md. Re-sync runbook: docs/maintenance/resync-vendored-skills.md. Licenses: skills/THIRD-PARTY-NOTICES.md.
