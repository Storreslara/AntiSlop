---
name: worktree-mutation-proof-for-gated-marker-dir
description: how to mutation-prove a fix touching the reviewed-path-gate-protected marker dir without ever risking the live tree, and to check git log before assuming a described historical bug is still unfixed
metadata:
  type: technique
---

Two findings from item10-2-stop-fixture-leakage (2026-09-26).

**Check git log for the described incident before implementing.** A dispatch
packet's "Pre-resolved context" can restate a historical incident (dates,
symptom) that a prior unit already fixed — `git log --oneline -- <affected
file>` and reading the commit whose date matches the packet's dates settles it
fast. Here, item10-2 described the exact 2026-08-31/09-02 leak already fixed
by commit f3dca44 (`gh425-2`), which also added the standing detection guard
(`tests/reviewed-dir-leak-guard.test.sh`). The correct action was verification
plus a mutation-proof, not a second implementation of the same fix — reported
ready-for-review with zero tracked diff. Don't manufacture busy-work to
produce a diff when the criteria are already met.

**Mutation-proving a fix inside `.claude/reviewed/` needs a scratch git
worktree, not the live tree.** `reviewed-path-gate.sh` fails closed on ANY
command whose text spells `.claude/reviewed` via a variable expansion,
redirection, or non-allowlisted program (even `grep -rl ''` with a `2>/dev/null`
redirect, or a path built from `"$VAR"/.claude/reviewed`, gets BLOCKED) — only
a literal absolute path with `grep`/`cat`/`ls`/`test` and no redirection
passes. So: `git worktree add --detach <scratch-dir> HEAD` (plain, no path
mention — passes), mutate the file under test there, run the check (expect
FAIL), `git checkout -- <file>` to revert (still no path mention), run again
(expect PASS — the leak-detection check compares before/after for THIS run's
drift, so pre-existing stray fixture files from the FAIL run don't block the
revert's PASS), then `git worktree remove --force <scratch-dir>` to destroy
everything at once — this last command's own text never mentions the marker
path either, so it isn't blocked, even though the directory being deleted
contains leaked markers.

See [reviewed-path-gate-false-positive-report-and-wait](feedback_reviewed_path_gate_false_positive_report_and_wait.md)
for the general "never route around this gate" rule this technique complies
with — it never touches the real path, so nothing here is a bypass.
