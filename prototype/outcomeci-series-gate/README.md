# OutcomeCI series-gate trial runbook

Local, read-only trial of `oci-series-gate.sh` around `oci workflow run`. The workflow has no `secrets`, `apis`, `can` or `policy`, so no broker call is made and no provider is contacted. Run it in the order below.

Never pass `--cloud` to `oci`. This trial is local only.

Before any live run, from the repo root: `bash prototype/outcomeci-series-gate/tests/run-all.sh` must exit 0 and end with `failed=0`. It runs every prototype suite plus `mutation-proof.sh`; `tests/validate.sh` does not run them.

1. Install: `pipx install outcomeci-cli==0.50.1`. The CLI pins `outcomeci-connectors>=0.8,<0.9`, so the trial runs connectors 0.8.x, not 0.10.0 (PC1).
2. Copy the workflow outside this repo, into a directory with no `.claude/` in it (A2):
   `export OCI_TRIAL_DIR=$(mktemp -d) && cp -a prototype/outcomeci-series-gate/workflow/. "$OCI_TRIAL_DIR"/`
3. Before snapshot, from the repo root:
   `bash prototype/outcomeci-series-gate/state-snapshot.sh . > "$OCI_TRIAL_DIR/before.txt"`
4. Run through the wrapper. Pick `<unit>` with a valid PASS marker and pass its cited commit as `<sha>` (e.g. `poc-1` cites `3ddfa45`):
   `bash prototype/outcomeci-series-gate/oci-series-gate.sh --unit <unit> --sha <sha> -- workflow run --dir "$OCI_TRIAL_DIR" --auto-continue 2> "$OCI_TRIAL_DIR/gate.log"`
5. After snapshot, diff, and journal check:
   - `bash prototype/outcomeci-series-gate/state-snapshot.sh . > "$OCI_TRIAL_DIR/after.txt"`
   - `diff "$OCI_TRIAL_DIR/before.txt" "$OCI_TRIAL_DIR/after.txt"` must exit 0; any diff goes to the human.
   - `bash prototype/outcomeci-series-gate/check-journal.sh --allow-absent "$OCI_TRIAL_DIR" <run-id>`. With zero APIs the journal is absent or `calls=0`, so this check is vacuous; the trial report must say so.
6. Limits:
   - At most 3 live runs (A4); each uses the `CLAUDE_CODE_OAUTH_TOKEN` subscription.
   - The wrapper considers only `.pass` markers (A3). A unit with only `.escalated` or `.directed`, or none, is refused. Under `reviewGating.mode=off` no markers are written, so every unit is refused.
   - Model: the workflow uses `claude-haiku-4-5`. If run 1 fails on the model, re-run with `--model claude-sonnet-5-5` after `workflow run`; that re-run counts against the 3-run cap.
   - Negative check: this must print `rc=65` and leave `oci` unexecuted (no new directory under `$OCI_TRIAL_DIR/.outcomeci/outcomes/`):
     `bash prototype/outcomeci-series-gate/oci-series-gate.sh --unit no-such-unit -- workflow run --dir "$OCI_TRIAL_DIR"; echo rc=$?`
7. Operator checks for the live run (not repo CI):
   - AC4.5, token spend. The `usage.json` path is UNVERIFIED until the first live run; the second lookup is the fallback. The cap is a placeholder to set after run 1. Must exit 0:
     `f=$(ls -d "$OCI_TRIAL_DIR"/.outcomeci/outcomes/*/transcripts/summarize/usage.json 2>/dev/null | head -1); [ -n "$f" ] || f=$(find "$OCI_TRIAL_DIR/.outcomeci" -name usage.json | head -1); bash prototype/outcomeci-series-gate/token-usage.sh --cap "${OCI_TOKEN_CAP:-60000}" "$f"`
   - AC4.6, static guard, must print `0`:
     `grep -cE '^[[:space:]]+(converse|await):|fallback:' prototype/outcomeci-series-gate/workflow/outcome.yml`
8. Licensing (R4): OutcomeCI declares Apache-2.0 but ships no LICENSE file, and the connectors license is unconfirmed. Never copy OutcomeCI code into this MIT repo, `prototype/` included. A fork lives outside the repo; before redistributing one, add the Apache-2.0 text, keep any NOTICE, and mark modified files.

If `oci validate` rejects the workflow schema, stop and report; that routes back to spec-master (D3).
