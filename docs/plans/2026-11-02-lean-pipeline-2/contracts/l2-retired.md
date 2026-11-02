Unit: l2-retired

## Objective
Plan unit 13. (1) `hooks/scripts/reviewed-path-gate.sh`: the standing-`.escalated` refusal (about :95) becomes exactly `BLOCKED: this project has a standing .escalated marker and no reviewer persona selected. The marker is left from a version before 0.32.0, which retired escalation (ADR-0044); nothing resolves it any more, so a human deletes it at their own terminal.` Nothing else in the gate changes. (2) `docs/trust-model.md` row 20: keep both script cells; the claim becomes "`hooks/scripts/human-decision-gate.sh` is a stub since 0.32.0 (ADR-0044) that allows every call; it stays registered only for A/B harness parity"; the notes become "It reads stdin and exits 0; it reads no config and writes no file." (3) `tests/reviewed-path-gate.test.sh`: `(l2-r1)` the `.escalated` fixture's refusal has `before 0.32.0` and `own terminal` and no `DECISION`. One `[Unreleased]` CHANGELOG bullet naming `l2-retired`.

## Retrieval
No tracker issue; plan `docs/plans/2026-11-02-lean-pipeline-2.md`, unit 13.

## Affected files
- `hooks/scripts/reviewed-path-gate.sh`
- `docs/trust-model.md`
- `tests/reviewed-path-gate.test.sh`
- `CHANGELOG.md`
- `.claude/` copies, only through `node bin/cli.js --update --force-render`

## Do NOT touch
- `hooks/scripts/human-decision-gate.sh`, `hooks/hooks.json`, `tests/trust-model-bijection.test.js`

## Acceptance criteria
1. run: `o=$(bash tests/reviewed-path-gate.test.sh 2>&1); r=$?; grep -cE '^OK +.*\(l2-r1\)' <<<"$o"; exit $r`
   exit: 0
   stdout: `1`
   mutation: keep today's refusal → `(l2-r1)` FAILs, exit 1.
2. run: `d=$(mktemp -d); mkdir -p $d/.claude/reviewed; echo '{"personaSelection":["explorer"]}' >$d/.claude/persona-config.json; touch $d/.claude/reviewed/u.escalated; jq -cn '{tool_name:"Write",agent_type:"",tool_input:{file_path:".claude/reviewed/u.pass"}}' | CLAUDE_PROJECT_DIR=$d bash hooks/scripts/reviewed-path-gate.sh 2>$d/e; r=$?; echo "rc=$r $(grep -c 'before 0.32.0' $d/e) $(grep -c 'own terminal' $d/e) $(grep -c DECISION $d/e)"`
   exit: 0
   stdout: `rc=2 1 1 0`
   mutation: keep today's refusal → `rc=2 0 1 1`.
3. run: `r=$(grep '^| 20 |' docs/trust-model.md); echo "$(grep -c 'stub since 0.32.0 (ADR-0044)' <<<"$r") $(grep -c 'A/B harness parity' <<<"$r") $(grep -c DECISION <<<"$r")"`
   exit: 0
   stdout: `1 1 0`
   mutation: keep today's row 20 → `0 0 1`.
4. run: `node tests/trust-model-bijection.test.js >/dev/null`
   exit: 0
   stdout: empty
   mutation: row 20 checked-by `self-reported` → exit 1.
5. run: `sed -n '/^## \[Unreleased\]/,/^## \[0\.33\.0\]/p' CHANGELOG.md | grep -c 'l2-retired'`
   exit: 0
   stdout: `1`
   mutation: bullet under 0.33.0 → `0`, exit 1.
6. run: `node bin/cli.js --update --force-render >/dev/null && git diff --quiet -- .claude adapters ':!.claude/agent-memory'`
   exit: 0
   stdout: empty
   mutation: leave `.claude/hooks/scripts/reviewed-path-gate.sh` stale → exit 1.
7. run: `bash tests/validate.sh >/dev/null 2>&1` (Bash tool timeout 600000 ms; once, after the final commit)
   exit: 0
   stdout: empty
