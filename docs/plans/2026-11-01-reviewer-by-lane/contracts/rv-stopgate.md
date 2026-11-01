Unit: rv-stopgate

## Objective
A small-lane writer's stop writes no pending-review flag (plan decision D3, unit 3). `hooks/scripts/stop-gate.sh` works only on SubagentStop. It joins the writer to its `.claude/reviewed/dispatch-lane.log` record: the `toolUseId` from `${agent_transcript_path%.jsonl}.meta.json`, the first record whose second field is `tool_use_id=<that id>`, and the third field equal to `prompt=<sha256 of the transcript's first user message>`, hashed as `writer-scope-gate.sh` hashes it. Only on that match does it set `writer_lane` to the record's `lane=` word. In `stop-gate-core.sh` rule 6, when `${writer_lane:-}` is `small`, no flag is written and `<ts> small-lane agent=<id> no-flag` is appended to `review-audit.log`. The D6 marker check still runs. Every other case writes the flag as today. Update the core header's caller contract and rule 6. Keep every string that `tests/state-distinctions-manifest.test.sh` pins. Add one `[Unreleased]` CHANGELOG bullet. No version bump.

## Retrieval
No tracker issue. Spec: `docs/plans/2026-11-01-reviewer-by-lane.md`, unit 3, D3 and D4. This file is the contract of record. Depends on rv-lanerec, and on rv-harden having passed: this unit is the first to skip the reviewer.

## Affected files
- `hooks/scripts/stop-gate.sh`
- `hooks/scripts/lib/stop-gate-core.sh`
- `tests/stop-gate.test.sh`
- `CHANGELOG.md`
- `adapters/codex/hooks/scripts/lib/stop-gate-core.sh`, `adapters/cursor/hooks/scripts/lib/stop-gate-core.sh` and the `.claude/` copies, only through `node bin/cli.js --update --force-render`

## Do NOT touch
- `adapters/codex/hooks/scripts/stop-gate.sh`, `adapters/cursor/hooks/scripts/stop-gate.sh`, `hooks/scripts/writer-scope-gate.sh`, `eval/`, `tests/abtest-arms.test.sh`

## Acceptance criteria
1. run: `o=$(bash tests/stop-gate.test.sh); r=$?; grep -oE '^OK   \(rv-s[0-9]\)' <<<"$o" | sort -u | wc -l; exit $r`
   exit: 0
   stdout: `6`
   mutation: make the small branch write the flag anyway → `(rv-s1)` FAILs, exit 1; move the D6 loop inside the non-small branch → `(rv-s2)` FAILs.
2. run: `{ bash tests/adapter-stop-gate-parity.test.sh && bash tests/state-distinctions-manifest.test.sh && bash tests/state-access-constraints.test.sh && bash tests/review-gating-off.test.sh; } >/dev/null 2>&1`
   exit: 0
   stdout: empty
   mutation: in the codex core copy only, make rule 6 never write the flag → the parity test (`has_flag` cases) exits 1.
3. run: `node bin/cli.js --update --force-render >/dev/null && git diff --quiet -- .claude adapters ':!.claude/agent-memory'`
   exit: 0
   stdout: empty
   mutation: revert `adapters/cursor/hooks/scripts/lib/stop-gate-core.sh` to HEAD~1 → exit 1.
4. run: `bash tests/validate.sh >/dev/null 2>&1` (Bash tool timeout 600000 ms; once, after the final commit)
   exit: 0
   stdout: empty
