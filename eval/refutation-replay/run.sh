#!/usr/bin/env bash
# Refutation replay runner (rfp-u2, Gate G2). For each corpus group (at most 3 defects from one past FAIL
# block), check out the reviewed commit in a scratch worktree, build the brief with this checkout's
# bin/refutation-brief.sh, and run one headless `claude -p` on sonnet with read-only tools and a 10-turn
# cap. Each answer line `D<n>: VERDICT — ... — artifact: ...` becomes one report row.
# Usage: eval/refutation-replay/run.sh [--dry-run] [--corpus <file>] [--out <file>] [--repo <dir>]
# --dry-run prints one `group=<id> cmd: ...` line per group and runs nothing: no claude, no worktree.
# A real run spends API budget (each run capped by --max-budget-usd 1). The human runs it (Gate G2).
set -uo pipefail
here="$(cd "$(dirname "$0")" && pwd)"
repo="$(cd "$here/../.." && pwd)"
corpus="$here/corpus.jsonl"
out="$here/report.jsonl"
dry=0
while [ $# -gt 0 ]; do
  case "$1" in
    --dry-run) dry=1; shift ;;
    --corpus) corpus="$2"; shift 2 ;;
    --out) out="$2"; shift 2 ;;
    --repo) repo="$(cd "$2" && pwd)"; shift 2 ;;
    *) echo "run.sh: unknown argument $1" >&2; exit 2 ;;
  esac
done
[ -f "$corpus" ] || { echo "run.sh: no corpus at $corpus" >&2; exit 2; }
brief="$here/../../bin/refutation-brief.sh"
[ -f "$brief" ] || { echo "run.sh: missing bin/refutation-brief.sh (rfp-u1)" >&2; exit 2; }
brief="$(cd "$(dirname "$brief")" && pwd)/refutation-brief.sh"

CLAUDE_FLAGS=(--model sonnet --max-turns 10 --output-format json --no-session-persistence
  --max-budget-usd 1 --allowedTools Read Grep Glob "Bash(git *)" "Bash(grep *)")

groups="$(python3 - "$corpus" <<'PY'
import json, sys, collections
g = collections.OrderedDict()
for l in open(sys.argv[1]):
    if l.strip():
        r = json.loads(l)
        g.setdefault(r['group'], []).append(r)
for gid, rows in g.items():
    print('\t'.join([gid, rows[0]['reviewed'], rows[0]['baseline'], json.dumps([r['dline'] for r in rows]), json.dumps([r['id'] for r in rows])]))
PY
)" || { echo "run.sh: unreadable corpus" >&2; exit 2; }

work="$(mktemp -d)"
trap 'git -C "$repo" worktree prune >/dev/null 2>&1; rm -rf "$work"' EXIT
[ "$dry" = 1 ] || : > "$out"
n=0
while IFS=$'\t' read -r gid reviewed baseline dlines ids; do
  [ -n "$gid" ] || continue
  n=$((n + 1))
  if [ "$dry" = 1 ]; then
    echo "group=$gid cmd: claude -p <brief> ${CLAUDE_FLAGS[*]}"
    continue
  fi
  wt="$work/$n"
  git -C "$repo" worktree add -q --detach "$wt" "$reviewed" || { echo "run.sh: worktree failed for $gid" >&2; continue; }
  prompt="$(cd "$wt" && python3 -c 'import json,sys; print("\n".join(json.loads(sys.argv[1])))' "$dlines" | bash "$brief" "$baseline")" \
    || { echo "run.sh: brief refused for $gid" >&2; git -C "$repo" worktree remove --force "$wt"; continue; }
  ( cd "$wt" && claude -p "$prompt" "${CLAUDE_FLAGS[@]}" ) > "$work/$n.json" 2> "$work/$n.err"
  python3 - "$work/$n.json" "$ids" >> "$out" <<'PY'
import json, re, sys
try:
    res = json.load(open(sys.argv[1]))
except Exception:
    res = {}
text = str(res.get('result') or '')
ids = json.loads(sys.argv[2])
ans = {}
for line in text.splitlines():
    m = re.match(r'^\s*D([1-3]):\s*(REFUTED|CONFIRMED|UNCERTAIN)\b(.*)$', line)
    if m and m.group(1) not in ans:
        art = re.search(r'artifact:\s*(.*)$', m.group(3))
        ans[m.group(1)] = (m.group(2), art.group(1).strip() if art else '')
for i, rid in enumerate(ids, 1):
    v, art = ans.get(str(i), ('NONE', ''))
    print(json.dumps({'id': rid, 'answer': v, 'artifact': art, 'num_turns': res.get('num_turns', 0),
                      'cost_usd': res.get('total_cost_usd', 0)}, sort_keys=True))
PY
  git -C "$repo" worktree remove --force "$wt" >/dev/null 2>&1
done <<< "$groups"
echo "run.sh: groups=$n dry-run=$dry out=$( [ "$dry" = 1 ] && echo none || echo "$out")"
