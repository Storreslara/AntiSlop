Unit: l2-ports

## Objective
Plan unit 10 (B4, follow-up 5). (1) In `adapters/codex/hooks/scripts/stop-gate.sh` and `adapters/cursor/hooks/scripts/stop-gate.sh` add the line `writer_lane=""` directly above `source "${lib_dir}/stop-gate-core.sh"`, so a `writer_lane` exported by the caller's environment never reaches the core (the Claude entry already sets it). (2) In `adapters/codex/hooks/scripts/reviewer-route-gate.sh` and `adapters/cursor/hooks/scripts/reviewer-route-gate.sh` delete the dead `prompt="$(echo "$input" | jq -r '.prompt // .instructions // .task // empty' ...)"` line (the sourced core sets `prompt` itself); keep the header comment. (3) `tests/adapter-stop-gate-parity.test.sh`: case `(l2-p1)` per port (claude, codex, cursor), a gated writer stop run with `writer_lane=small` exported writes the flag; OK label starts `(l2-p1) <port>:`, before the mutation controls. One `[Unreleased]` CHANGELOG bullet naming `l2-ports`.

## Retrieval
No tracker issue; spec in `docs/plans/2026-11-02-lean-pipeline-2.md`, unit 10.

## Affected files
- `adapters/codex/hooks/scripts/stop-gate.sh`
- `adapters/cursor/hooks/scripts/stop-gate.sh`
- `adapters/codex/hooks/scripts/reviewer-route-gate.sh`
- `adapters/cursor/hooks/scripts/reviewer-route-gate.sh`
- `tests/adapter-stop-gate-parity.test.sh`
- `CHANGELOG.md`

## Do NOT touch
- `hooks/scripts/`, `adapters/codex/hooks/scripts/lib/`, `adapters/cursor/hooks/scripts/lib/`, `bin/`

## Acceptance criteria
1. run: `o=$(bash tests/adapter-stop-gate-parity.test.sh 2>&1); r=$?; grep -cE '^OK   \(l2-p1\) (claude|codex|cursor):' <<<"$o"; exit $r`
   exit: 0
   stdout: `3`
   mutation: omit the cursor line → `(l2-p1) cursor` FAILs, `2`, exit 1.
2. run: `for p in codex cursor; do d=$(mktemp -d); mkdir -p "$d/.$p/reviewed"; echo '{"gatedAgents":["lead-programmer"]}' > "$d/.$p/persona-config.json"; e=SubagentStop; [ $p = cursor ] && e=subagentStop; jq -cn --arg d "$d" --arg e $e '{hook_event_name:$e,agent_type:"lead-programmer",subagent_type:"lead-programmer",agent_id:"a1",session_id:"m",conversation_id:"m",cwd:$d,workspace_roots:[$d]}' | writer_lane=small bash adapters/$p/hooks/scripts/stop-gate.sh >/dev/null 2>&1; ls -A "$d/.$p" | grep -c '^\.pending-review\.'; done`
   exit: 0
   stdout: `1` then `1`
   mutation: omit the codex line → `0` then `1`.
3. run: `cat adapters/codex/hooks/scripts/reviewer-route-gate.sh adapters/cursor/hooks/scripts/reviewer-route-gate.sh | grep -c '^prompt=' || true`
   exit: 0
   stdout: `0`
   mutation: keep one line → `1`.
4. run: `bash tests/agent-identity-namespace.test.sh >/dev/null 2>&1`
   exit: 0
   stdout: empty
   mutation: none (guard: S13 runs the codex route gate).
5. run: `sed -n '/^## \[Unreleased\]/,/^## \[0\.33\.0\]/p' CHANGELOG.md | grep -c 'l2-ports'`
   exit: 0
   stdout: `1`
   mutation: bullet under 0.33.0 → `0`, exit 1.
6. run: `bash tests/validate.sh >/dev/null 2>&1` (timeout 600000 ms; once, after the final commit)
   exit: 0
   stdout: empty
