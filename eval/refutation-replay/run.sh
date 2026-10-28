#!/usr/bin/env bash
# Refutation replay runner (rfp-u2, Gate G2; isolation rfp-u2b). For each corpus group (at most 3 defects
# from one past FAIL block), fetch the reviewed commit into a fresh repository that holds only the history
# up to that commit (no other refs, no remote, no FETCH_HEAD, no alternates), build the brief there with
# this checkout's bin/refutation-brief.sh, and run one headless `claude -p` on sonnet with a 10-turn cap.
# The run loads no user, project or plugin settings (--setting-sources local; the clone has no
# .claude/settings.local.json) and only guard.py as a PreToolUse hook: Read, Grep and Glob inside the
# clone, Bash only as `git show`, `git diff` or `git log`. Each answer line
# `D<n>: VERDICT — ... — artifact: ...` becomes one report row. A group whose clone or brief fails gets
# one NONE row per defect, so the scorer counts it as unanswered.
# Usage: eval/refutation-replay/run.sh [--dry-run] [--corpus <file>] [--out <file>] [--repo <dir>]
# --dry-run prints one `group=<id> cmd: ...` line per group and runs nothing: no claude, no clone.
# Exit 3: a run used tools but the guard logged no call, so the guard is not wired; the replay stops.
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
  --max-budget-usd 1 --setting-sources local --strict-mcp-config --permission-mode dontAsk
  --tools Read,Grep,Glob,Bash
  --allowedTools Read Grep Glob "Bash(git show *)" "Bash(git diff *)" "Bash(git log *)")

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

# A fresh repository holding the reviewed commit's history only, with the baseline in it.
clone() { # <dir> <reviewed> <baseline>
  git init -q "$1" && git -C "$1" fetch -q --no-tags "file://$repo" "$2" \
    && git -C "$1" -c advice.detachedHead=false checkout -q --detach FETCH_HEAD \
    && rm -f "$1/.git/FETCH_HEAD" && git -C "$1" cat-file -e "$3^{commit}"
}
none_rows() { # <ids-json> <setup-step>: one unanswered row per defect of a group that could not run
  python3 -c 'import json, sys
for i in json.loads(sys.argv[1]):
    print(json.dumps({"id": i, "answer": "NONE", "artifact": "", "num_turns": 0, "cost_usd": 0, "setup": sys.argv[2]}, sort_keys=True))' "$1" "$2" >> "$out"
}

work="$(mktemp -d)"
trap 'rm -rf "$work"' EXIT
[ "$dry" = 1 ] || : > "$out"
n=0
while IFS=$'\t' read -r gid reviewed baseline dlines ids; do
  [ -n "$gid" ] || continue
  n=$((n + 1))
  if [ "$dry" = 1 ]; then
    echo "group=$gid cmd: claude -p <brief> ${CLAUDE_FLAGS[*]} --settings <guard.py hook for the group's clone>"
    continue
  fi
  wt="$work/$n"
  clone "$wt" "$reviewed" "$baseline" >/dev/null 2>&1 \
    || { echo "run.sh: clone failed for $gid" >&2; none_rows "$ids" clone; rm -rf "$wt"; continue; }
  prompt="$(cd "$wt" && python3 -c 'import json,sys; print("\n".join(json.loads(sys.argv[1])))' "$dlines" | bash "$brief" "$baseline")" \
    || { echo "run.sh: brief refused for $gid" >&2; none_rows "$ids" brief; rm -rf "$wt"; continue; }
  log="$work/$n.guard.log"; : > "$log"
  python3 -c 'import json, shlex, sys
cmd = " ".join(shlex.quote(x) for x in ["python3"] + sys.argv[1:])
print(json.dumps({"hooks": {"PreToolUse": [{"matcher": "*", "hooks": [{"type": "command", "command": cmd}]}]}}))' \
    "$here/guard.py" "$wt" "$log" > "$work/$n.settings.json"
  ( cd "$wt" && claude -p "$prompt" "${CLAUDE_FLAGS[@]}" --settings "$work/$n.settings.json" ) > "$work/$n.json" 2> "$work/$n.err"
  turns="$(python3 -c 'import json, sys
try:
    print(int(json.load(open(sys.argv[1])).get("num_turns") or 0))
except Exception:
    print(0)' "$work/$n.json")"
  if [ "$turns" -ge 2 ] && [ ! -s "$log" ]; then
    echo "run.sh: guard not invoked for $gid (num_turns=$turns): the guard hook is not wired; stopping" >&2
    exit 3
  fi
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
  rm -rf "$wt"
done <<< "$groups"
echo "run.sh: groups=$n dry-run=$dry out=$( [ "$dry" = 1 ] && echo none || echo "$out")"
