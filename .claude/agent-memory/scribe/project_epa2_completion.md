---
name: escalation-packet follow-ups (epa, epf, epfb)
description: vln-1..4 closure (lane runner process groups and busy-tree retry; open items: KILL escalation, stale plan range, exit-99 handling, vlg3-ac1 116 pin); lgc-1 closure (leak guard sandbox, j closed by likely cause); epa-2..4 carry-forward gaps for the escalation layout, card/fold marker, viewer tests and parity probes; the epf run (epf-1..6, 2026-10-13) that closed items 1-14; the epfb run (epfb-1..5, 2026-10-13) that closed a-i; and the live carry-forward list (j, plus epfb notes 1-5)
metadata:
  type: project
---

**epa-2: PASS 2026-10-12, commit 60ff302, version 0.31.157.** Scribe pass (5a26e69) aligned two glossary entries and minted **terminal reader**.

- **literate change summary** and **worked example** match the shipped wording: a `>` blockquote line, and `**Before:**` / `**After:**` lines.
- **terminal reader** is the plain-text layout contract. **epa-3 (PASS 2026-10-12, ac1e511, 0.31.158)** added `view.sh`, which renders in colour only when a renderer exists and otherwise falls back to `cat`, so the plain-text layout still holds. If a later unit adds a layout rule, update the entry rather than adding a second term.
- **epa-3 scribe pass:** the **packet viewer** CONTEXT.md entry said "comprehension tooling"; reworded to "a viewer for **comprehension material** only", the existing term. No other glossary change.

## Carry-forward (epa-2..4 original list, 1-14)

Items 1-14 are closed (epf-1..6 and epfb-1..5); do not re-check them.

- 1, 6 (partly), 7, 10, 11: epf-6 erratum on the 2026-10-12 plan. Item 3 (OQ1/R4) resolved by epf-4 + epf-6.
- 2: epf-2 added 4 `// epf-2` parity probes. 4, 5: epf-3 (O1-O4 order cases, stderr-empty T8). 6: epf-3 T1b golden copy.
- 3: epf-4 (markdown-lite pipe tables, TB1-TB10). 8: epf-5 (parseProtocolSections ignores fenced `## `, F1-F3).
- 9: epf-6 fixed the stale line at 2026-10-01 plan :928.
- 12: epf-1 (old marker printed whole; default Q1 text; parity-pinned). 13: epf-2 (skip token is now ASCII hyphen `examples: none - <reason>`). 14: epf-2 (card follow-on is a list item).

## epf closure (epf-1..6, PASS 2026-10-13; 1f261e7, 4b56fb7, 811449d, 11919a8, 6c994d5, 1b14288)

Carry-forward items a-h from the epf reviewers were closed by the epfb run below (a was closed by the epf scribe pass itself). The epf-4 item i (contract wording defects) is handled by the plan's Contract hygiene rule.

**Closed:** the epa-1 gap (orchestrator.md step 3 lacked the "without the Read tool's line-number prefixes" clause) was closed by epa-3.

## epfb closure (epfb-1..5, PASS 2026-10-13; 4ce147d, 0d141c4, f0443ec, 278a94c, da2fb37; version 0.31.162)

- **a** (CONTEXT.md card entry lacked the no-fold clause): closed by the epf scribe pass.
- **b** (templates/persona-protocol.md ~609 ~200-column line): closed by epfb-1 (re-flowed to 80 cols).
- **c** (agents/reviewer.md "per the bullet after next"): closed by epfb-1 (pointer now names the "Resolving a standing escalation" bullet).
- **d** (no test for the hyphen-only skip token or list item after card): closed by epfb-2 (EB1 and EB2 in tests/adapter-protocol-parity.test.js).
- **e** ("Durable escalation packet" restates the glossary term): closed by epfb-1 (alias sentence in the CONTEXT.md Escalation packet entry).
- **f** (markdown-lite table body and escaped backslash): closed by epfb-3 (mdStartsBlock, mdSplitRow escape handling, TB11-TB17, VM1 vm-load). See new note 1 for the remaining `* ` branch gap.
- **g** (parseProtocolSections inline code span and CRLF closer): closed by epfb-4 (check F4). See new notes 2 and 3.
- **h** (O4 `grep -q raw` could match a random mktemp suffix): closed by epfb-5 (T4, T5, O4 anchored with `-qxE`).
- **i** (contract wording defects): handled by the plan's Contract hygiene rule.
- **j** (validate.sh exited 1 under ~5 concurrent runs): still unreproduced; gate G passed clean at HEAD da2fb37. Keep open as a watch item, not a defect.

