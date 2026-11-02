Unit: l2-sg2

## Objective
Plan unit 10b (after l2-h4, l2-sg1). `dispatch-hygiene.sh`: the gatedAgents match no longer touches `.claude/reviewed/.writer-dispatch-stamp`; it sets `sg_stamp_due=1`. An `EXIT` trap installed before that match touches the stamp (same guard) only when the exit status is 0 and `sg_stamp_due` is set, and keeps that status. Mode off, override, replay, warn and no check fired touch it; exit 2 or a crash leaves it (fail closed). Update header item 0a. Tests, stamp pre-set to 2026-01-01: `(l2-d1)` a lead-programmer dispatch blocked by H4 → rc 2, stamp unchanged; `(l2-d2)` an allowed one → touched; `(l2-d3)` mode off and an `override: <reason>` sentinel, each with a blocking prompt → rc 0, touched; `(l2-d4)` a `.pass` at 2026-01-02, then a blocked dispatch, then the writer's SubagentStop through `hooks/scripts/stop-gate.sh` → rc 2 naming the marker; `(l2-d5)` an explorer dispatch never touches it. T50 keeps passing. One `[Unreleased]` CHANGELOG bullet naming `l2-sg2`.

## Retrieval
No tracker issue; spec in `docs/plans/2026-11-02-lean-pipeline-2.md`, unit 10b.

## Affected files
- `hooks/scripts/dispatch-hygiene.sh`
- `tests/dispatch-hygiene.test.sh`
- `CHANGELOG.md`
- `.claude/` copies, only through `node bin/cli.js --update --force-render`

## Do NOT touch
- `hooks/scripts/lib/`, `hooks/scripts/stop-gate.sh`, `bin/`

## Acceptance criteria
1. run: `o=$(bash tests/dispatch-hygiene.test.sh 2>&1); r=$?; grep '^OK ' <<<"$o" | grep -oE '\(l2-d[1-5]\)' | sort -u | wc -l | tr -d ' '; exit $r`
   exit: 0
   stdout: `5`
   mutation: touch at the match again → `(l2-d1)`, `(l2-d4)` FAIL, exit 1.
2. run: `d=$(mktemp -d); c=$d/.claude; mkdir -p $c/reviewed; echo '{}' > $c/persona-config.json; touch -d 2026-01-01 $c/reviewed/.writer-dispatch-stamp; echo P > $c/reviewed/u.pass; touch -d 2026-01-02 $c/reviewed/u.pass; jq -cn '{tool_name:"Agent",tool_input:{subagent_type:"lead-programmer",prompt:"do it"}}' | CLAUDE_PROJECT_DIR=$d bash hooks/scripts/dispatch-hygiene.sh >/dev/null 2>&1; h=$?; echo '{"hook_event_name":"SubagentStop","agent_type":"lead-programmer","agent_id":"lp-1"}' | CLAUDE_PROJECT_DIR=$d bash hooks/scripts/stop-gate.sh 2>/dev/null; s=$?; echo "hyg=$h stamp=$(find $c/reviewed/.writer-dispatch-stamp -newermt 2026-01-02 | wc -l) stop=$s"`
   exit: 0
   stdout: `hyg=2 stamp=0 stop=2`
   mutation: touch at the match again → `hyg=2 stamp=1 stop=0`.
3. run: `sed -n '/^## \[Unreleased\]/,/^## \[0\.33\.0\]/p' CHANGELOG.md | grep -c 'l2-sg2'`
   exit: 0
   stdout: `1`
   mutation: bullet under 0.33.0 → `0`, exit 1.
4. run: `node bin/cli.js --update --force-render >/dev/null && git diff --quiet -- .claude adapters ':!.claude/agent-memory'`
   exit: 0
   stdout: empty
   mutation: leave `.claude/hooks/scripts/dispatch-hygiene.sh` stale → exit 1.
5. run: `bash tests/validate.sh >/dev/null 2>&1` (timeout 600000 ms; once, after the final commit)
   exit: 0
   stdout: empty
