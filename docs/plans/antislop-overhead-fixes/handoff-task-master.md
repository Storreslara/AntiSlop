# task-master handoff: antislop-overhead-fixes slice

Spec `docs/plans/antislop-overhead-fixes/spec.md` (finalized 2026-10-19). Label `plan/antislop-overhead-fixes`. Unit ids `aof-uN`. Contract files `docs/plans/antislop-overhead-fixes/contracts/<unit-id>.md`, written by spec-master (commits 392c1b8d, e1289654) and taken unchanged. All units `Suggested model: haiku` (no FAIL records exist for any aof unit). Commit trailer for unit commits: `Co-Authored-By: Claude Sonnet 5.5 <noreply@anthropic.com>`.

Retrieval line: GitHub issues (repo Storreslara/AntiSlop): fetch with `gh issue view <N> --repo Storreslara/AntiSlop`; list with `gh issue list --repo Storreslara/AntiSlop --label plan/antislop-overhead-fixes`.

## Done (issue filed, contract committed)

| unit | issue | contract | stamped | depends on |
|---|---|---|---|---|
| aof-u5 stream.py token count over the whole run, OD-22 | #628 | contracts/aof-u5.md | no | none |
| aof-u6 uniform policy enforced in the plugin copy, OD-23 | #629 | contracts/aof-u6.md | no | aof-u5 (#628) |
| aof-u1 ladder helpers installed into .claude/bin | #630 | contracts/aof-u1.md | yes | none |
| aof-u2 Stop allowed while a reviewer is in flight | #631 | contracts/aof-u2.md | yes | aof-u1 (#630) |
| aof-u3 binding unit scope on lead-programmer dispatches | #632 | contracts/aof-u3.md | yes | aof-u2 (#631) |
| aof-u4 knowledge proposals, scribe once per plan | #633 | contracts/aof-u4.md | yes | aof-u3 (#632) |

Dispatch order, one unit at a time: aof-u5, aof-u6, aof-u1, aof-u2, aof-u3, aof-u4. Eval chain u5 -> u6; product chain u1 -> u2 -> u3 -> u4 (serial: shared `agents/orchestrator.md` and version bump).

## Decisions not in a contract

- Each issue carries a close-only `## Dispatch contract (scribe)` block (no knowledge edits; ISSUE number and `<PASS-VERDICT-LINE>` as in earlier units), because the spec assigns knowledge updates to the single end-of-plan scribe run.
- Contract guard (`node bin/contract-guard.js`) scores: u1 1/7, u2 1/7, u3 1/7, u4 2/7, u5 2/7, u6 2/7, all pin `sonnet`. Contracts were not edited to raise the score; the orchestrator pins the ladder to sonnet.
- Each contract's `## Retrieval` still says "Fast path, no tracker issue"; the issues above now exist and are the retrieval target.
