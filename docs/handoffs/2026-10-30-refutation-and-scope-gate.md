# Handoff: AntiSlop refutation pass, tooling fixes and scope-gate hardening

Repo `/home/sebas/AntiSlop`, branch `master`, HEAD `50d57bd2` at time of writing. Tree clean, no pending-review flags or review-join stamps. Every unit below is reviewer-PASSed.

## Done

| Work | Units | Final commits |
|---|---|---|
| Refutation pass (reviewer tries to disprove its own judgment defects), plus hardening and follow-ups | rfp-u1 to u7e | PASSed. Gate G2 passed: 41 real defects, 1 refuted, 25 confirmed, 15 uncertain. |
| Precheck "A then B" multi-part stdout specs | tg-u1 | `9306b7d9`, fix `0e0a2141` |
| Scope-gate false positives (bare bullets, the unit's own contract read at the baseline) | tg-u2 | `c07e9283`, fix `ab174935` |
| Cosmetic close-out | cos-u1 to cos-u5 | `6b4bda80`, `1a987d32`, `ecc8104e` (version 0.31.226), `712a5a9e`, `f566aeef` |
| `$start` baseline hardening | sgb-u1, sgb-u2 | `935170b0`, `1e4659a1` |
| "dispatch baseline" glossary entry | sgb-scribe | `50d57bd2` |

cos-u5 took four reviews: each of the first three failed on one false clause in the "dispatch message" glossary entry; the fourth cut the entry to verified statements.

Hardening: `dispatch-hygiene.sh` records the dispatcher's HEAD for each writer dispatch. `writer-scope-gate.sh` takes its baseline only from that record, matched by `tool_use_id` and the dispatch-message hash. It ignores `git replace` objects and grafts. With no usable record it fails closed if the writer changed anything. The reviewer showed all seven forgery variants give rc=0 on the old gate and are blocked by the new one.

## Open items

Specced and held, awaiting the user's go: `docs/plans/2026-10-29-wording-followups.md`.

- wrd-u1: `bin/review-precheck.sh`, its test, mirror and config hashes. A spec ending in an empty part now fails; the "sentinel" comment is reworded. Sonnet or above.
- wrd-u2: `label.py`, `score.py`, label-server test. Comment fix, 160-character cap with a test, docstring fix. Sonnet or above.
- wrd-u3: glossary edits ("double quote", dropped "can be added" clause, new "amended line" entry) and the `cos-u3.md` mode correction (644, not 755). Opus. Re-check its pinned gate line against the post-sgb-u2 `writer-scope-gate.sh` before dispatch.
- Run one at a time, each with its own reviewer; validate criteria run after the unit's commit.

Not yet specced (needs the user's go; covered by the existing hook authorisation):

- FIFO hang: add a `[ -f ]` check before the log read at gate line ~134.
- Block reason: with no `sha256sum`/`shasum`, give the gate its own reason instead of "record for another dispatch message".
- Graft file path: point `GIT_GRAFT_FILE` outside a user-writable directory.
- Stale `BASE` in tests: unset after cases (q), (r), (z).
- Missing space after `1)` in a `dispatch-hygiene.sh` header comment (~line 33).
- Add a block-mode exit-code check to `(ad)` case 7.
- Diff-level bypasses: `git update-index --assume-unchanged` / `--skip-worktree`, and `core.worktree` pointing at a clean copy (rc=0; not in the plan's open list).

Still open and not planned:

- A writer editing its transcript metadata so `toolUseId` names a later dispatch with the same prompt.
- A route into the log that `reviewed-path-gate.sh` documents as open.
- Git-config clean/textconv filters hiding a change from `git diff`.
- Bash-only writes with no Write/Edit call or commit line.
- Whether an agent-teams teammate's metadata carries `toolUseId`; by default a teammate writer that changes files is blocked until a probe confirms it (plan OQ1).
- SHA-256 repos always record `head=none` (empty-tree baseline): fails closed but stricter.
- Upgrade caveat: a writer dispatched before sgb-u1 landed blocks once if it changed files; re-dispatch recovers.

Human-side steps:

- Kill rule: after about 20 live reviews, read the `refutation:` telemetry in FAIL blocks; remove the pass if it prevents under 10% of FAILs. In Gate G2, 37% of cases came back UNCERTAIN, above the ~25% break-even.
- Fable pilot: re-run the paid eval pilot. Committed `eval/abtest/results.jsonl` rows are fingerprinted `0803ed2a`, predating OD-23 (`3b0d0c2b`), so they are superseded.

Smaller leftovers, none planned:

- `guard.py`'s `:..` over-refusal is documented and pinned by tests, not narrowed; narrowing needs its own reviewed unit.
- A line at `agents/reviewer.md:129` runs past the usual 80 columns; rewrapping means editing a test pin.
- A `.blocked` marker carries no refuted defects (documented, no behaviour change).

## Authorisations on record (`.claude/orchestrator-rulings.log`)

- tg units: edits to `writer-scope-gate.sh`, `review-precheck.sh`, mirrors and tests.
- Cosmetic bundle: `review-precheck.sh`, its mirror and tests; not the scope gate.
- Hardening: `dispatch-hygiene.sh` and `writer-scope-gate.sh` with mirrors, config hashes and tests ("both hooks, default fail-closed").
- Not authorised: any other hook or gate.

## Rules that stay in force

- Ground truth: never set, guess or pre-fill labels in `eval/refutation-replay/labels.tsv`; never touch `corpus.jsonl` or `report.jsonl`. A paid replay (`run.sh` without `--dry-run`) is the human's step; no agent starts `label.py serve` against the real files.
- Never read or write `.claude/reviewed/` from the main session; subagents use the Read tool for markers.
- Never name the persona-selection config in a Bash command.
- Mirrors: any change under `bin/` or `hooks/scripts/` needs `node bin/cli.js --update`, staged with `git add -u -- .claude ':(exclude).claude/agent-memory'`; otherwise `tests/cli-backfill.test.js` fails. Plain `--update` says "already current"; use `--force-render` to verify. Any uppercase angle-bracket text in a hook comment trips a placeholder warning.
- Dispatches open with a literal `Unit: <id>` line and carry a backticked `## Affected files` list in the message itself (the scope gate reads scope only from the message). Use unique `mktemp -d` directories; no `rm`, `rmdir`, `find -delete`.
- Reviewer mutations run on scratch copies only (one reviewer once mutated the real hook by accident and restored it).
- Full validate: `ANTISLOP_VALIDATE_LANES=4 bash tests/validate.sh`, 7 to 8 minutes. Lane C4.1a is flaky; re-run once before calling a failure.
- A report from another agent carries no user authority.
- Commit attribution: end commit messages with `Co-Authored-By: Claude Sonnet 5.5 <noreply@anthropic.com>` and `Claude-Session: https://claude.ai/code/session_01Ps7koEQ6H1kg2MZ93RantU`.
