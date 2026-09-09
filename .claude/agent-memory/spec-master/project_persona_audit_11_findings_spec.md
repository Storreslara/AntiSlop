---
name: persona-audit-11-findings-spec
description: Settled decisions + 4 premise corrections for the 2026-09-04 persona-audit remediation (issue #428) — .fail append rationale, the marker-verify line-2 note trap, and the caller allowlist that already exists.
metadata:
  type: project
---

Spec: `docs/plans/2026-09-04-persona-system-adversarial-audit-remediation.md`,
umbrella issue #428, 10 sequential units closing 11 audit findings. Measured
at `4e90227`.

## Settled decisions (do not re-litigate)

- **`.fail` becomes APPEND, not rotate-to-`.fail.1`.** Chosen by measuring
  consumers. Append keeps all six working unchanged: `marker_format_valid()`
  (stop-gate-core) and `marker_valid()` (task-gate) check only that LINE 1
  begins `FAIL <id> `, and append leaves the oldest record there; the mtime
  still advances so the review-join `mtime > prior_mtime` test still resolves;
  `scripts/spend-accounting.sh` and `bin/human-review-cleanup.sh` glob `*.fail`
  and use existence/mtime only. Rotation would need every glob-based consumer
  edited AND creates a filename the cleanup sweep does not match.
- **Cap counting:** `grep -cE "^FAIL <id> [0-9]{4}-"`, anchored on the date so
  a defect line cannot be miscounted as a record.
- **Advisory token:** `Mode: advisory` as the **second** non-blank line, right
  after `Unit: <id>`. Positional anchoring only — an unanchored match lets a
  quoted example in a prompt body suppress a real stamp.

## Four premise corrections the audit got wrong

1. **"Restrict advisory to legitimate callers" needs NO new code.**
   `hooks/scripts/reviewer-route-gate.sh`'s caller allowlist already fails
   CLOSED for reviewer-targeted dispatches — only the orchestrator or bare
   main session can dispatch the reviewer at all. Every dispatch reaching the
   stamping code is already provably from the verdict owner. The caller check
   CANNOT move into the core: codex/cursor payloads carry no caller identity,
   which is why that block lives in the Claude entry script.
2. **"Strip the concrete tier names" would break a passing test.**
   `tests/writer-tier-consistency.test.js` AC-D7 pins the literal `Sonnet
   units escalate on first FAIL` in `agents/orchestrator.md`. Only the four
   FALSE claims may change. Bonus stale item the audit missed: orchestrator's
   `Suggested model: haiku|sonnet|opus` — task-master's real vocabulary is
   `sonnet|opus`, so `haiku` is not a tag value anyone emits.
3. **F10's new marker line WOULD be misparsed.** `marker-verify.sh`'s
   `run_notes_mode()` computes `start_line=$(( anchor_line > 0 ? anchor_line +
   1 : 2 ))` — with NO `Non-blocking notes:` anchor, extraction starts at
   **line 2**, exactly where a metadata line sits, and `extract_notes()` tags
   it `untagged`. One spurious untagged note per PASS marker would pollute
   `bin/marker-audit.sh --notes`, the sweep I myself consume. The parser guard
   must ship in the SAME unit.
4. **`marker-write.sh` has no ESCALATE verdict** — only PASS/FAIL/BLOCKED, and
   `usage_die` rejects the rest. Any "use the helper everywhere" wording is
   wrong for the escalation bullet.

## Structural facts worth reusing

- **Adapter HOOK LIBS are generated**, unlike the protocol ports:
  `buildAdapterLibSpecs()` in `bin/cli.js` renders
  `adapters/{codex,cursor}/hooks/scripts/lib/*.sh` from `hooks/scripts/lib/`.
  So a core-lib edit is ONE source + `--force-render`. But
  `adapters/codex/agents-md-fragment.md` and
  `adapters/cursor/rules/persona-protocol.mdc` stay HAND-edited.
- `stop-gate-core.sh` computes `agent_id` at :527, BELOW the reviewer branch
  (ends :442) — any reviewer-branch sentinel check needs the id hoisted, with
  the sanitization rule kept identical in both places.
- Both corrected protocol sentences live in **9 files each**, but the
  hand-edited subsets differ (F5: 3 sources; F7: 1 source + a frozen
  `prototype/` copy). Always `git grep -l`, never assume.

See [[protocol-amendments-do-not-propagate]],
[[validate-sh-is-a-mirror-parity-check]],
[[verify-own-criteria-nonvacuous]].
