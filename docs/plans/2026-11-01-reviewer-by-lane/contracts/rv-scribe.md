Unit: rv-scribe

## Objective
Record the reviewer-by-lane decision and vocabulary (plan unit 8, Scribe update hint). `knowledgeWrites` is `apply`; this contract names the only knowledge files it edits.
- New `docs/adr/0045-reviewer-by-lane.md`, `Status: Accepted`: the policy (small lane skips the reviewer and gets `unit-bookkeeping.sh check`; a failed or undecided check moves the unit to medium; agent-teams mode keeps the reviewer), the evidence (43 dispatches, 43 of 43 PASS, $46.6, 37% of Arm B spend; 41 of 41 sampled defects real elsewhere) and the trade-off (plan Risks).
- `CONTEXT.md`: the entry **The Writer/Reviewer split** names the small-lane exception; new entries **unit lane** and **small-lane check**.
- `docs/harness-glossary.md`: new entries **dispatch-lane record** (names `dispatch-lane.log`) and **review-dispatched flag** (names the `review-dispatched:` first line).

## Retrieval
No tracker issue. Spec: `docs/plans/2026-11-01-reviewer-by-lane.md`, unit 8, D1, D2, D7, Risks. This file is the contract of record. Dispatch after rv-flagprose has passed.

## Affected files
- `docs/adr/0045-reviewer-by-lane.md`
- `CONTEXT.md`
- `docs/harness-glossary.md`

## Do NOT touch
- `agents/`, `templates/`, `hooks/`, `bin/`, `CHANGELOG.md`, `docs/adr/0044-retire-escalation-and-bash-scans.md`, `eval/`, `tests/abtest-arms.test.sh`

## Acceptance criteria
1. run: `f=docs/adr/0045-reviewer-by-lane.md; head -1 "$f" | cut -c1-10; t=$(tr -s ' \n' ' ' < "$f"); for s in 'Status: Accepted' '43 of 43' '$46.6' '37%' '41 of 41' 'agent-teams' 'unit-bookkeeping.sh check' 'medium'; do grep -qF -- "$s" <<<"$t" || echo "missing $s"; done`
   exit: 0
   stdout: `# ADR 0045`
   mutation: drop the cost figure → a second line `missing $46.6`.
2. run: `e(){ awk -v t="**$2**" 'index($0,t)==1{f=1;print;next} f&&/^\*\*/{exit} f' "$1" | tr -s ' \n' ' '; }; e CONTEXT.md 'The Writer/Reviewer split' | grep -ciE 'small[- ]lane'; grep -cE '^\*\*(unit lane|small-lane check)\*\*' CONTEXT.md`
   exit: 0
   stdout: `1` then `2`
   mutation: skip the Writer/Reviewer split amendment → first line `0`, exit 1.
3. run: `e(){ awk -v t="**$2**" 'index($0,t)==1{f=1;print;next} f&&/^\*\*/{exit} f' "$1" | tr -s ' \n' ' '; }; e docs/harness-glossary.md 'dispatch-lane record' | grep -c 'dispatch-lane.log'; e docs/harness-glossary.md 'review-dispatched flag' | grep -c 'review-dispatched:'`
   exit: 0
   stdout: `1` then `1`
   mutation: omit the **review-dispatched flag** entry → second line `0`, exit 1.
4. run: `{ node tests/context-glossary-links.test.js && bash tests/glossary-index.test.sh; } >/dev/null 2>&1`
   exit: 0
   stdout: empty
   mutation: add the link `[[unit lanes]]` (no such entry) to the **unit lane** entry → exit 1.
5. run: `bash tests/validate.sh >/dev/null 2>&1` (Bash tool timeout 600000 ms; once, after the final commit)
   exit: 0
   stdout: empty
