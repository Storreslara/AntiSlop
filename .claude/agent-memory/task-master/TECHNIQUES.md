# task-master memory techniques — index lines moved from MEMORY.md on 2026-10-15; topic files unchanged
- [GitHub native issue dependencies](reference_github_native_issue_dependencies.md) — real blocking edges are available here; `gh api -F issue_id=<database id>`, never `-f`, never the issue number.
- [Generate and replay contracts](technique_generate_and_replay_contracts.md) — tools/cg.py builds contracts from tested scratch files, tools/replay.py replays edits, criteria and skip-edit mutations
- [Fix contract over the budget: split rounds](technique_fix_contract_over_budget_split_rounds.md) — fix1..fixN under one Unit id, tools/dedit.py diffs to edits, round-specific commit selectors

## Replay and matrix mechanics (2026-10-17)
- Parallel `replay.py` runs collide on the shared `.git/config` lock; run them one after another or retry on "could not lock". A replay uses a linked worktree, so a criterion that runs `tests/validate-lanes.sh` exits 2 there: verify it in a `git clone --no-hardlinks` with `applyto.py` instead.
- `pkill -f <name>` kills your own shell when the name is in the command line; write the pattern as `mu[t]05d`.
- `python3 -I` ignores `PYTHONDONTWRITEBYTECODE`; set `sys.dont_write_bytecode = True` before an importlib load in a test.
- A bash heredoc or Bash command text is rewritten when it holds `\uXXXX`: build files from a placeholder (`@u2219`) in Python, or Write them, and grep for non-ASCII afterwards.
- A contract over 30000 bytes is split into units (u05d/u05e, u12c); an amendment to a not-yet-dispatched contract that is near the cap becomes its own unit blocked by it.
- Mutation matrix: sliced copies of the finished tree (`cp -r` of a worktree works) run in parallel; list equivalent edits as unclaimed instead of leaving a survivor.

## Follow-up round mechanics (2026-10-17, abt u08b-u17b)
- `tools/chain.py REPO BASE CONTRACT...` applies several contracts in order (commits included) in one worktree; `git branch -f <name> <sha>` on it gives a replay BASE that already holds earlier units. `tools/anchors.py` counts every literal anchor at its turn; `tools/applyall.py` leaves a finished worktree for hand-run proof mutations.
- A grep false-fail check (comment filter) is fixed with a tokenizer script in the checks dir, not a longer grep pipe; pin proof-script output with a `.expected` file and a gate test.
- A review's suggested anchor can create a false failure (table-row-only README route): test the regex on real forms (table row, curl example, prose, test file name) before accepting it.
- Ordering trap: u12 put the config dir inside `.runs/`, which u01b's arms refuse; u12c must follow u01b with nothing between.
