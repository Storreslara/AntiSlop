# Refutation replay (Gate G)

This is the offline safety check for the reviewer's refutation pass (`docs/plans/2026-10-27-refutation-pass.md`,
"Safety"). The question it answers: shown a **real** past defect, how often does the refutation brief
(`bin/refutation-brief.sh`), run on sonnet, wrongly answer REFUTED? The reviewer instructions that enable the
pass (unit rfp-u3) carry `score.py --gate` on the committed report as an acceptance criterion. They cannot
ship until this check passes.

## Files

| file | written by | what it holds |
|---|---|---|
| `build-corpus.py` | rfp-u2 | builds, checks and prints the label checklist for the corpus |
| `corpus.jsonl` | `build-corpus.py`, committed | one row per past judgment defect: unit, FAIL timestamp, reviewed and baseline commits, the `D<n>:` line, the fix commit |
| `labels.tsv` | the builder writes `unknown`; **a human** sets `real` or `bogus` | ground truth |
| `run.sh` | rfp-u2, rfp-u2b | one headless `claude -p` per corpus group, in a fresh clone holding the history up to the reviewed commit only |
| `guard.py` | rfp-u2b | the PreToolUse hook of every run: Read, Grep and Glob inside the clone, Bash only as `git show`, `git diff` and `git log` |
| `report.jsonl` | `run.sh`, committed by the human | one row per defect: the answer, the artifact, the turns, the cost |
| `score.py` | rfp-u2 | prints `replay-gate: <pass\|fail\|insufficient> …`; `--gate` turns the result into the exit code |

## Gate G (manual: the human operator runs it)

1. `python3 eval/refutation-replay/build-corpus.py --labels` prints one checklist entry per row: the claim,
   then the fix commit's subject. For each row, set `real` or `bogus` in `labels.tsv`, then commit it.
   `--check` must then print `unlabeled=0`. An agent must not set the labels: they are the ground truth
   the agent's own kind is graded against.
2. `bash eval/refutation-replay/run.sh` makes one sonnet run per group, each capped by
   `--max-budget-usd 1` and `--max-turns 10`. Check the plan first with `--dry-run`. A group whose clone
   or brief fails gets one `NONE` row per defect, which counts as unanswered. Exit 3 means a run used
   tools but the guard logged no call: the guard hook is not wired, so fix that and re-run from the
   start. Commit `report.jsonl`.
3. Run `python3 eval/refutation-replay/score.py eval/refutation-replay/report.jsonl --gate`. The result
   means:
   - `pass` (exit 0): dispatch rfp-u3.
   - `fail` (exit 1) or `insufficient` (exit 2): do not dispatch rfp-u3. Return the report to spec-master.

## Thresholds and what they mean

- **pass** needs all four of the following:
  - at least 30 defects labelled `real` were replayed;
  - at most 1 of them was answered REFUTED with an artifact (a **miss**);
  - at most 20% of all rows got no answer line;
  - no run exceeded 10 turns.
- One miss in 30 bounds the brief's true raw miss rate at about 17% (95% upper bound, exact binomial).
  Zero in 30 bounds it at about 10%.
- The live pass adds the reviewer's own re-check of every artifact, which this replay does not model. The
  measured rate is therefore an upper bound on the live one.

## Known fidelity limits

- The replay is not the `explorer` persona. It sends the same brief, but runs headless without the persona
  body or its graph MCP, and loads no user, project or plugin settings (`--setting-sources local`). Its
  tools are Read, Grep and Glob inside the clone and Bash only as `git show`, `git diff` and `git log`.
  `guard.py` refuses everything else, including `git -c`, shell operators and paths outside the clone.
- Each run happens in a fresh repository fetched up to the reviewed commit. The later fix commit, other
  refs, `labels.tsv` and the FAIL records are not in it, and the guard refuses paths outside it.
- A claim is whitespace-collapsed and cut at 300 characters when the corpus is built; its cited
  `<path>:<line>` is kept whole. The live reviewer writes its own defect lines, with no cut.
- The corpus is per defect. A judgment defect from a FAIL block that also had a mechanical ground still
  counts. The corpus measures how real defects are treated, not how often the pass would run.
- "Real" starts as a proxy: a `(<unit>)` commit after the FAIL touched the cited file, and the unit later
  passed. The human label replaces the proxy. A bogus defect wrongly kept as `real` can only make the gate
  stricter.
- The corpus is built from this clone's `.claude/reviewed/`, which is gitignored per-clone state. The
  committed `corpus.jsonl` is the record. `--check` re-validates it against git alone.
