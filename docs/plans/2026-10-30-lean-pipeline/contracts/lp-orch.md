Unit: lp-orch

## Objective
Cut the orchestrator prompt toward 15KB (plan change 5, decision D10, step "U11 lp-orch"). The source `agents/orchestrator.md` must be at most 16,384 bytes. The deployed `.claude/agents/orchestrator.md`, which carries the inlined protocol sections, must be at most 40,960 bytes.
- Keep these at runtime, condensed: the routing table, the lanes, the writer-to-reviewer rule, the fix-contract rule (lp-tmroute's sentence `On FAIL, the orchestrator writes the fix contract`), the `needs-human:` relay (lp-escprose), the scribe dispatch lines (lp-slim), the Escalation ladder and 2-FAIL cap, the contract-score guard, and one line on running `.claude/bin/unit-bookkeeping.sh` and `.claude/bin/ladder-tier.sh` and passing on their output.
- Move rationale, incident history and worked examples to `docs/orchestrator-rationale.md` as new `## N<k>:` entries. Delete any text that restates a protocol section the deployed file already inlines (the `PROTOCOL_SECTIONS_BY_PERSONA.orchestrator` include list in `bin/cli.js`). Delete any mechanics a script already carries out.
- The orchestrator's final message to the user is three lines (block below). Rulings and tier choices go to the rulings ledger only.
No version bump.

## Retrieval
Fast path, no tracker issue. Spec: `docs/plans/2026-10-30-lean-pipeline.md`, step "U11 lp-orch", D10, A2, R5, R6. This file is the contract of record. Dispatch after lp-slim has PASSed. Implementer tier: opus.

## Affected files
- `agents/orchestrator.md`, `docs/orchestrator-rationale.md`
- `adapters/codex/agents/orchestrator.toml`, `adapters/cursor/agents/orchestrator.md` (final-message block only)
- `bin/cli.js` (only the `orchestrator` row of `PROTOCOL_SECTIONS_BY_PERSONA`, and only if criterion 1's deployed half fails after the source cut)
- Prose pins on moved or deleted wording only: `tests/persona-prose-pins.test.sh`, `tests/prompt-diet-pins.test.sh`, `tests/writer-tier-consistency.test.js`, `tests/default-implementer-model.test.js`, `tests/orchestrator-model.test.js`, `tests/reviewer-dispatch-line-order.test.js`, `tests/cli-backfill.test.js`, `tests/adapter-protocol-parity.test.js`, `tests/unit-scope-prose.test.sh`, `tests/knowledge-writes.test.sh`
- `CHANGELOG.md` (one bullet under `## [Unreleased]`), `.claude/` mirrors via `node bin/cli.js --update --force-render`

## Ordered edits
1. Measure first. Record `wc -c` of both orchestrator files and of each `## ` section of the source in the notes line.
2. For each section, keep the rules listed in the Objective and nothing that duplicates an inlined protocol section. Move each paragraph that explains why a rule exists to `docs/orchestrator-rationale.md` as `## N<k>: <title> (from "<source section>")`, numbering from N6. Keep N1 to N5 and the file's header as they are.
3. Add this block at column 0 in a section named `## Final message`, with the sentence `Rulings and tier choices go to \`.claude/orchestrator-rulings.log\` only, never into the final message.`:
```
<unit-id>: PASS|FAIL <sha> <one-line result>
open: <open items, or none>
next: <the next dispatch, or the question for the user>
```
4. Add the same three lines, at column 0, to both adapter orchestrator copies. Change nothing else in the adapters.
5. Run the criterion 6 pin tests. A pin on a rule that is kept stays unchanged and must pass. A pin on moved text is repointed to `docs/orchestrator-rationale.md` with the same literal. A pin on deleted text is deleted, and its name goes in the CHANGELOG bullet.
6. Run `node bin/cli.js --update --force-render`. If the deployed file is still over 40,960 bytes, move a section the orchestrator never executes from `include` to `drop` in its `bin/cli.js` row, one at a time. Name each move in the notes line. If no section can go, stop (see Escalation).

## Do NOT touch
- Every other persona in `agents/`, `templates/`, `hooks/`, `skills/`, `commands/`
- The other rows of `PROTOCOL_SECTIONS_BY_PERSONA`, and the N1-N5 entries of `docs/orchestrator-rationale.md`
- `tests/abtest-*`, `eval/`, `CONTEXT.md`, `docs/harness-glossary.md`, `docs/adr/`
- Do not re-add text that earlier units removed: escalation steps (lp-escprose), task-master routing (lp-tmroute), or the "scribe digest" (lp-slim).

## Acceptance criteria
1. run: `bash -c 'echo "src=$(wc -c < agents/orchestrator.md) dep=$(wc -c < .claude/agents/orchestrator.md)"; test $(wc -c < agents/orchestrator.md) -le 16384 && test $(wc -c < .claude/agents/orchestrator.md) -le 40960 && echo ok'` → last line `ok`, exit 0. mutation: `git show $(git log --format=%H -1 --grep='(lp-slim)'):agents/orchestrator.md > agents/orchestrator.md` → no `ok`, exit 1.
2. run: `bash -c 'for s in "On FAIL, the orchestrator writes the fix contract" "needs-human:" "## Lane routing" "unit-bookkeeping.sh" "ladder-tier.sh" "contract-guard.js" "**Escalation ladder.**" "At the 2-FAIL cap"; do grep -cF -- "$s" agents/orchestrator.md; done | grep -c "^0$"'` → `0`. mutation: delete the fix-contract sentence → `1`.
3. run: `bash -c 'for f in agents/orchestrator.md adapters/cursor/agents/orchestrator.md adapters/codex/agents/orchestrator.toml; do for l in "<unit-id>: PASS|FAIL <sha> <one-line result>" "open: <open items, or none>" "next: <the next dispatch, or the question for the user>"; do grep -cxF -- "$l" "$f"; done; done | grep -vc "^1$"; grep -cF "Rulings and tier choices go to \`.claude/orchestrator-rulings.log\` only, never into the final message" agents/orchestrator.md'` → `0`, `1`. mutation: drop the `open:` line from the cursor copy → first count `1`.
4. run: `bash -c 'f=docs/orchestrator-rationale.md; echo "old=$(grep -cE "^## N[1-5]: " $f) new=$(grep -cE "^## N([6-9]|[1-9][0-9]): .*\(from \"" $f)"'` → `old=5 new=<n>` with n ≥ 1. mutation: `git checkout HEAD~1 -- docs/orchestrator-rationale.md` on the unit's commit → `new=0`.
5. run: `bash -c 'bash tests/escalation-retired.test.sh prose >/dev/null 2>&1 || echo esc-fail; grep -ciE "scribe digest|task-master" agents/orchestrator.md'` → `0` only. mutation: paste back an escalation step from before lp-escprose → `esc-fail` precedes the count.
6. run: `bash tests/persona-prose-pins.test.sh && bash tests/prompt-diet-pins.test.sh && node tests/writer-tier-consistency.test.js && node tests/default-implementer-model.test.js && node tests/orchestrator-model.test.js && node tests/reviewer-dispatch-line-order.test.js && node tests/cli-backfill.test.js && node tests/adapter-protocol-parity.test.js && bash tests/unit-scope-prose.test.sh && bash tests/knowledge-writes.test.sh` → exit 0. This is a preservation check: it passes today by design.
7. C-mirror: `node bin/cli.js --update --force-render >/dev/null && git diff --quiet -- .claude adapters` → exit 0. C-full: `bash tests/validate.sh` → exit 0, run once by the reviewer after the final commit.

## Pre-resolved context
- Today (2026-10-30, f56eba3d): criterion 1 prints `src=49729 dep=73765` and exits 1. Criterion 2 gives `2`, from the two anchors that earlier units add. Criterion 3 gives `9`, `0`. Criterion 4 gives `old=5 new=0`. Criterion 5 prints `esc-fail` and `29`. Criterion 6 passes.
- The deployed file is the source plus about 24KB of inlined protocol (73765 - 49729 = 24036). At a 16,384-byte source that is about 40,420 bytes before lp-escprose and lp-stopgate shrink the protocol, so the source cap usually also satisfies the deployed cap. Edit 6 exists for assumption A2.
- `docs/orchestrator-rationale.md` already exists (qw-u2, 3,844 bytes, N1 to N5). `tests/prompt-diet-pins.test.sh:37,116,119` pin N1 to N5 and the orchestrator's pointer to N1. Keep both.
- `.claude/agents/orchestrator.md` is only ever written by `node bin/cli.js --update --force-render`.

## Escalation
If the deployed file stays over 40,960 bytes after edit 6, stop and report both measured sizes (A2). If a pin fails on a rule the Objective says to keep, stop and report the pin and the rule. If a gate blocks a write, report the path and the refusal text, and never route around it.
