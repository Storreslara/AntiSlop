# task-master memory techniques — index lines moved from MEMORY.md on 2026-10-15; topic files unchanged
- [GitHub native issue dependencies](reference_github_native_issue_dependencies.md) — real blocking edges are available here; `gh api -F issue_id=<database id>`, never `-f`, never the issue number.
- [Generate and replay contracts](technique_generate_and_replay_contracts.md) — tools/cg.py builds contracts from tested scratch files, tools/replay.py replays edits, criteria and skip-edit mutations
- [Fix contract over the budget: split rounds](technique_fix_contract_over_budget_split_rounds.md) — fix1..fixN under one Unit id, tools/dedit.py diffs to edits, round-specific commit selectors
