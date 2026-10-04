# Auto-mode double "Interrupted" line in the Bash-ask post-decline pane

**Post-hoc analysis, not script output.** Nothing here was run live. It
reads transcripts already on disk, written by earlier runs of
`scripts/probe-bash-ask.sh` (records in
`docs/experiments/2026-10-01-probe-bash-ask.md`, which this note does not edit).

## Question

In the auto-mode post-decline pane of the Bash-ask record, the line
`  ⎿  Interrupted · What should Claude do instead?` appears twice in two of
three records. Was the decline key sent twice, or was there a second tool call?

## Finding: one keystroke, one tool call, one decline

- The script sends the decline key once per mode: `scripts/probe-bash-ask.sh:71`,
  `tm send-keys -t "$s" 2`. That line is identical in every committed version
  of the script from 8d13b90 to 6d30470.
- The probe sessions' transcripts are in
  `~/.claude/projects/-tmp-bash-ask-probe/*.jsonl`. Every declined session
  has exactly one Bash `tool_use` and exactly one rejected `tool_result`
  (`toolUseResult: "User rejected tool use"`). No declined session has a
  second call.
- What differs is the interrupt marker the session writes after the
  rejection. Declined auto sessions wrote one of two texts:
  - `[Request interrupted by user for tool use]`
  - `[Request interrupted by user]` (the generic marker)
  Every declined session in every other mode wrote `... for tool use]`.

Auto-mode sessions (mode taken from each transcript's `permission-mode` line;
timestamps UTC, the record timestamps are local, UTC-5):

| Record | Run (UTC) | CLI | Auto marker in transcript | Interrupted lines in auto pane |
|---|---|---|---|---|
| cbb918e | 2026-10-03T18:58 | 2.1.288 | `... for tool use]` | 1 |
| 229138e | 2026-10-03T20:53 | 2.1.288 | `[Request interrupted by user]` | 2 |
| 7e04acd | 2026-10-04T00:45 | 2.1.289 | `[Request interrupted by user]` | 2 |

The marker and the pane agree in 3 of 3 records. One earlier auto session
(2026-10-02T05:02, 2.1.287, not part of a committed record) also wrote
`... for tool use]`.

**The CLI version does not explain it.** The cbb918e and 229138e auto runs
were both 2.1.288 and differ; 7e04acd was 2.1.289.

## Not determined

- Why Claude Code wrote the generic marker in the 229138e and 7e04acd auto
  runs and the `for tool use` marker in the cbb918e one. That choice is
  inside Claude Code and cannot be derived offline.
- Whether the second rendered `Interrupted` line in the pane is that
  generic marker. The 3-of-3 correlation makes it likely; it is not shown.

## Grading is unaffected

The Decline row is graded from the filesystem decline block
(`out.txt: absent` plus the `ls -Aq` listing), not from the pane. See
glossary "decline block". The pane is context only.

## Command used

Per transcript: mode, version, Bash `tool_use` count, rejected-result count,
and interrupt markers.

```
jq -r '.permissionMode // empty' F | head -1
jq -r 'select(.version) | .version' F | head -1
jq -c 'select(.type=="assistant") | .message.content[]? | select(.type=="tool_use" and .name=="Bash") | .id' F | wc -l
jq -r 'select(.toolUseResult=="User rejected tool use") | .timestamp' F | wc -l
jq -r 'select(.type=="user") | .message.content | if type=="array" then .[]? | select(.type=="text") | .text else . end | select(startswith("[Request interrupted"))' F
```

The transcripts are machine-local and may be pruned. This note quotes their
results and does not depend on them existing later. Source of the original
measurement: `docs/plans/2026-10-04-escalation-leftovers.md`, Item 2.

## Operator step (optional, not part of any unit)

A fresh live re-run of `scripts/probe-bash-ask.sh` would show whether auto
still emits the generic marker, and whether the pane still shows two lines.
