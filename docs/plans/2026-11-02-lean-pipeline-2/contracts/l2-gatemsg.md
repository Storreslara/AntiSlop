Unit: l2-gatemsg

## Objective
Plan unit 9. (1) `stop-gate-core.sh`, unrecognized-namespace reviewer message: if `${dot}/bin/unit-bookkeeping.sh` is a file, its last sentence reads "Dispatch this project's own reviewer, or run: bash ${dot_label}/bin/unit-bookkeeping.sh flag defer|skip <reason> (existing flags only)."; else today's text. (2) `reviewer-route-gate-core.sh`: `chmod 644 "$tmp"` between the write and `mv -f`, in the same `&&` chain. Tests, `tests/stop-gate.test.sh`: `(l2-g1)` `other:reviewer` stop, `.claude/bin/unit-bookkeeping.sh` present → stderr names `flag defer|skip`; `(l2-g2)` absent → today's text; `(l2-g3)` a `lane=small` record for another tool_use_id, then the writer's `lane=medium` one → flag; `(l2-g4)` two with the writer's id, `medium` then `small` → flag. `tests/reviewer-route-gate-caller.test.sh`: `(l2-g5)` `.claude` at `chmod 555` (root: `SKIP (l2-g5)`), a reviewer dispatch → flag plain, Stop exits 2; `(l2-g6)` a marked flag has mode 644. One `[Unreleased]` CHANGELOG bullet naming `l2-gatemsg`.

## Retrieval
No tracker issue; spec in `docs/plans/2026-11-02-lean-pipeline-2.md`, unit 9.

## Affected files
- `hooks/scripts/lib/stop-gate-core.sh`
- `hooks/scripts/lib/reviewer-route-gate-core.sh`
- `tests/stop-gate.test.sh`
- `tests/reviewer-route-gate-caller.test.sh`
- `CHANGELOG.md`
- `.claude/` and `adapters/` copies, only through `node bin/cli.js --update --force-render`

## Do NOT touch
- `hooks/scripts/stop-gate.sh`, `hooks/scripts/reviewer-route-gate.sh`, `bin/`

## Acceptance criteria
1. run: `a=$(bash tests/stop-gate.test.sh 2>&1); r1=$?; b=$(bash tests/reviewer-route-gate-caller.test.sh 2>&1); r2=$?; printf '%s\n%s\n' "$a" "$b" | grep -E '^(OK|SKIP) ' | grep -oE '\(l2-g[1-6]\)' | sort -u | wc -l | tr -d ' '; exit $((r1 + r2))`
   exit: 0
   stdout: `6`
   mutation: drop the `chmod 644` → `(l2-g6)` FAILs, exit 1.
2. run: `d=$(mktemp -d); mkdir -p "$d/.claude/bin" "$d/.claude/reviewed"; echo '{}' > "$d/.claude/persona-config.json"; j='{"hook_event_name":"SubagentStop","agent_type":"other:reviewer","agent_id":"r","session_id":"s"}'; for i in 1 2; do echo "$j" | CLAUDE_PROJECT_DIR="$d" bash hooks/scripts/stop-gate.sh 2>&1 | grep -oE 'unit-bookkeeping.sh flag defer.skip|write .defer: <reason>.'; touch "$d/.claude/bin/unit-bookkeeping.sh"; done`
   exit: 0
   stdout: `write 'defer: <reason>'` then `unit-bookkeeping.sh flag defer|skip`
   mutation: keep today's text → line 2 `write 'defer: <reason>'`.
3. run: `for f in stop-gate-core.sh reviewer-route-gate-core.sh; do for p in adapters/codex/ adapters/cursor/ .claude/; do cmp -s hooks/scripts/lib/$f ${p}hooks/scripts/lib/$f && echo same; done; done | grep -c same`
   exit: 0
   stdout: `6`
   mutation: no re-render → `0`, exit 1.
4. run: `sed -n '/^## \[Unreleased\]/,/^## \[0\.33\.0\]/p' CHANGELOG.md | grep -c 'l2-gatemsg'`
   exit: 0
   stdout: `1`
   mutation: bullet under 0.33.0 → `0`, exit 1.
5. run: `bash tests/validate.sh >/dev/null 2>&1` (timeout 600000 ms; once, after the final commit)
   exit: 0
   stdout: empty
