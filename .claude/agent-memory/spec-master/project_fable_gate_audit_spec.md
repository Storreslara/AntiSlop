---
name: fable-gate-audit-spec
description: 2026-09-09 fable gate-audit remediation spec (18 findings) — settled decisions plus 6 premise corrections where the audit's directed fix was not implementable as written
metadata:
  type: project
---

Spec: `docs/plans/2026-09-09-fable-gate-audit-remediation.md`, PRD view at
`Storreslara/AntiSlop#439`. 15 steps, 18 findings (C1, C2, M1-M9, m1-m7).
Human directed the fix for each; my job was verification + design, not
re-derivation. **All 4 Open Questions answered 2026-09-09, each taking my
recommended option** — drop M8's substitution half and pin it as a residual;
port M8's brace collapse plus a two-segment glob-match arm (F-1 reclassifies);
branch-split M6 across Set A/Set B; apply M7 in full, sequenced last.

**Settled, do not re-litigate:**
- C1 = unconditional `dispatch_name` check in
  `lib/reviewer-route-gate-core.sh` (privileged set derived, not restated:
  a drift test computes it from every `persona_matches_grant` second-arg
  literal under `hooks/scripts/` ∪ the caller allowlist = `{reviewer,
  orchestrator}`). Only the `Agent` PreToolUse payload carries `name`, so
  ONE check on the `Agent` matcher covers everything; no other gate needs it.
- C2 = git-index witness in `harness_armed`. Closes DETECTION, not
  prevention — `set_a_mentioned` does not match a bare `.claude` chunk, so
  `rm -rf .claude` is still undenied at the moment of the rm.
- M1/M2/M3 are ONE unit (same two files, same `review_join_state`).
- M4 has a hard dependency on C1; M7 must land LAST.
- M5 resolves `#` drift by ACCEPTING `#` everywhere (4 of 6 sites already
  do); rejecting would turn a malformed id into a missing review-join
  stamp, which fails OPEN.

**Six premise corrections — each is a case where the directed fix was
wrong or not portable as written. Re-check before trusting any similar
one-line remedy in a gate audit:**

1. **M8 substitution half is unimplementable.** "Move the `$(` rejection
   ahead of the early exit" denies EVERY command containing `$(`/backtick/
   `<(` from every non-reviewer identity — the fall-through has no allow
   branch. Blast radius includes this repo's own test invocations.
2. **M8 brace-collapse half is vacuous alone.** `set_a_mentioned`'s collapse
   only matters because it feeds a glob match against WHOLE-PATH literals.
   `mentions_marker_dir` substring-tests a DIRECTORY PREFIX, so collapsing
   `{...}`→`*` changes no verdict. A useful port needs a glob-match arm
   (recommended: truncate to two `/`-segments, `[[ ".claude/reviewed" ==
   $g2 ]]`), which also closes the F-1 glob residuals.
3. **M6 would delete three sanctioned escapes.** `.pending-review.*`,
   `.config-drift-override.*` and `.dispatch-override` all have documented,
   gate-recommended Bash write routes (`defer:`/`skip:`/`override:`) that
   the gates' OWN remediation text prints. Remedy: branch-split — the three
   with no route into Set A, the three with one into Set B (Write/Edit only).
4. **M7 double-gates one file.** `lib/benign-command.sh`'s own text spells
   `.claude//reviewed` (lines 207-209), so after Set B blocks Write/Edit, a
   whole-file heredoc rewrite is ALSO blocked by reviewed-path-gate. Precedent
   exists (`harness-integrity-gate.sh` has been in this state since Set B and
   is maintained via surgical Bash edits, e.g. `f52bec2`), but say it out loud.
5. **m1's `normalize_path` is not portable.** It lives in
   `lib/benign-command.sh`, which is `CLAUDE_ONLY_HOOK_LIB_FILES` —
   `protected-paths-core.sh` is SHARED and its codex/cursor copies cannot
   source it. Needs an inline resolver or a copy in `state-access.sh`.
6. **m2 must not go on the hot path.** Case-folding has to be an ADDITIONAL
   disjunct after the raw arms miss, never a replacement. `hdg-prose-2-fix2`
   measured a 195 KB command at 74 s already.

**Seventh premise correction — Step 5 / M5, found mid-flight by `task-master`
(2026-09-10, issue `#452`), NOT at authoring time.** The step said "six sites";
the measured census is **8 call sites across 7 files in 3 spellings**. Two
sites were missing (`dispatch-hygiene.sh:369` — the same `Unit:` ERE appears
twice in that file; and `lib/stop-gate-core.sh:260`, the `unit=` stamp
read-back). Criterion 2's count pin was unsatisfiable and is now an allowlist —
full write-up as trap thirteen in
[[feedback-verify-own-criteria-nonvacuous]]. Three decisions, settled:
- `agent_id`/`session_id`/`target_type`/path-head/identity-token charclass
  sites are **out of scope** — a different id domain; migrating them would
  admit `#` into WIP-sentinel and session-baseline filenames.
- `lib/stop-gate-core.sh:260` **stays in Step 5**, does not move to Step 3.
  A unit's criteria must be satisfiable within its own write scope (the CC1
  rule); moving it would strand Step 5's central criterion. Cost: a new
  **Step 3 ──► Step 5** ordering edge (`#442` before `#452`), because Step 3
  restructures `review_join_state` and could otherwise reintroduce an inline
  spelling past Step 5's already-PASSed pin.
- `human-decision-gate.sh:76` interpolates the **tail character class only** —
  substituting the whole `UNIT_ID_RE` would tighten a sanctioned-write
  allowance (rejects leading `_`, caps at 64 chars).

**Two premises reproduced LIVE this session (not read, run):** m6 — a
read-only `jq ... | head` probe of the persona-selection config was denied by
`harness-integrity-gate.sh`'s whole-command-only jq carve-out; and the
`human-decision-gate.sh` prose false positive — a plain `git grep` for
`human-review` + the decision token was denied. Both make excellent
pre-fix criteria.

**New lib files are load-time fatal.** `bin/cli.js`'s
`assertHookLibDeclarationComplete` throws on any file in `hooks/scripts/lib/`
absent from `SHARED_HOOK_LIB_FILES`/`CLAUDE_ONLY_HOOK_LIB_FILES`. Put a new
shared helper in an EXISTING declared lib (`state-access.sh`) unless you mean
to edit `bin/cli.js` too. See [[validate-sh-is-a-mirror-parity-check]].

**`docs/trust-model.md` is bijection-guarded** by
`tests/trust-model-bijection.test.js` with `EXPECTED_SELF_REPORTED_COUNT`
pinned at 9 — converting a row from self-reported to mechanically-checked
without bumping the count fails the suite. Any gate-behaviour spec needs this
as a cross-cutting criterion.
