Unit: lp-tidy

## Objective
Tidy stale persona and protocol prose left by earlier lean-pipeline units, and record what lp-orch deleted outright. Prose only, no behaviour change, no version bump. lp-tidy2 (`contracts/lp-tidy2.md`) carries the test, hook-comment and docs half.
1. `agents/spec-master.md`. The plan shape is Goal / Decisions / Units / Open Questions, so no `Context` or `Risks` section exists. Repoint every such mention: the prior-defect history and the ADR draft go in the plan's Decisions; the marker-sweep dispositions are recorded in `appendix.md` (this matches Output caps, which already puts the sweep there); the Constitution check is its own heading in `appendix.md`, with the "after the Risks/dependencies section and before Step 1" placement deleted; the PRD mapping reads `Decisions → Solution` and `Open Questions → Out of Scope`; the checkpoint bullet's last sentence says decisions live in the plan's Decisions and `appendix.md`. Self-check exists only at 6 or more units, so **Emit the dispatch contracts** starts `once the plan is written (at 6 or more units, once Self-check passes and, where used, ...)` and checkpoint (2) reads `plan doc written (and, at 6 or more units, Self-check passed)`.
2. `agents/milestone-auditor.md`: the Clarifications bullet reads the section from `docs/plans/<slug>/appendix.md`, which exists only for plans of 6 or more units.
3. `agents/reviewer.md` (the review-gating-off bullet): `read both keys with` becomes `read the key with`; only `reviewGating.mode` is read.
4. Nothing writes `.claude/reviewed/<task-id>.directed` since lp-hdg and lp-escbin retired the DECISION channel. Delete the `A .directed dispatch` bullet in `agents/lead-programmer.md` and the two-line `.directed` marker paragraph in `agents/orchestrator.md` (Review routing). Leave `docs/orchestrator-rationale.md` N10 as history.
5. Microworld text: escalation packets are gone. In `templates/persona-protocol.md` delete the `At escalation time` bullet and replace the body of `### Authoring policy for functions[] and location` with one sentence: `functions[]` and `location` are written with the bundle; the reviewer neither authors nor corrects them, and no packet copy or `verifiedBy` stamp exists (retired in 0.32.0). Make the same cut in the two adapter protocol ports and in the cursor reviewer copy (its `At escalation:` sentences through `carried over and checked.`).
6. `CHANGELOG.md`, one bullet under `## [Unreleased]`, titled `**Stale lean-pipeline prose is tidied (lp-tidy).**`, listing edits 1-5. The bullet also says the lp-orch cut deleted four orchestrator rules outright, naming each: forwarding the external run journal to the reviewer; the no-scribe fallback; mandatory naming of nested debug-spec dispatches; the issue body as guard input for units with no contract file.

## Retrieval
Fast path, no tracker issue. Spec: `docs/plans/2026-10-30-lean-pipeline.md`, section "Dispatch" (lp-tidy line). This file is the contract of record. Dispatch after lp-orch has PASSed and before lp-tidy2 and lp-scribe. Implementer tier: sonnet.

## Affected files
- `agents/spec-master.md`
- `agents/milestone-auditor.md`
- `agents/reviewer.md`
- `agents/lead-programmer.md`
- `agents/orchestrator.md`
- `templates/persona-protocol.md`
- `adapters/codex/agents-md-fragment.md`
- `adapters/cursor/rules/persona-protocol.mdc`
- `adapters/cursor/agents/reviewer.md`
- `CHANGELOG.md`
- `.claude/` mirrors, only via `node bin/cli.js --update --force-render`

## Do NOT touch
- `CONTEXT.md`, `docs/harness-glossary.md`, `docs/adr/`, `docs/orchestrator-rationale.md` (lp-scribe and history)
- `hooks/`, `tests/`, `README.md`, `docs/trust-model.md` (lp-tidy2), `eval/`, `bin/`
- The `Mode: advisory` sentences in `agents/orchestrator.md` (pinned by `tests/reviewer-dispatch-line-order.test.js`; lp-tidy2 records the missing consumer in a hook comment instead)
- Any orchestrator text other than the `.directed` paragraph; do not re-add text lp-orch removed.