## epfc closure (epfc-1..5, PASS 2026-10-13; 04f3862, 2bcf0c8, f71f5c8, 52ac70b, c9e1578; no version bump)

Closed epfb notes 1-5: 1 by epfc-1 (TB18 pins the `* ` branch of mdStartsBlock); 2 by epfc-2 (mutants (d)/(e) in docs/plans/epfb-criteria/epfb4-ac3.sh for F4 cases 3, 4); 3 by epfc-3 (no-preamble `## ` case is a documented non-goal, comment in bin/cli.js, check F5); 4 by epfc-4 (EB1 uses a local splitFences: skip token required in prose and inside the card fence); 5 by epfc-5 (CONTEXT.md Escalation packet alias names templates/persona-protocol.md; epfb1-ac3.sh pin updated). No glossary change by the scribe pass. Do not re-check these.

## epfd closure (epfd-1..3, PASS 2026-10-13; 5f98e4c, 02b131c, 4f3055b; no version bump)

Closed the epfc open items: epfd-1 made mutant (d) in docs/plans/epfb-criteria/epfb4-ac3.sh position-exact (line index, lookahead from li + 1, plus a guard line), replacing the `indexOf` lookup. epfd-2 added a bare `## ` input to F5 in tests/protocol-cross-references.test.js; a trailing-newline input was deliberately not added because F2/F4 already catch it. epfd-3 added SF1 (six direct cases) for the local splitFences helper in tests/adapter-protocol-parity.test.js; nothing exported from bin/. No glossary change. Do not re-check these.

## vtmp closure (vtmp-1, PASS 2026-10-14; 1e915f7; no version bump)

tests/validate.sh sections 5, 6, 7, 10 and 67 now write scratch files via per-run `mktemp` (npm_pack_err, marketplace_err, claude_plugin_tag_out, frontmatter_yaml_err, codex_toml_err) instead of fixed /tmp names; each section's existing `rm -f` cleans them. Messages and behaviour unchanged. Fast path, no issue. No glossary change.

**Corrected reasoning for j:** the vtmp plan measured that the fixed /tmp names cannot change an exit code (30/30 exit 0 with six concurrent runs), so vtmp-1 is hygiene and does NOT explain j. Remaining unverified candidates for j: shared `.claude/` marker state, git `index.lock`, fixed ports in the dashboard sections.

**Timing profile (explorer report, not a unit):** serial validate.sh is about 435 s; 29 sections take >=1 s and total 419 s. Top costs: section 109 (136 s, probe-hook-identity tests), 115 (83 s, unit-outcomes.js), 49 (62 s, human-decision gate), 25 and 48 (about 21 s each).

**Not-started follow-up:** run validate.sh in three parallel lanes (about 60% saving). Prerequisite: isolate `.claude/` marker state and the git index first (same shared state is a j suspect). No unit or spec exists yet.

## lgc closure (lgc-1, PASS 2026-10-14; 67b3a26; no version bump; fast path, no issue)

tests/reviewed-dir-leak-guard.test.sh (validate.sh section 101) no longer lists the live reviewed-marker directory. It runs the nested validate.sh with `CLAUDE_PROJECT_DIR` pointing at a fresh `mktemp` sandbox holding an empty marker directory, and FAILs if any entry appears or the directory is removed; an EXIT trap cleans the sandbox. This removes false FAILs from legitimate concurrent reviewer/implementer marker writes. It still catches the gh425 leak route (via `CLAUDE_PROJECT_DIR`) and now also overwrites of existing names.

- **gh425-2 note 3 (overwrite of an existing name): closed** by lgc-1.
- **j: closed by likely cause** (leak guard false FAIL on concurrent reviewer writes). Reopen if it recurs. The original failing run's output was not kept, so this is unconfirmed.
- **Gate usage:** merge-gate vsec runs with `REVIEWED_DIR_LEAK_GUARD_NESTED=1` make section 101 a no-op. Run `vsec 101 101` WITHOUT that variable to exercise the real guard through the sandbox (done at HEAD, exit 0).
- **Open note 1:** the guard discards the nested run's exit code, so an early-aborting nested suite would silently shrink what the guard sees.
- **Open note 2 (accepted gap, plan Open Question 1 default):** a suite or hook that writes the marker path relative to the repo root or via an explicit repo-root argument (marker-commit-check.sh, marker-verify.sh) while ignoring `CLAUDE_PROJECT_DIR` is not caught.
- **Open note 3:** parallel-lanes speedup for validate.sh (about 60%) is still not started; needs `.claude/` marker and git-index isolation first. The tmp-name (vtmp-1) and leak-guard hazards are now fixed.
- **CONTEXT.md left alone:** "leak guard" and "watch item" are test-suite/process vocabulary, explained in the test file and here; no domain or harness-mechanics reader needs them defined, so a glossary entry is not load-bearing.

