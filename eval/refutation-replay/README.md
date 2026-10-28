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
| `label.py` | rfp-u2c | the Gate G1 labeling server: a click on a card writes that one line of `labels.tsv` |
| `label_page.html` | rfp-u2c | the labeling page template, filled in memory by `label.py` |
| `corpus.jsonl` | `build-corpus.py`, committed | one row per past judgment defect: unit, FAIL timestamp, reviewed and baseline commits, the `D<n>:` line, the fix commit |
| `labels.tsv` | the builder writes `unknown`; **a human** sets `real` or `bogus` with `label.py serve` (or by hand) | ground truth |
| `run.sh` | rfp-u2, rfp-u2b | one headless `claude -p` per corpus group, in a fresh clone holding the history up to the reviewed commit only |
| `guard.py` | rfp-u2b | the PreToolUse hook of every run: Read, Grep and Glob inside the clone, Bash only as `git show`, `git diff` and `git log` |
| `report.jsonl` | `run.sh`, committed by the human | one row per defect: the answer, the artifact, the turns, the cost, and the CLI result's `subtype` and `is_error` |
| `score.py` | rfp-u2 | prints `replay-gate: <pass\|fail\|insufficient> …`; `--gate` turns the result into the exit code |

## Gate G (manual: the human operator runs it)

1. `python3 eval/refutation-replay/label.py serve` starts the labeling server (add `--no-open` on a headless
   machine, `--port <n>` for a fixed port: `label.py serve --no-open --port <n>`).
   - It prints `label: http://127.0.0.1:<port>/?t=<token>` and opens that URL in a browser when it can.
   - Read each card's evidence and click real or bogus (unknown undoes). The keyboard only navigates (j and k);
     no key labels.
   - Each click writes that one line of `eval/refutation-replay/labels.tsv` in your working tree at once.
     There is no export step.
   - Ctrl-C stops the server.
   - Review `git diff eval/refutation-replay/labels.tsv`. `build-corpus.py --check` must print `unlabeled=0`.
     Then commit `labels.tsv` yourself.
   - `build-corpus.py --labels` remains the plain-text checklist.
   - An agent must not set the labels: they are the ground truth the agent's own kind is graded against.
2. `bash eval/refutation-replay/run.sh` makes one sonnet run per group, each capped by
   `--max-budget-usd 1` and `--max-turns 10`. Check the plan first with `--dry-run`. A group whose clone
   or brief fails gets one `NONE` row per defect, which counts as unanswered. Exit 3 means a run used
   tools but the guard logged no call: the guard hook is not wired, so fix that and re-run from the
   start. `run.sh` parses its whole body before it runs, so an edit to the file during a replay does not
   change that replay; still, do not edit it while one runs. Commit `report.jsonl`.
3. Run `python3 eval/refutation-replay/score.py eval/refutation-replay/report.jsonl --gate`. The result
   means:
   - `pass` (exit 0): dispatch rfp-u3.
   - `fail` (exit 1) or `insufficient` (exit 2): do not dispatch rfp-u3. Return the report to spec-master.

## Labeling server: what it does and does not protect

- It binds to 127.0.0.1 only.
- A foreign `Host` or `Origin` is refused, which stops DNS rebinding.
- A per-launch token sits in the URL and is sent on every write.
- Each click is one validated, atomic, version-checked line: the file is never re-serialized.
- A local write log, `<git dir>/refutation-label-writes.log`, records every POST (`.git/` in a normal checkout, `.git/worktrees/<name>/` in a linked worktree). It is never committed.
- It does **not** stop a local process that can read the URL or the token, or that edits the file directly,
  an agent included. That control is process-level, and the human's own commit of `labels.tsv` is the record.

## Thresholds and what they mean

- **pass** needs all five of the following:
  - at least 30 defects labelled `real` were replayed;
  - at most 1 of them was answered REFUTED with an artifact (a **miss**);
  - at most 20% of all rows got no answer line;
  - no run exceeded 10 turns (`max-turns`, the CLI's `num_turns`: on a finished run, 1 plus its tool calls);
  - no run was cut off at the turn cap (`capped=0`: no row's `subtype` is `error_max_turns`).
- A run cut off at the cap also reports `num_turns` 11, so the turn rule fails it too; `capped` names the
  cause. A report written before rfp-u2f has no `subtype`, so it always shows `capped=0`.
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
- A claim is the whole defect item: its bullet line plus every indented line after it, across blank lines,
  up to the next bullet or unindented line, whitespace-collapsed and cut at 8000 characters. No committed
  claim reaches the cut. Its cited `<path>:<line>` is kept whole. The live reviewer writes its own defect
  lines, with no cut. Which defects are kept still depends on the bullet line alone.
- `build-corpus.py --refresh-claims` rewrites the claims of the committed corpus from the FAIL records
  without selecting again, so the ids, the rows' other fields and `labels.tsv` stay as they are. A rebuild
  would select again from today's FAIL records and change the ids.
- The corpus is per defect. A judgment defect from a FAIL block that also had a mechanical ground still
  counts. The corpus measures how real defects are treated, not how often the pass would run.
- "Real" starts as a proxy: a `(<unit>)` commit after the FAIL touched the cited file, and the unit later
  passed. The human label replaces the proxy. A bogus defect wrongly kept as `real` can only make the gate
  stricter.
- The corpus is built from this clone's `.claude/reviewed/`, which is gitignored per-clone state. The
  committed `corpus.jsonl` is the record. `--check` re-validates it against git alone.