## Acceptance criteria
1. run: `bash -c 'f=agents/spec-master.md; t=$(tr "\n" " " < $f | tr -s " "); echo "ctx=$(grep -cwE "Context|Risks" $f) wait=$(printf %s "$t" | grep -oE "Emit the dispatch contracts\*\*: once Self-check passes|plan doc written and Self-check passed" | wc -l) sweep=$(printf %s "$t" | grep -oE "disposition you record in .?appendix\.md" | wc -l)"'`
   exit: 0
   stdout: `ctx=0 wait=0 sweep=1`
   mutation: restore `Context or Risks section.` in the marker-sweep sentence → `ctx=1 wait=0 sweep=0`.
2. run: `bash -c 'grep -cE "Clarifications.*appendix\.md" agents/milestone-auditor.md || true'`
   exit: 0
   stdout: `1`
   mutation: `git checkout HEAD~1 -- agents/milestone-auditor.md` on the unit's commit → `0`.
3. run: `bash -c 'grep -c "both keys" agents/reviewer.md; grep -c "read the key with" agents/reviewer.md || true'`
   exit: 0
   stdout: `0` then `1`
   mutation: put `both keys` back → `1` then `0`.
4. run: `bash -c 'cat agents/lead-programmer.md agents/orchestrator.md | grep -c "\.directed" || true'`
   exit: 0
   stdout: `0`
   mutation: restore the orchestrator paragraph → `1`.
5. run: `bash -c 'cat templates/persona-protocol.md adapters/codex/agents-md-fragment.md adapters/cursor/rules/persona-protocol.mdc adapters/cursor/agents/reviewer.md | grep -ciE "escalation time|at escalation|escalation commit|escalating unit" || true'`
   exit: 0
   stdout: `0`
   mutation: restore the cursor reviewer sentence → `1`.
6. run: `bash -c 'awk "/^## \[Unreleased\]/{f=1;next} /^## \[/{f=0} f" CHANGELOG.md | grep -F "(lp-tidy)" | grep -F "run journal" | grep -F "no-scribe fallback" | grep -F "debug-spec" | grep -cF "issue body" || true'`
   exit: 0
   stdout: `1`
   mutation: drop `no-scribe fallback` from the bullet → `0`.
7. run: `{ test $(wc -c < agents/orchestrator.md) -le 16384 && bash tests/escalation-retired.test.sh prose && node tests/reviewer-dispatch-line-order.test.js && bash tests/persona-prose-pins.test.sh && bash tests/prompt-diet-pins.test.sh && node tests/adapter-protocol-parity.test.js && node tests/protocol-cross-references.test.js && bash tests/knowledge-writes.test.sh && node tests/writer-tier-consistency.test.js && node tests/cli-backfill.test.js; } >/dev/null 2>&1`
   exit: 0
   stdout: empty
   note: a preservation check; it passes today by design.
8. run: `node bin/cli.js --update --force-render >/dev/null && git diff --quiet -- .claude adapters` (C-mirror)
   exit: 0
   stdout: empty
9. run: `bash tests/validate.sh >/dev/null 2>&1` (Bash tool timeout 600000 ms; C-full, run once by the reviewer after the final commit)
   exit: 0
   stdout: empty

## Pre-resolved context
- Today (1227fa2a): criterion 1 prints `ctx=8 wait=2 sweep=0`; 2 gives `0`; 3 gives `1`,`0`; 4 gives `3`; 5 gives `7`; 6 gives `0`; 7 passes.
- No test pins any phrase this unit removes (grep of `tests/` and `bin/`, 2026-10-30). `.directed` remains in `hooks/scripts/lib/state-access.sh` and two tests as marker-type names; leave them.
- The cursor reviewer copy breaks `At` / `escalation:` across lines 170-171; criterion 5 still catches it via `escalation commit`.
- `adapters/cursor/agents/reviewer.md` is hand-synced, not rendered.

## Escalation
If a pin test fails on removed wording, stop and report the pin. If a gate blocks a write, report the path and the refusal text, and never route around it.