## vlg closure (vlg-1..3, PASS 2026-10-14; 7adddc1, 4ed8fc9, 5178319; no version bump)

vlg-1: the leak guard (validate.sh section 101) judges the nested run by exit code plus last non-blank line (0 + "All checks passed." OK; 1 + "One or more checks FAILED." NOTE only; else FAIL "did not finish") and sets `ANTISLOP_VALIDATE_INNER=1`; repo-root-relative writers remain a documented accepted gap in the serial guard. vlg-2: opt-in `tests/validate-lanes.sh` (lane copies; closes the repo-root-relative gap there). vlg-3: `tests/validate-lanes.test.sh` is section 116, CONTRIBUTING.md bullet. Closed lgc notes 1-3. Glossary: **lane runner** and **lane copy** added to docs/harness-glossary.md only.

**Open reviewer notes (non-blocking):** the EXIT trap kills only lane subshells (tar/bash children survive TERM/INT); tar "file changed as we read it" reddens a busy-tree run (run on a quiet tree); the vlg-3 test lacks mutants for L1/L6/L9 and `tree()` ignores git setup failure; the guard header says "item 2" where the plan says "Note 2"; nested.out lives inside the sandbox; the plan's measured timings are stale.

## vln closure (vln-1..4, PASS 2026-10-14; 31dc1a6, 3efa204, 7278604, 912e2b3; criterion amendment 4894be2; no version bump; no issue)

- **vln-1** (`tests/validate-lanes.sh`): lanes run in their own process groups with stdin from /dev/null; the EXIT/TERM/INT trap sends TERM to each group, waits, then removes the work dir. A lane copy retries up to 3 times only when tar create exits 1 and extract exits 0 (a `NOTE lane k:` line each time); any other status or a third failure is FAIL naming the tar exits. Closes the vlg notes "trap kills only lane subshells" and "busy tree reddens the run" (the latter partly: a third failure still FAILs by design).
- **vln-2** (`tests/validate-lanes.test.sh`, 106 to 152 lines): `tree()` exits 99 on git setup failure; new L10 (SIGTERM leaves no surviving process) and L11 (busy-tree copy retried); L9 moved last; mutants for L1/L6/L9 live in criterion vln2-ac2. Closes the vlg notes on test mutants and ignored `tree()` failure.
- **vln-3** (`tests/reviewed-dir-leak-guard.test.sh`): `nested.out` is a second mktemp outside the sandbox, removed by the same EXIT trap; header "item 2" now "Note 2". Closes the vlg notes on the header and on `nested.out` inside the sandbox.
- **vln-4**: vlg plan's vlg-3 `measured:` line now reads about 0.35 s / about 3 s. Closes the stale-timings note.
- **4894be2**: spec-master amended criterion vln2-ac1 (it no longer pins the validate.sh section count).

**Open after vln (non-blocking, carried forward):**
1. vln-1: the bare `wait` has no KILL escalation; a process that leaves its group (setsid) or ignores TERM is not reached (documented in a runner comment).
2. vln-2 plan: its Pre-resolved context still cites `tests/validate-lanes.test.sh:1-106` (the file is now 1-152).
3. `tests/validate.sh` treats exit 99 (test-setup failure) like any other FAIL; no distinct message.
4. `docs/plans/vlg-criteria/vlg3-ac1.sh` pins 116 sections; `tests/validate.sh` has 118 (implementer digest, not re-counted here). Stale criterion.

## Live carry-forward

- **j:** closed by likely cause; reopen only if validate.sh exits 1 under concurrency again.
- **lgc notes 1-3** and **all vlg open notes:** closed by vln (see above).
- **Open:** vln items 1-4 only.

**Why:** reviewers' non-blocking notes the plan does not record elsewhere. **How to apply:** everything above is closed except vln open items 1-4; check those before re-raising any lane-runner note.
