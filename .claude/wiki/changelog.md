# Changelog (lead-programmer digest log)

Dated log of persona-driven work in this repo. Distinct from the project's
own `CHANGELOG.md` (which tracks plugin version releases for consumers).

## 2026-08-14 (Step 3 of the `--update` flag-surface plan — scribe dispatch, gh339)
- **Completed unit gh339 (issue #339, Step 3 of `docs/plans/2026-08-11-cli-update-flag-surface.md`) —
  documented the flag surface Steps 1 (gh336, `--personas=` additive union, #289) and 2 (gh338,
  `--force-render`/`--dry-run`/deprecated `--check`, #291) shipped, and released it as v0.31.50.**
  Rewrote `CONTEXT.md`'s `--update` semantics glossary entry (previously stale: called `--check` "a
  force-the-loop control, not a dry-run") to name `--force-render` as the canonical force-the-loop
  control, record `--check` as a deprecated writing alias, and point to the genuine no-write mode.
  Added two new glossary entries per the spec's terminology-consistency lens-3 finding: `--update
  --dry-run` (the no-write investigation mode, all twelve write sites, mutation-based `0`/`3`/`1` exit
  contract) and `--update --personas=` additive-union (explicitly contrasted with the fresh-scaffold
  path's replacement semantics for the same flag — a real confusion risk the glossary now heads off).
  Added `--dry-run` to `commands/update-antislop.md` as the safe pre-update investigation step. Bumped
  `package.json`/`.claude-plugin/plugin.json` 0.31.49 → 0.31.50, added a matching `CHANGELOG.md` entry
  covering both #289 and #291, and ran `node bin/cli.js --update` to restamp every mirror, committing
  the restamp together with `.claude/persona-config.json`'s `fileHashes` in the same commit (`e7f688c`)
  — the `gh308.fail` pairing this repo has failed on before. Post-commit verification: `node bin/cli.js
  --update --dry-run` exits 0 and `git status --porcelain` is clean for every file this unit touched.
  Reread both changed sections in full (C3.7): no sentence describes `--check` as canonical or claims
  `--force-render` is read-only. Affected files: `CONTEXT.md`, `commands/update-antislop.md`,
  `CHANGELOG.md`, `package.json`, `.claude-plugin/plugin.json`, plus the mechanical `.claude/` mirror
  restamp. Not yet reviewer-PASSed at the time of this entry — issue #339 left open pending review.

## 2026-08-11
- **Closed issue #323** (scribe post-PASS duties) — Step D10 reconciliation, dashboard polling clause.
  Unit #323 (commit `a1c4220`, PASS marker `.claude/reviewed/gh323.pass`) completed Step D10 of the
  microworld dashboard plan: reconciliation and documentation handoff. **D10 scope:** two new
  `CONTEXT.md` glossary entries (`[[The check]]` — the audit-log per-bundle exit-code verdict;
  `[[Function location]]` — file:line anchor convention for specs and docs, with staleness binding);
  one amendment to the existing `[[Microworld dashboard]]` entry (clarified "live status indicator
  polled every 5s via setInterval" matching implementation); one new ADR (docs/adr/0019-microworld-dashboard-supersedes-fixture-only-narrowing.md,
  renumbered from a stale 0017 during pre-dispatch reconciliation, explaining why dashboard's
  audit-log-derived status makes the older "narrowed fixture" pattern obsolete). Wiki updates:
  `.claude/wiki/architecture.md:67-85` documents the audit-log contract (producer, path, key=value
  format, "invoked per request never on startup", contract test); `.claude/wiki/architecture.md:100-105`
  documents the bundle-format-v2 conventions (zip structure, entry recipe keys). All acceptance criteria
  pass (grep for two new CONTEXT.md terms, ls count 1 for ADR file, bash tests/validate.sh).
  
  **Debug-spec correction pass (2-FAIL-cap escalation, third review, PASS at commit a1c4220):**
  Two prior FAILs prompted a spec-master escalation (`docs/plans/2026-08-11-gh323-debug-spec-dashboard-polling-clause.md`).
  **First FAIL** (commit `9fe3021`) — audit-log and manifest-schema descriptions had three independent
  errors: (1) audit-log path wrong; (2) key=value format claimed one value type but code uses another;
  (3) ADR cross-reference stale. Specification: D10 required wiki reconciliation to the existing running
  code, not aspirational rewrite. Fix: corrected all three; commit `9fe3021` amended seven wiki lines
  in `.claude/wiki/architecture.md`, verified against `bin/dashboard/discover.js:49-60`, `CHANGELOG.md`,
  and docs/adr/0008 (the stale reference). **Second FAIL** (commit `9fe3021`) — a single false claim
  about "live re-rendering on every poll": the client does **not** call `render()` (which would re-render
  the entire page); it calls only `renderLeftRail()` (a targeted update to the status-indicator `<span>`
  at index.html:143,156). Specification: Step 2 of the debug spec required the clause rewrite to state
  the polling interval, endpoint, render target, and trigger condition, all file:line-anchored. Fix:
  single-line replacement at `.claude/wiki/architecture.md:105`, replacing the overstated "live
  re-render" claim with precise "re-renders the left rail's audit-log-derived status indicator
  (renderLeftRail, index.html:124)" + two file:line anchors + the polling interval (5s) and endpoint
  (GET /api/bundles) + condition ("with no user action"). All six claim anchors verified source-first
  against bin/dashboard/index.html (lines 570, 124) and bin/dashboard/server.js (line 77). Deviation
  from debug spec (disclosed in PASS marker): spec's suggested closing fragment contained the literal
  substring "pull-on-request" which would collide with C-N1; rewording necessary and permitted under
  Step 2's "for scribe to adapt" license. FAIL-cap: 2-of-2, resolved.

- **Closed issue #138** (scribe post-PASS duties) — Step 8b, glossary + ADRs + wiki.
  Unit #138 (scribe documentation + domain-modeling) amended seven glossary entries
  in place in `CONTEXT.md` (Microworld bundle, Microworld, escalation packet, ESCALATE-TO-HUMAN,
  `.escalated` marker, `.directed` marker, humanReviewMode) — all seven already had canonical
  entries before this unit; none were newly added — with two required explicit contrasts
  (`.escalated` vs `.blocked`: reviewer lacked context vs. policy wants human eyes;
  microworld bundle vs escalation packet: gitignored scratch vs. durable snapshot).
  Wrote two ADRs: `docs/adr/0018-human-in-the-loop-review-on-by-default.md` (why on-by-default
  over opt-in; the behaviour change and its rationale; accepted costs; why not "all" or "off")
  and `docs/adr/0017-microworld-bundles-gitignored.md` (why bundles are working-tree scratch,
  not committed; the user's 2026-07-28 override and its reasoning; the survivability gap closed
  by escalation packets; R10 and R5 accepted limitations). Updated wiki: `.claude/wiki/architecture.md`
  documents the `.escalated`/`.directed` marker state machine and the escalation packet
  create/delete lifecycle; `.claude/wiki/conventions.md` documents microworld bundle layout,
  gitignored-scratch status, and run.sh relocatability rule; `.claude/wiki/changelog.md` records
  that human review ships **on** at `critical` (this entry). All acceptance criteria pass
  (bash tests/validate.sh, grep for three new CONTEXT.md terms, ls count 1 for each ADR file).
  G1 version bump: 0.31.23 → 0.31.24 (patch).
  
  **Debug-spec correction pass (2-FAIL-cap escalation, third review, PASS at commit 15c67d7):**
  Two prior FAILs prompted a spec-master escalation (`docs/plans/2026-08-11-gh138-debug-spec-wiki-accuracy.md`,
  Clarifications #3); this debug-spec correction pass resolved all noted defects.
  **D8 CLOSED:** `.claude/wiki/architecture.md:88-92` now states `.escalated` and packet are deleted
  in the same action that writes `.directed`, and that `.directed` is the only thing standing until
  the next resolution — now matches `templates/persona-protocol.md:417` and :419-421. **D9 CLOSED:**
  `.claude/wiki/conventions.md:33-36` now reads "lead-programmer executes run.sh during implementation,
  producing the bundle; reviewer verifies bundle presence by filesystem check (not a diff check) and
  never executes a bundle's entries" — verbatim-faithful to `templates/persona-protocol.md:481`.
  **D10 CLOSED as a class** (it was the generalization of D8/D9). **Note 5a CLOSED:** `changelog.md:8-11`
  corrected from "added six glossary entries" (demonstrably false) to accurate "amended seven glossary
  entries in place, none newly added" — verified against git diff. **Note 5b CLOSED:** `architecture.md:72-73`
  now credits unit #135 for implementing `humanReviewMode` and says #138 documented it, with no
  false claim of #138 flipping the live value. Scope verified: only three permitted wiki files touched.
  Single-commit scope (fbfed05, 3 files / +13 -8); no version bump owed (constitution v1.0.0 exempts
  wiki-only passes from the stamp-fastpath). PASS marker indicates all C1-C9 debug-spec block criteria green.

- **Closed issue #136** (scribe post-PASS duties) — Step 7 (amended), the
  human-decision-routing loop via the DECISION file. Unit #136 (commit
  `54d1fc326da67c7ad405e605aeb4660a6d10ee2c`, PASS marker
  `.claude/reviewed/gh136.pass`) built the reviewer-side mechanism that reads,
  verifies, and **transcribes** (never re-reviews) a human's `DECISION` file
  into a resolution — the final unit of the human-decision-channel-adjacent
  chain, and the mechanism the orchestrator uses next to resolve the
  long-standing gh134 escalation. **DECISION file, not chat relay:** the
  human writes `.claude/human-review/<task-id>/DECISION` in their own
  terminal; `human-decision-gate.sh` (Step 1/#325) blocks every agent
  identity, reviewer included, from creating or modifying it, so a decision
  relayed in a dispatch prompt or chat message is never a substitute for the
  file — the orchestrator surfaces the command template but never writes it
  and never offers to. **Staleness binding:** the DECISION file's
  `escalation:` timestamp must exactly match the standing `.escalated`
  marker's own first-line timestamp before the reviewer will transcribe it,
  so a DECISION left over from an earlier escalation of a unit can't resolve
  a later, different escalation of that same unit. **Three routes:** approve
  → `.pass` with an appended `human: approved by <name> <ts>` attestation
  line; reject with reason → `.fail` with the human's reason verbatim as the
  defect list (consumes a 2-FAIL-cap slot); fixable a specific way → new
  `.directed` marker (`DIRECTED <task-id> <ts> fix: <one-line human
  directive>`, human's full prescribed fix verbatim), which does NOT consume
  a cap slot (same logic as `INSUFFICIENT-CONTEXT`) and dispatches back to
  `lead-programmer` for a normal re-review. In all three routes the packet is
  deleted in the same reviewer action that deletes `.escalated`, via
  `rm -rf .claude/human-review/<task-id>` — the decision gate's sanctioned
  deletion path. **Review outcome:** clean single-pass PASS on commit
  `54d1fc326da67c7ad405e605aeb4660a6d10ee2c`, thirteen criteria including
  both adapter-protocol-parity and validate suites plus the pre-existing
  `tests/stop-gate-escalated.test.sh`.
  **Non-blocking notes carried forward from review (none fixed by this
  scribe pass — outside CONTEXT.md/changelog scope):**
  (a) `agents/reviewer.md:233-234`'s deletion instruction reads as if one
  `rm -rf .claude/human-review/<task-id>` removes both `.escalated` and the
  packet, but that command only removes the packet directory — `.escalated`
  (`.claude/reviewed/<task-id>.escalated`) needs its own separate `rm -f`,
  the same pattern already used for `.blocked` at reviewer.md:137/:150. Miss
  is fail-safe (stop-gate keeps blocking) but worth a future precision fix.
  (b) The new "Resolving an escalation" subsection's adapter-port content
  (`adapters/codex/agents-md-fragment.md`, `adapters/cursor/rules/persona-protocol.mdc`)
  is currently untested — a mutation deleting the whole subsection from both
  ports still passes parity+validate; the spec's own accepted tradeoff for a
  `###` subsection (no parity-map entry needed), but the ports can silently
  rot without a probe on a distinctive substring.
  (c) Approve-route provenance: at resolution time HEAD may have moved past
  the commit the human actually approved (gh134's `.escalated` records
  commit `fa5afeb`; HEAD is now `54d1fc3`), so the transcribed `.pass`
  records the resolution-time commit rather than the approved one, and the
  packet (which had the original commit) gets deleted, losing that
  provenance. Spec is silent on this.
  (d) `tests/stop-gate-escalated.test.sh:100` has a pre-existing `.directed`
  fixture using `decision:` instead of the now-canonical `fix:` field name —
  cosmetic (the stop-gate reads filenames only, never contents), no behavior
  impact, worth a spelling fix later.
  **Domain terms updated/added to CONTEXT.md:** `DECISION file` and
  `DECISION channel` entries corrected from forward-looking/unbuilt to
  shipped (the reviewer now reads and transcribes both); new `` `.directed`
  marker `` and `Staleness binding` glossary entries added. Issue #136
  closed with PASS marker and commit reference.

- **Closed issue #135** (scribe post-PASS duties) — Step 6, `humanReviewMode`
  ships as a real config field. Unit #135 (commit `134b3962e0b7ac842bc62ccac6fef5eab13b3df3`,
  PASS marker `.claude/reviewed/gh135.pass`) implemented Step 6 of the
  human-decision-channel plan: `templates/persona-config.schema.json` gains
  `humanReviewMode` (`enum: ["off","critical","all"]`, `default: "critical"`);
  `bin/cli.js`'s fresh-install skeleton writes `humanReviewMode: "critical"`;
  `agents/reviewer.md` documents reading the key from `.claude/persona-config.json`
  (or the adapted equivalent). **R1 fix — where the default actually lives:**
  the on-by-default posture is encoded as the reviewer-persona consumer's
  absent-key fallback (absent key **or any unrecognised value** both resolve to
  `critical`; only `off`, spelled exactly, disables it), *not* in the `--update`
  backfill path — `runUpdate`'s `existingPersonaConfig` branch is deliberately
  left untouched, so an already-adapted project never receives the key on
  update. Encoding the default in the backfill instead would have been the
  single most likely way to ship "on by default" that is silently off for every
  existing user; two new `tests/cli-backfill.test.js` cases pin the pair (fresh
  install carries the key with value `critical`; existing config without the
  field stays without it across `--update`, with a mutation control on
  `runUpdate` proving the test binds). `CHANGELOG.md`'s entry states this
  behavior change without softening. **Review outcome:** clean single-pass
  PASS on commit `134b3962e0b7ac842bc62ccac6fef5eab13b3df3`.
  **Deliberate deviation, disclosed:** issue #135 originally specified adding
  `"humanReviewMode": "critical"` to this repo's own live
  `.claude/persona-config.json` (self-dogfooding). That step was deliberately
  *not* performed — the live value stays `"off"` — per an active
  [[bootstrap window]] recorded in `docs/plans/2026-08-11-human-decision-channel.md`
  Step 4.1: the human-decision resolution channel (amended #136, Step 7) hasn't
  landed yet, and with `critical` live, this fix batch's own heavy-unit changes
  (hook code, security-sensitive) would each escalate into a route that doesn't
  exist. This is a **known, intentional gap**: the plan's runbook Step 4.7
  originally expected #135 itself to restore the `critical` posture, so with
  this deviation the restoration currently has no code unit tracking it. The
  **orchestrator** (not scribe, not a future dispatched code unit) is tracking
  that restoration as part of finishing the human-decision-channel runbook —
  recorded here for audit trail only, not an open action item for this wiki's
  maintainer.
  **Domain terms updated/added to CONTEXT.md:** `humanReviewMode` entry
  corrected from forward-looking/unbuilt to shipped; new `bootstrap window`
  entry added. Issue #135 closed with PASS marker and commit reference.

## 2026-08-10
- **Closed issue #133** (scribe post-PASS duties) — Step 4, fourth verdict `ESCALATE-TO-HUMAN`.
  Unit #133 (`feat(gh133)` commit `bf36317`, PASS marker `.claude/reviewed/gh133.pass` at
  commit `54b81f8`) implemented Step 4 of the install-antislop plan, adding the fourth
  reviewer verdict `ESCALATE-TO-HUMAN` and a durable escalation packet mechanism. **New
  verdict:** `ESCALATE-TO-HUMAN` is a gate on PASS (only a unit the reviewer *would have
  passed* escalates), never a replacement for FAIL. Verdict precedence is explicit:
  `FAIL` > `INSUFFICIENT-CONTEXT` > `ESCALATE-TO-HUMAN` > `PASS`. Trigger: when `humanReviewMode`
  is `all`, or is `critical` (default if absent) and the unit meets the heavy-unit trigger
  (referenced by pointer to ADR-0004 § "Heavy unit trigger", deliberately not restated to
  prevent future copy-divergence). **Marker and packet mechanism:** Reviewer writes `.escalated`
  marker file under `.claude/reviewed/` with fixed-shape first line
  `ESCALATE-TO-HUMAN <task-id> <ts> trigger: <criterion> microworld: <packet path or "none">`,
  followed by would-be verdict and non-blocking notes. In the same action, snapshots the unit's
  microworld bundle (if any) to `.claude/human-review/<task-id>/` plus a byte-identical
  `PACKET.md` copy of the marker body (marker authoritative on divergence). Units with no
  bundle still receive a packet directory with `PACKET.md` alone. **Why not under reviewed-markers:**
  `hooks/scripts/reviewed-path-gate.sh` blocks execution of anything under that path for
  non-reviewer callers, so a packet sited there would be unrunnable by the orchestrator or
  human — documented to prevent future "tidying." Packets are untracked (destroyed by `git clean -fdx`),
  documented but not fixed. Distinct from `.blocked` (lacked context vs. policy wants human
  eyes): separate marker files, separate audit-log tokens. Never consumes a 2-FAIL-cap slot.
  **Implementation scope:** new canonical section in `templates/persona-protocol.md` (Step 4
  only; Steps 5-7 unbuilt: stop-gate wiring, `humanReviewMode` config field, human-decision
  resolution routes). Hand-ports to adapter prose, parity-map entries, and `agents/reviewer.md`
  update (verdict list grows 3→4). `bin/cli.js` matrix updated (new section classified in all
  six full-tier rows, mirroring Third-verdict classification). G1 version bumped 0.31.15→0.31.16.
  **Files changed:** `templates/persona-protocol.md`, `adapters/cursor/rules/persona-protocol.mdc`,
  `adapters/codex/agents-md-fragment.md`, `agents/reviewer.md`, `templates/protocol-digest.md`,
  `bin/cli.js`, `tests/adapter-protocol-parity.test.js`, `CHANGELOG.md`, `plugin.json`,
  `package.json`, `.claude/persona-config.json`, and 13 mirrored agent files. **Review outcome:**
  single-pass PASS on commit `54b81f8`. **Reviewer advisory notes (scribe follow-ups):** (N1,
  non-blocking, prose-only) Five files repeat a now-stale claim that the reviewed-markers
  path gate blocks "read-only ones included" — a 2026-07-31 write-intent allowlist change
  made read-only inspection allowed; only execution is blocked. The directive ("don't site
  the packet under reviewed-markers") remains correct; reword for accuracy in a future unit.
  (N3, **scribe fixed immediately**, ubiquitous-language) CONTEXT.md "Escalation packet" entry
  was forward-looking; now stale (mechanism defined). Updated entry to reflect actual packet
  mechanism. Added four new glossary entries: `ESCALATE-TO-HUMAN` (the verdict), `.escalated`
  (marker file), `PACKET.md`, `humanReviewMode` (forward-looking config field, not yet
  implemented). **Domain terms added to CONTEXT.md:** ESCALATE-TO-HUMAN, .escalated marker,
  PACKET.md, humanReviewMode (forward-looking). Issue #133 closed with PASS marker and
  commit reference.

- **Closed issue #131** (scribe post-PASS duties) — Step 3a, `.gitignore` reach fix.
  Unit #131 (`feat(gh131)` commit `24154f5`, PASS marker `.claude/reviewed/gh131.pass`)
  implemented Step 3a of the install-antislop plan, extending `.gitignore` reach to four sites
  (this repo's `.gitignore`, plus three `bin/cli.js` scaffold `appendUnique` lists for adapters
  `.claude/`, `.cursor/`, `.codex/`), ensuring `microworlds/`, `<adapter-root>/human-review/`,
  and `<adapter-root>/microworld-audit.log` are consistently ignored across all three adapter
  variants. **R9 fix — the actual payload:** `runUpdate()` (line 821, claude-side only) gains
  its own idempotent `appendUnique` call for the claude-side lines, sited alongside existing
  `migrateGlobalProtocolImport` fixup. Previously a line added only at scaffold time would
  never reach an already-adapted project on `--update`, causing users to see bundles and
  escalation packets as untracked noise in `git status`. **Files changed:** `.gitignore`
  (4 new lines), `bin/cli.js` (four site edits: :2065 claude scaffold, :1398 cursor scaffold,
  :1778 codex scaffold, :897 runUpdate), `tests/cli-backfill.test.js` (new, proving the
  `runUpdate` path idempotent).

  **Advisory notes from second review (non-blocking):** (1) `appendUnique` substring-match
  semantics (line 156) would silently skip append if project has `!microworlds/` or
  `# microworlds/` pre-existing — pre-existing behavior, not new. (2) `runUpdate` is
  claude-only; already-adapted cursor/codex projects get no `--update` reach for adapter-side
  lines — per-spec for this unit, but a residual gap if adapter-side `--update` path ever exists.
  (3) **Ubiquitous-language gap:** "escalation packet" and `.claude/human-review/` are now
  load-bearing terms (appear in `.gitignore` and CHANGELOG) with no dedicated `CONTEXT.md`
  glossary entry beyond a parenthetical; scribe added entry in this same session. Issue #131 closed
  with PASS marker and commit reference.

- **Closed issue #321** (scribe post-PASS duties) — microworld dashboard D8 step.
  Unit #321 (`feat(gh321)` commit `f6ab291`, fix commit `2c60fae`, PASS marker
  `.claude/reviewed/gh321.pass` at commit `11d0576`) implemented Step D8 of the
  microworld dashboard plan, adding **escalation packets** (see [[Escalation
  packet]]) as a second read source for the dashboard alongside working
  bundles. `GET /api/bundles` now enumerates `.claude/human-review/<task-id>/`
  directories via a new `discoverPackets()` in `bin/dashboard/discover.js`,
  yielding bundles with `source: "packet"`, `id: packet:<task-id>`, and
  `status` always `null` (a snapshot, not a live rerun target — packets are
  never re-watched or re-scored). Working bundles (`source: "working"`,
  `id: working:<dirSlug>`) and packet bundles are concatenated, never merged,
  and rendered in two separately labelled `bin/dashboard/index.html` sections
  ("Working Bundles" / escalation packets). The `working:`/`packet:` id
  namespacing (see [[Bundle id namespace]]) is what makes a unit that has
  both a local bundle AND an escalation packet resolve to two distinct,
  independently invocable entries rather than a collision. **Files changed:**
  `bin/dashboard/discover.js` (`discoverPackets()` added), `bin/dashboard/server.js`
  (`dirSlug`/`source` path resolution for packet invocation, lines 189-197),
  `bin/dashboard/index.html` (second section + header), `tests/dashboard-packets.test.js`
  (new, cases (a)-(e)), `tests/validate.sh` (registered), `CHANGELOG.md`, version
  bump 0.31.16→0.31.17.

  **Review arc (FAIL→fix→PASS):** First review (`.claude/reviewed/gh321.fail`)
  FAILed the original build (commit `f6ab291`) because test cases (b) and (c)
  didn't actually exercise their stated criteria: (b) claimed to prove
  same-slug working-bundle + packet coexistence but used different slugs for
  the two fixtures, so a defect that dropped the working bundle on a real
  collision would have gone undetected; (c) claimed to prove a packet's
  `status` stays `null` even when a matching audit-log entry exists, but
  never actually wrote a matching audit-log fixture, so a defect that made
  `discoverPackets()` consult the audit log would have gone undetected either
  way. Fix pass (commit `2c60fae`, scope: `CHANGELOG.md` + `tests/dashboard-packets.test.js`
  only, no implementation file touched) rewrote (b) to use one shared slug
  (`same-unit`) for both a `makeBundle` and a `makePacket` fixture, asserting
  both `working:same-unit` and `packet:same-unit` are present with distinct
  ids; rewrote (c) to write a real `.claude/microworld-audit.log` entry
  matching the co-located working bundle's slug, asserting the working bundle
  reaches `status.result === 'pass'` while the packet stays `null` — proving
  the fixture is genuinely parsed rather than trivially absent. Second review
  mutation-tested both fixes (spliced the collision-handling line out /
  made `discoverPackets()` audit-log-aware) and confirmed each fixed test
  goes red under the reintroduced defect and the pre-fix test stayed green
  under the same mutation. FAIL-cap: 1-of-2, resolved.

  **ESCALATE-TO-HUMAN note (institutional record, not a defect):** the unit's
  diff size (525 insertions in `f6ab291` alone) meets ADR-0004's heavy-unit
  trigger criterion 1, and `humanReviewMode` (see [[humanReviewMode]]) is
  still unimplemented everywhere, which literally read would escalate this
  unit. The reviewer returned PASS instead, following the precedent set at
  `.claude/reviewed/gh133.pass` and accepted by the operator one unit prior,
  after independently re-verifying its mechanical premise (no hook consumes
  `.escalated`; writing one would leave the unit's review-join stamp
  unsatisfied and strand the session). Recorded here, not treated as
  resolving the open `humanReviewMode` gap (Steps 6-7 remain unbuilt).

  **Domain terms added/updated in CONTEXT.md:** `Bundle source` (added the
  now-implemented `"packet"` value and its always-`null` status semantics);
  `Bundle id namespace` (added the now-implemented `packet:<task-id>`
  namespace and the same-slug collision-coexistence design, proven live at
  review time with a `rev-probe` fixture pair in both `microworlds/` and
  `.claude/human-review/`). **Ubiquitous-language note:** "working bundle"
  (used informally in `tests/dashboard-packets.test.js`, `index.html`'s
  "Working Bundles" header, and `CHANGELOG.md`) is UI/test shorthand for "a
  microworld bundle with `source: working"`", not a second canonical term —
  the canonical term for the underlying directory remains **microworld
  bundle** (CONTEXT.md, unit #314). Pre-existing since D2's `source: "working"`
  design; surfaced by gh321's ubiquitous-language pass, not introduced by it;
  now flagged in the `Bundle source` entry's `_Avoid_` line.

  **Carried-forward advisory notes (non-blocking, re-verified fresh, not new
  defects):** (1) `bin/dashboard/discover.js:139-259` — `discoverPackets()` is
  a ~120-line near-verbatim copy of `discover()`'s per-directory loop, over
  the coding-discipline 60-line cap and a two-place maintenance hazard; a
  shared `readBundleDir()` helper would collapse both. (2) No test asserts
  `index.html:139,152` actually renders the two section headers or that
  packets never interleave with working bundles in the DOM — verified by
  reading the source (concatenated, never merged) but unexecuted;
  `tests/dashboard-feedback.test.js` case (m) is the precedent for asserting
  shipped-client markup, worth following for a future unit. (3) `discover.js:203`
  / `server.js:198` — `fn.entry` from a manifest flows into `path.join()`
  unvalidated (pre-existing, identical for working bundles, not introduced
  here), but this diff does widen the executable surface: any directory
  dropped into `.claude/human-review/` becomes invocable via the local HTTP
  endpoint. (4) The untested combination: test (d) covers packet invoke
  without a same-slug working bundle, test (b) covers same-slug discovery
  without invoke; invoking `packet:<slug>` while `microworlds/<slug>` also
  exists is untested (manually exercised and correct at review time; adding
  it to (b) would be cheap insurance). Issue #321 closed with PASS marker and
  commit reference.

- **Closed issue #320** (scribe post-PASS duties) — microworld dashboard D7 step.
  Unit #320 (`feat(gh320)` commit `26a0191`,
  PASS marker `.claude/reviewed/gh320.pass`) implemented Step D7 of the
  microworld dashboard plan, adding "Source excerpt" read primitive (`GET /api/source`,
  bounded, root-confined, symlink-safe via `fs.realpathSync.native`), a `GET /api/context`
  endpoint (returns git HEAD sha), free-text comment boxes per-function AND per-cell
  (ephemeral, never persisted to disk), and a "Copy feedback" button per scope producing
  a fixed markdown shape via a genuinely shared formatter (`bin/dashboard/feedback-block.js`,
  injected server-side into the served page so client and test suite exercise identical
  code path — not two divergent implementations). **Files changed:** `bin/dashboard/source.js`
  (new), `bin/dashboard/feedback-block.js` (new), `bin/dashboard/server.js` (edited: `GET /api/source`,
  `GET /api/context`, plus feedback-block source injection into `GET /`),
  `bin/dashboard/index.html` (edited: excerpt pane, per-function AND per-cell comment boxes +
  copy buttons, clipboard mechanics), `tests/dashboard-feedback.test.js` (new, 13 cases (a)-(m)),
  `tests/validate.sh` (registered).

  **Review arc (FAIL→fix→PASS):** First review (`.claude/reviewed/gh320.fail`, haiku) FAILed
  original build (commit `9a07895`) on 6 blocking defects: (1) security — `/api/source`'s
  path-containment check was purely lexical (no `fs.realpathSync`), so a symlink inside the
  project root pointing outside it was followed and its contents leaked via HTTP 200, live
  violation of plan guardrail 6; (2) `endLine < startLine` silently returned HTTP 200 with
  empty result instead of stated-reason 404 (plan explicitly forbids "a silent empty one"),
  reachable from shipped client's default endLine=100; (3) only one function-scoped comment
  box existed (hardcoded singleton id); plan required "per function AND per cell" with
  per-instance ids, and "`### Last run` appears only when copying from a cell" rule was
  inverted; (4) `feedback-block.js` (the issue's named pure formatter) was dead code —
  `index.html` re-implemented markdown shape inline instead, and two implementations had
  already diverged; (5) no truncation marker emitted for truncated cell result, contradicting
  plan's fixed block shape; (6) CHANGELOG/commit message falsely claimed working per-cell
  comment box. Per haiku-escalates-on-first-FAIL policy, re-dispatched on sonnet
  (fresh session). Fix pass (commit `26a0191`): real `fs.realpathSync.native` containment
  check for (1); stated-reason 404 for (2); genuine per-cell comment boxes with per-instance
  ids for (3), with corrected `### Last run` scoping (cell-copy only, sourced from that
  specific cell); server-side injection of `feedback-block.js`'s real source into served page
  for (4) (one implementation, not two); explicit `*(output truncated)*` marker for (5);
  (6) became true once (3) was genuinely fixed. Added test cases (j)-(m), each mutation-tested
  (revert → red with the original symptom → restore → green). Second review (`.claude/reviewed/gh320.pass`,
  opus tier due to prior FAIL) PASSed independently re-verifying all 6 fixes, including
  running reviewer's own broader symlink-escape sweep (6 vectors) and manually verifying
  "THAT cell, not the last cell" per-cell isolation property with live 3-cell drive (not
  just single-cell test suite coverage). FAIL-cap: 1-of-2, resolved.

  **Domain terms added to CONTEXT.md:** Feedback block (fixed-shape markdown artifact from
  Copy button, per-function or per-cell); Source excerpt (bounded, symlink-safe read of
  location.file lines). **Advisory notes from second review (institutional record, not
  defects):** (1) CHANGELOG.md 0.31.14 entry says "nine criteria (a)-(i))" but suite now
  has 13 (a)-(m) — stale enumeration, not false claim (original nine still exist/pass);
  consider updating if touching CHANGELOG for other reasons. (2) `server.js:117` uses
  String.prototype.replace with string pattern, scans feedback-block.js source for
  $-replacement sequences — currently harmless (none present), but fragile; future `replace(placeholder,
  () => src)` callback would be structurally safer. (3) TOCTOU note: `source.js` realpath-checks
  candidate but reads lexical path afterward — symlink swapped between check/read could
  theoretically be followed, but exploiting it requires write-access to project root
  (already implies arbitrary bundle-entry execution), so no real privilege escalation.
  Issue #320 closed with PASS marker and commit reference.

- **Closed issue #319** (scribe post-PASS duties) — microworld dashboard D6 step.
  Unit #319 (`feat(gh319)` commit `1b331b7`,
  PASS marker `.claude/reviewed/gh319.pass`) implemented Step D6 of the
  microworld dashboard plan, adding client-side in-memory **notebook** feature to track
  execution history of `POST /api/invoke` invocations as **cells**. Each cell stores
  `{ cellId, functionId, inputs, startedAt, result }`, appended (never overwritten)
  on invocation; re-running appends a NEW cell. Each cell renders with three controls:
  edit-and-re-run (prefills input form from cell's recorded `inputs`, no re-fetch of
  manifest), collapse/expand of output, and remove. Cells persist in-memory across
  tab switches but are NEVER persisted to disk, localStorage, sessionStorage, or
  indexedDB — lost on refresh by design (guardrail 5, in-page-only state). UI displays
  permanent text "each cell runs in a fresh process" to clarify cells share no state;
  this is enforced purely client-side, since D1/D4 already spawn fresh process per
  invoke. Zero server-side changes — no new HTTP route, `server.js`/`discover.js`/
  `audit-log.js`/`invoke.js` are byte-identical to before D6. **New domain terms
  introduced, added to CONTEXT.md glossary:** Cell (in-page record of one result,
  never persisted); Notebook (per-function ordered list of cells rendered in output
  pane). **Test suite:** `tests/dashboard-notebook.test.js` with 5 cases: (a) fresh-process
  proof via differing PIDs across two invocations, (b) no-shared-state proof via counter
  fixture (value never increases across invocations), (c) server route table byte-identical
  (no new endpoints), (d) GET / regression (still 200, still references /api/invoke), (e)
  real client-side test driving actual inline `<script type="module">` via `vm.createContext`
  against stub DOM — asserts fetch called with /api/invoke + correct body, cell appended
  per invoke, second invoke appends SECOND cell (not overwrite), post-invoke listener
  rewiring occurs, collapse toggle works both directions.

  **FAIL→fix→PASS arc (full fidelity, do not sanitize):** First review (`.claude/reviewed/gh319.fail`,
  reviewer agentId `a01dd61d5c074097c`) FAILed original build (commit `e9f2143`) on 4 real
  defects: (1) temporal-dead-zone `ReferenceError` on every "Run" click — duplicate/shadowing
  `const inputs = {}` declared AFTER its own use inside `invokeFunction()`'s try block meant
  `/api/invoke` was NEVER called and no cell was ever created — total regression of working
  D4/D5 invoke feature; (2) collapse/expand was dead (`isCollapsed` ternary evaluated to
  `false` for every input); (3) cells produced by invocation had no event listeners wired
  (`attachCellEventListeners()` wasn't called after `invokeFunction()`'s re-render); (4)
  original test suite exercised ZERO client-side JS (`makeFakeDOMEnv()` defined but never
  called, `vm` imported but never used), which is exactly why defects 1-3 all passed the
  4 original acceptance criteria. Per haiku-escalates-on-first-FAIL policy, re-dispatched on
  sonnet (fresh session) with full defect list. Fix pass (commit `1b331b7`): collapsed the
  duplicate input-collection into single pass reused by invoke call (removing shadowing
  declaration entirely, not just renaming); fixed collapse boolean to `cell.collapsed === true`;
  added missing `attachCellEventListeners()` call after `invokeFunction()`'s re-render; added
  real client-side test (e) using same `vm.createContext` pattern already proven in
  `tests/dashboard-client.test.js`. All 3 code fixes individually mutation-tested (reverting
  each one, one at a time, turns Test (e) red) by both fix-pass lead-programmer and,
  independently, second reviewer in its own throwaway worktree. Second review (`.claude/reviewed/gh319.pass`,
  reviewer agentId `af38d3d3dbe554405`, commit `1b331b7`, 2026-08-10T22:53:11Z) PASSed.
  FAIL-cap: 1-of-2, resolved on first fix attempt.

  **Non-blocking advisory notes from second review, carried into institutional record:**
  (1) CHANGELOG.md 0.31.13 entry still describes notebook suite as "four cases: (a)...(d)" —
  there are now five, and entry records none of FAIL-fix-PASS arc (unlike 0.31.12 D5 entry
  which has its own "### Fixed" subsection). Correct/extend CHANGELOG entry as part of this
  documentation pass if within scope, or note as open documentation debt if not. (2)
  `bin/dashboard/index.html:492` guard `if (!document.querySelectorAll) return;` lives in
  shipped production code; can never fire in real browser but future stub-DOM test omitting
  `querySelectorAll` could silently re-hide exact defect class (original defect 3) just fixed.
  Flagged as design smell, not blocking. (3) Test (e) covers invoke→append→re-invoke→append→collapse
  and post-invoke listener rewire, but NOT edit-and-re-run prefill, remove, or cell persistence
  across tab switch — all three spec-required behaviors. Reviewer manually verified all three work
  correctly against real inline script with richer DOM stub, so uncovered impact rather than defect,
  but same coverage shape that let defects 1-3 ship green first time. (4) Two pre-existing
  (not introduced by D6) minor issues carried forward from D5, confirmed still present: invoke
  error paths wipe rendered cell history from visible pane until next `renderContent()` (cells
  survive in `cellsByFunctionId`, no data loss, just rendering quirk); `isNaN('')` being `false`
  means cleared number field silently posts `0` instead of `null`. Issue #319 closed with PASS
  marker and commit reference.

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

## 2026-08-11
- **Closed issue #326** (scribe post-PASS duties) — Step 2 of the human-decision-channel
  fix (spec #324). Unit #326 (`fix(gh326)` commit `8803252`, `test(gh326)` commit `a828742`,
  version-bump commit `13841aa7e1967ca6beec8a58ae013faca973a310`, PASS marker
  `.claude/reviewed/gh326.pass`) closes the **escalation-laundering** hole in
  `reviewed-path-gate.sh`'s no-reviewer fallback: previously, deselecting the reviewer
  persona (removing `reviewer` from `personaSelection`) unconditionally re-armed the
  main-session write fallback for `.claude/reviewed/`, even while a standing `.escalated`
  marker existed — silently discarding a pending `ESCALATE-TO-HUMAN` escalation with zero
  human artifact. The fix, at `reviewed-path-gate.sh:105-116`, globs
  `.claude/reviewed/*.escalated` before the fallback's `exit 0` and blocks (`exit 2`) if any
  marker stands, naming the **DECISION channel** (Step 1/#325's `.claude/human-review/<task-id>/DECISION`
  mechanism) as the resolution route. With no `.escalated` marker standing, the fallback is
  unchanged. New test cases (j)-(n) in `tests/reviewed-path-gate.test.sh`: (j) a Write into
  the marker dir is blocked with a standing escalation, (k) an `rm` of the marker itself is
  blocked, (l) the fallback still allows a write when no escalation stands, (m) reads of the
  marker stay allowed, (n) the reviewer's grant is unaffected. **Unusual provenance:** the
  core hook edit (commit `8803252`) was made directly by the human at their own terminal, not
  by an agent, because Step 1/#325 added `reviewed-path-gate.sh` to `protectedPaths` — the
  lead-programmer correctly declined to act on an agent-relayed "human approved this" claim
  rather than treating the claim itself as consent, the same consent-channel principle
  discovered via the gh134 incident earlier this session (an agent-relayed approval claim is
  never a substitute for the human's own action). **Review outcome:** clean single-pass PASS,
  zero regressions across all 35+ pre-existing test cases plus the 5 new ones.
  **Flagged-but-not-fixed follow-ups (code-level, out of scribe's scope):** (a) **priority
  item** — `reviewed-path-gate.sh`'s own top-of-file header comment (lines 1-9) is now stale:
  it still describes the no-reviewer fallback as unconditional ("...or the main session/team
  lead in the documented no-reviewer fallback...") with no mention that a standing `.escalated`
  marker now suspends it (the actual behavior added at lines 106-113). This is a doc-vs-behavior
  drift inside the very file this unit changed — the same defect class that previously failed
  gh-286-docs in this project's history — worth flagging by name rather than folding into the
  general note below. Spec-directed to Step 3/#136. (b) Other doc locations
  (`agents/orchestrator.md`, `commands/start-feature-team.md`, `docs/adr/0002-reviewed-dir-owned-by-reviewer.md`)
  also don't yet describe the escalation suspension — same Step 3/#136 destination, next in
  this batch. **Domain terms added to CONTEXT.md:** **Escalation-laundering** (the attack this
  unit closes, contrasted with the legitimate no-reviewer fallback this unit preserves) and
  **DECISION channel** (cross-referenced to Step 1/#325's DECISION file mechanism). Affected
  files: `CONTEXT.md`, `.claude/wiki/changelog.md` (this entry). Did not touch `hooks/`,
  `tests/`, `agents/`, `commands/`, or `docs/adr/` (lead-programmer's/task-master's surfaces;
  the header-comment fix and other stale-docs items belong to Step 3/#136, already queued).
  Issue #326 closed with PASS marker and commit reference. Step 3 (amended #136) is next,
  depending on both #325 and #326 landing plus #135 (unchanged, elsewhere).

- **Closed issue #325** (scribe post-PASS duties) — Step 1 of the human-decision-channel
  fix (spec #324). Unit #325 (`feat(gh325)` commit `dab48f7`, `refactor(gh325)` commit
  `00ce4e5`, version-bump commit `4ba0e2b76aace8566cc95de643cd035d02fc318b`, PASS marker
  `.claude/reviewed/gh325.pass`) added `hooks/scripts/human-decision-gate.sh`, a new
  `PreToolUse` hook (registered for both `Write|Edit` and `Bash` matchers) that blocks
  **every** agent identity — reviewer included, empty/main-session `agent_type` included —
  from writing `.claude/human-review/<task-id>/DECISION`, the not-yet-consumed file that
  will carry a human's escalation resolution once Step 3 (amended #136) lands. No grant
  branch, no no-reviewer fallback: unlike `reviewed-path-gate.sh`, no identity may ever
  write this file. Reads stay allowed. The sanctioned way to discard a resolved packet is
  `rm -rf .claude/human-review/<task-id>` (its command text never spells `DECISION`, so it
  clears the substring early-exit); a per-file `rm .../DECISION` is blocked for everyone,
  reviewer included, by design. **Mechanical lib extraction:** the six-function benign-command
  lexer (`program_allowed`, `command_skeleton`, `mask_inert_redirections`, `segment_allowed`,
  `command_is_provably_benign`, `normalize_path`) moved verbatim out of `reviewed-path-gate.sh`
  into new `hooks/scripts/lib/benign-command.sh`, sourced by both gates now — `reviewed-path-gate.sh`'s
  own behavior unchanged, its test suite passes with zero assertion changes. **Review outcome:**
  clean PASS this round, no FAIL. Escalation declined (`humanReviewMode` reads `"off"`, the
  deliberate temporary bootstrap value, so ADR-0004's heavy-unit trigger did not fire).
  **Flagged-but-not-fixed follow-ups from the PASS marker (code-level, out of scribe's scope,
  left for a future lead-programmer unit):** (a) `tests/human-decision-gate.test.sh` is not
  registered in `tests/validate.sh`'s explicit suite list — every other hook suite is, so this
  is a real coverage gap (marker suggests adding it beside line 305); (b) `human-decision-gate.sh:44-50`
  anchors its match at the start of the normalized path, so an absolute `file_path` fails open
  when the `CLAUDE_PROJECT_DIR` prefix strip doesn't fire (verified reproducible with the var
  unset or trailing-slash) — not agent-reachable under Claude Code today since the harness always
  sets the var, but untested, and `reviewed-path-gate.sh` uses an unanchored substring that stays
  blocking in both cases by contrast; (c) `reviewed-path-gate.sh:27`'s header comment still says
  `command_is_provably_benign()` is defined "below," stale since the function moved to
  `lib/benign-command.sh` in `00ce4e5`. **Domain terms added to CONTEXT.md:** **DECISION file**
  and **the human-decision gate** (`human-decision-gate.sh`), closing the gap the PASS marker's
  ubiquitous-language note flagged (glossary had `Escalation packet`/`ESCALATE-TO-HUMAN`/
  `.escalated marker`/`PACKET.md` but no entry for the new consent artifact or the now-shared
  lexer). Also added a short "Agent-unwritable path as consent proof" note to
  `.claude/wiki/architecture.md`'s Hooks section, naming the pattern this gate introduces (no
  grant branch at all, contrasted with every prior gate's grant-one-identity-through shape) as
  novel and repo-defining. Affected files: `CONTEXT.md`, `.claude/wiki/architecture.md`,
  `.claude/wiki/changelog.md` (this entry). Did not touch `hooks/`, `tests/`, `README.md`, or
  `.claude/persona-config.json` (lead-programmer's surface, already landed and reviewed; the
  `humanReviewMode: "off"` bootstrap key is a deliberate temporary value, out of scope). Issue
  #325 closed with PASS marker and commit reference. Step 2 (#326, suspend the no-reviewer
  fallback while an escalation stands) is next and depends on this unit's lib extraction, which
  has landed.

- **Closed issue #322** (scribe post-PASS duties) — microworld dashboard D9 step
  (README.md documentation + packaging verification). Unit #322 (`docs(gh322)`
  commit `5ce1c5f7a2a94a6f15fd10babce394409f2a42ba`, PASS marker
  `.claude/reviewed/gh322.pass`) authored README.md's "Microworld dashboard"
  section from scratch: the `node bin/cli.js --dashboard` start command,
  loopback-bind + per-launch-token security posture (`?t=` query or
  `X-Antislop-Token` header), ephemeral in-page cells (never persisted, lost on
  refresh, each running in a fresh process), the feedback-block shape, and a
  "Dashboard-specific limitations" subsection (token visibility, bundle
  verification, stale location line numbers). Packaging assertions (`npm pack
  --dry-run --json` includes `bin/dashboard/`, `validate.sh`'s npm-pack
  included/excluded lists unchanged) were verified, requiring no `validate.sh`
  edit. **Review outcome:** single clean PASS this round — no FAIL, unlike the
  gh321 FAIL→fix→PASS arc the round before. 6 of 7 acceptance criteria passed
  literally; the 7th (an `awk` range over the "Known limitations" section
  piped to `grep -qi token`) is structurally vacuous — the range's end pattern
  matches its own start line and self-terminates after one line, so it can
  never pass for any content. Reviewer verified the substantive intent instead
  (token caveat genuinely present at README.md:211, correctly nested under
  "Dashboard-specific limitations") and did not fault the unit for a
  criterion-authoring defect. **Notable: this is the second consecutive unit**
  (after gh320's N1) with a structurally vacuous awk-range acceptance
  criterion — the same shape both times (a range whose end pattern
  self-matches the start line). Worth flagging to task-master/spec-master as a
  criterion-authoring pattern to lint against when future units generate
  awk-range criteria over markdown section headers.
  **Scribe follow-up (this entry, ubiquitous-language Lens 3):** README.md
  made "microworld dashboard" a headline term (README.md:177/179) with no
  dedicated CONTEXT.md entry for the server/UI process as a whole — only
  **Microworld** (an individual bundle's rendered dashboard entry) and
  **Microworld bundle** (the gitignored directory) existed. Renamed the
  stale, forward-looking **The dashboard** entry (unit #314, "not yet built")
  to **Microworld dashboard**, updated it to reflect that the dashboard is now
  built and documented, and cross-linked it against **Microworld** and
  **D5 browser client** to prevent the three terms blurring together. Also
  refreshed the **Microworld** entry's stale "not yet built" language. Did not
  touch README.md, `bin/dashboard/`, or `tests/` (lead-programmer's surface,
  already landed and reviewed); did not add the missing `bundle:` line to
  README.md's feedback-block enumeration (N2 in the PASS marker — a README
  completeness gap, out of scribe's write scope for this unit; CONTEXT.md's
  own **Feedback block** entry already lists "bundle path" correctly).
  **Domain terms added/updated in CONTEXT.md:** **Microworld dashboard**
  (renamed from **The dashboard**, updated from forward-looking to built),
  **Microworld** (staleness fix only). Affected files: `CONTEXT.md`,
  `.claude/wiki/changelog.md` (this entry). Issue #322 closed with PASS marker
  and commit reference.

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

## 2026-08-16 (gh405, Dispatch B — scribe, Step 5 of the ceremony-reduction plan)
- **Completed unit gh405 (issue #405, Dispatch B of Step 5 of
  `docs/plans/2026-08-15-ceremony-reduction-solo-operator.md`) — filed the
  ADR covering Steps 2-4, annotated ADR-0018, added four glossary entries.**
  `lead-programmer`'s Dispatch A (version bump, CHANGELOG, mirror
  regeneration) is a separate half of the same unit, not covered here.
  Determined the next free ADR number by listing `docs/adr/` live at
  execution time (highest on disk was `0023`, no concurrent claim found) and
  wrote [ADR 0024](../../docs/adr/0024-ceremony-reduction-solo-operator.md),
  covering Step 2 (milestone audit becomes on-demand), Step 3 (fast path
  ≤2→≤5, `to-spec` publish threshold ≥3→≥6, coupled per Open Question 3),
  and Step 4 (2-FAIL cap asks the human via `AskUserQuestion` instead of
  auto-spawning a debug spec) as one decision, with an in-body **Amends
  ADR-0003** line for the fast-path/publish thresholds and references to
  both ADR-0003 and ADR-0018. Added an inline annotation to
  [ADR 0018](../../docs/adr/0018-human-in-the-loop-review-on-by-default.md)
  recording that this repo now runs the documented `humanReviewMode: "off"`
  opt-out locally and permanently (the solo-operator posture, distinct from
  the earlier, now-closed bootstrap window) — the annotation does not
  reverse ADR-0018's decision; the shipped default stays `critical`. Added
  four new `CONTEXT.md` glossary entries: **on-demand milestone audit**
  (Step 2), **solo-operator posture** (Step 1, this repo's `humanReviewMode:
  "off"` + `dispatchHygiene.mode: "warn"` combination), **parked unit**
  (Step 4 option (c) — no marker written, none deleted, distinguishable only
  by absence of further dispatch), and **operator** (an explicit synonym of
  **human**, since Step 2's shipped trigger literal "only when the operator
  explicitly asks" put that word into persona prose with no matching
  glossary term). Made an additive consistency pass over the existing "FAIL
  routing (post-reviewer)" and "Dispatch hygiene" glossary entries (already
  substantively updated by Steps 4 and 1's own dispatches): linked the
  former's option-(c) mention to the new **parked unit** entry, and added a
  clause to the latter noting this repo's own config runs `warn`. Also
  corrected a staleness gap surfaced in passing: the `humanReviewMode`
  glossary entry stated the bootstrap-window closure returned this repo's
  config to `critical` "the same as any other adapted project" — true as of
  unit #136, but superseded by this plan's Step 1 (the config now runs `off`
  again, permanently); appended a superseding note rather than rewriting the
  historical statement. **Not touched, per this dispatch's explicit
  boundary:** `docs/adr/0003-hivemind-split-spec-master-task-master.md`'s two
  standing `**Superseded by (ADR TBD, Step 5):**` placeholders now have a
  concrete answer (ADR-0024) but resolving them was not in this dispatch's
  affected-files list — flagged here as a loose end for a future pass, not
  fixed. Affected files: `docs/adr/0024-ceremony-reduction-solo-operator.md`
  (new), `docs/adr/0018-human-in-the-loop-review-on-by-default.md`,
  `CONTEXT.md`, `.claude/wiki/changelog.md` (this entry).
