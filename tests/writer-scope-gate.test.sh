#!/usr/bin/env bash
# writer-scope-gate.sh (st-u3): SubagentStop scope gate for lead-programmer, scribe and spec-master.
# Synthetic transcripts in a temp repo; the real .claude/ is never touched.
set -uo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
GATE="$ROOT/hooks/scripts/writer-scope-gate.sh"
fail=0
ok()  { echo "OK   $*"; }
bad() { echo "FAIL $*"; fail=1; }
T="$(mktemp -d)"; trap 'rm -rf "$T"' EXIT
R="$T/repo"; mkdir -p "$R/src" "$R/docs/adr" "$R/.claude" && cd "$R" || exit 1
g() { git -c user.email=t@t -c user.name=t "$@"; }
git init -q . && printf 'a\n' > src/a.js && printf 'c\n' > CONTEXT.md && printf 'r\n' > README.md
printf '{"pluginVersion":"0"}\n' > .claude/persona-config.json
g add -A && g commit -q -m base
export CLAUDE_PROJECT_DIR="$R"
# mk <file> <prompt> [<abs-path-edited>...]: a minimal transcript; prompt first, one Edit per path.
mk() {
  local f="$1" prompt="$2"; shift 2
  jq -nc --arg p "$prompt" '{type:"user",message:{role:"user",content:$p}}' > "$f"
  local a; for a in "$@"; do
    jq -nc --arg a "$a" '{type:"assistant",message:{content:[{type:"tool_use",name:"Edit",input:{file_path:$a}}]}}' >> "$f"
  done
}
commit_result() { # <file> <sha>: a Bash tool_result carrying git's commit line
  jq -nc --arg t "[master $(printf '%s' "$2" | cut -c1-7)] msg
 1 file changed" '{type:"user",message:{content:[{type:"tool_result",content:$t}]}}' >> "$1"
}
run() { # <agent_type> <transcript> -> sets rc and err
  err="$(jq -nc --arg a "$1" --arg t "$2" '{hook_event_name:"SubagentStop",agent_type:$a,agent_id:"ag1",agent_transcript_path:$t,stop_hook_active:false}' | bash "$GATE" 2>&1 >/dev/null)"; rc=$?
}
LP='Unit: u1

## Affected files
- `src/a.js`

## Acceptance criteria
1. run: `bash -c "grep -c a src/b.js"`'

# (a) lead-programmer inside scope (uncommitted Edit) passes.
printf 'a2\n' > src/a.js; mk "$T/t1" "$LP" "$R/src/a.js"; run lead-programmer "$T/t1"
[ "$rc" = 0 ] && ok "(a) listed edit allowed" || bad "(a) rc=$rc $err"
# (b) lead-programmer CONTEXT.md edit blocks, and names the path.
printf 'c2\n' > CONTEXT.md; mk "$T/t2" "$LP" "$R/src/a.js" "$R/CONTEXT.md"; run lead-programmer "$T/t2"
[ "$rc" = 2 ] && printf '%s' "$err" | grep -qF 'outside your dispatch'"'"'s unit scope: CONTEXT.md.' && ok "(b) out-of-scope edit blocked" || bad "(b) rc=$rc $err"
grep -q 'blocked: CONTEXT.md' "$R/.claude/bookkeeping/scope-gate.log" && ok "(b) logged" || bad "(b) not logged"
# (c) reverting the change clears the block (net diff, not edit history).
git checkout -q -- CONTEXT.md; run lead-programmer "$T/t2"
[ "$rc" = 0 ] && ok "(c) reverted change allowed" || bad "(c) rc=$rc $err"
# (d) criteria-named path is a standing exception for lead-programmer.
printf 'b\n' > src/b.js; mk "$T/t3" "$LP" "$R/src/b.js"; run lead-programmer "$T/t3"
[ "$rc" = 0 ] && ok "(d) criteria-named path allowed" || bad "(d) rc=$rc $err"
rm -f src/b.js; git checkout -q -- src/a.js
# (e) a committed Bash write is attributed through the commit line.
printf 'r2\n' > README.md && g commit -qam 'scribe: readme' && S="$(git rev-parse HEAD)"
mk "$T/t4" 'Close issue #1 for unit u1.'; commit_result "$T/t4" "$S"; run scribe "$T/t4"
[ "$rc" = 2 ] && printf '%s' "$err" | grep -qF 'README.md' && ok "(e) committed README write by scribe blocked (knowledgeWrites scoped)" || bad "(e) rc=$rc $err"
# (f) the same write passes when the dispatch names README.md.
mk "$T/t5" 'Update README.md with the new flag.'; commit_result "$T/t5" "$S"; run scribe "$T/t5"
[ "$rc" = 0 ] && ok "(f) named knowledge file allowed" || bad "(f) rc=$rc $err"
# (g) knowledgeWrites apply allows it unnamed.
printf '{"pluginVersion":"0","knowledgeWrites":"apply"}\n' > .claude/persona-config.json; run scribe "$T/t4"
[ "$rc" = 0 ] && ok "(g) apply mode allows knowledge writes" || bad "(g) rc=$rc $err"
printf '{"pluginVersion":"0"}\n' > .claude/persona-config.json
g reset -q --hard HEAD~1
# (h) spec-master: docs/plans and .claude are free, CONTEXT.md and code are not.
mkdir -p docs/plans/x && printf 'p\n' > docs/plans/x/spec.md && printf 'c3\n' > CONTEXT.md
mk "$T/t6" 'Write the spec.' "$R/docs/plans/x/spec.md" "$R/CONTEXT.md"; run spec-master "$T/t6"
[ "$rc" = 2 ] && printf '%s' "$err" | grep -qF 'scope: CONTEXT.md.' && ok "(h) spec-master CONTEXT.md blocked, plan allowed" || bad "(h) rc=$rc $err"
git checkout -q -- CONTEXT.md; printf 'z\n' > src/a.js; mk "$T/t7" 'Write the spec.' "$R/src/a.js"; run spec-master "$T/t7"
[ "$rc" = 2 ] && ok "(h) spec-master code write blocked" || bad "(h) rc=$rc"
git checkout -q -- src/a.js; rm -rf docs/plans
# (i) other personas, missing transcript, missing config: allowed.
printf 'c4\n' > CONTEXT.md; mk "$T/t8" 'x' "$R/CONTEXT.md"; run reviewer "$T/t8"
[ "$rc" = 0 ] && ok "(i) reviewer not gated" || bad "(i) reviewer rc=$rc"
run lead-programmer "$T/missing"; [ "$rc" = 0 ] && grep -q 'unattributable' "$R/.claude/bookkeeping/scope-gate.log" && ok "(i) no transcript: allowed and logged" || bad "(i) no transcript rc=$rc"
mv .claude/persona-config.json "$T/pc"; run lead-programmer "$T/t8"; [ "$rc" = 0 ] && ok "(i) no config: allowed" || bad "(i) no config rc=$rc"
mv "$T/pc" .claude/persona-config.json; git checkout -q -- CONTEXT.md
# (j) paths outside the project (scratch files) are ignored.
mk "$T/t9" "$LP" "$T/scratch.txt"; run lead-programmer "$T/t9"
[ "$rc" = 0 ] && ok "(j) path outside the project ignored" || bad "(j) rc=$rc"
# (k) namespaced identity still gated.
printf 'c5\n' > CONTEXT.md; run antislop:lead-programmer "$T/t2"
[ "$rc" = 2 ] && ok "(k) namespaced agent_type gated" || bad "(k) rc=$rc"
git checkout -q -- CONTEXT.md
# (m) Do NOT touch: a `partial:` bullet leaves a listed file in scope; a whole-file bullet removes it.
printf 'a3\n' > src/a.js
mk "$T/t11" "$LP
## Do NOT touch
- \`src/a.js\` partial: past its first line" "$R/src/a.js"; run lead-programmer "$T/t11"
[ "$rc" = 0 ] && ok "(m) partial bullet: listed edit allowed" || bad "(m) partial rc=$rc $err"
mk "$T/t12" "$LP
## Do NOT touch
- \`src/a.js\` (whole file)" "$R/src/a.js"; run lead-programmer "$T/t12"
[ "$rc" = 2 ] && ok "(m) whole-file bullet: listed edit blocked" || bad "(m) whole-file rc=$rc $err"
git checkout -q -- src/a.js
# (n) a unit-scope library that is missing or defines nothing blocks the writers, never other personas.
LG="$T/lg"; mkdir -p "$LG/lib" && cp "$GATE" "$LG/" && cp "$ROOT/hooks/scripts/lib/"*.sh "$LG/lib/" && : > "$LG/lib/unit-scope.sh"
GATE0="$GATE"; GATE="$LG/writer-scope-gate.sh"
mk "$T/t13" "$LP" "$R/src/a.js"; run lead-programmer "$T/t13"
[ "$rc" = 2 ] && printf '%s' "$err" | grep -qF 'unit-scope.sh is missing or incomplete' && ok "(n) empty library: writer blocked" || bad "(n) empty library rc=$rc $err"
run reviewer "$T/t13"; [ "$rc" = 0 ] && ok "(n) empty library: reviewer not gated" || bad "(n) reviewer rc=$rc"
rm -f "$LG/lib/unit-scope.sh"; run scribe "$T/t13"
[ "$rc" = 2 ] && ok "(n) missing library: writer blocked" || bad "(n) missing library rc=$rc $err"
GATE="$GATE0"
# (o) a Do NOT touch bullet naming a .claude/ copy (aof-u1-fix1's shape) says how it changes, not whether:
# the mirror its own --update regenerates is allowed (the .claude/ allowance comes before exclusions).
mkdir -p .claude/agents && printf 'o\n' > .claude/agents/orchestrator.md
mk "$T/t14" "$LP
## Do NOT touch
- \`.claude/agents/orchestrator.md\` and \`.claude/agents/task-master.md\`: no hand edits, only through \`node bin/cli.js --update\`." "$R/.claude/agents/orchestrator.md"
run lead-programmer "$T/t14"
[ "$rc" = 0 ] && ok "(o) excluded .claude/ copy regenerated: allowed" || bad "(o) rc=$rc $err"
rm -rf .claude/agents
# (p) a tool-call path is normalised before it is judged: src//a.js is the listed src/a.js, and
# .claude/../CONTEXT.md is CONTEXT.md, never the .claude/ allowance.
printf 'a4\n' > src/a.js; mk "$T/t15" "$LP" "$R/src//a.js"; run lead-programmer "$T/t15"
[ "$rc" = 0 ] && ok "(p) doubled slash judged as the listed file" || bad "(p) doubled slash rc=$rc $err"
git checkout -q -- src/a.js
printf 'c6\n' > CONTEXT.md; mk "$T/t16" 'Write the spec.' "$R/.claude/../CONTEXT.md"; run spec-master "$T/t16"
[ "$rc" = 2 ] && printf '%s' "$err" | grep -qF 'scope: CONTEXT.md.' && ok "(p) .. resolved before the .claude/ allowance" || bad "(p) dot-dot rc=$rc $err"
git checkout -q -- CONTEXT.md
# (q) a committed name git prints C-quoted cannot be judged: it blocks.
printf 'q\n' > 'src/q"x.js' && g add -A && g commit -qm q && S2="$(git rev-parse HEAD)"
mk "$T/t17" "$LP"; commit_result "$T/t17" "$S2"; run lead-programmer "$T/t17"
[ "$rc" = 2 ] && ok "(q) C-quoted committed path blocked" || bad "(q) rc=$rc $err"
g reset -q --hard HEAD~1
# rp-u15 fixtures replay the st-u3 review's fail-open and false-block cases. mkt is mk with a first
# timestamp; dc commits with a fixed date (the baseline is the last commit before that timestamp).
mkt() { mk "$@" && jq -c '. + {timestamp:"2099-01-01T00:00:00.000Z"}' "$1" > "$1.t" && mv "$1.t" "$1"; }
dc() { GIT_COMMITTER_DATE=2099-01-02T00:00:00Z g commit -q --date=2099-01-02T00:00:00Z "$@"; }
# (r) a committed Edit is judged against the baseline, with or without a visible commit line.
printf 'c7\n' > CONTEXT.md && dc -am leak && S3="$(git rev-parse HEAD)"
mkt "$T/t18" "$LP" "$R/CONTEXT.md"; run lead-programmer "$T/t18"
[ "$rc" = 2 ] && printf '%s' "$err" | grep -qF 'scope: CONTEXT.md.' && ok "(r) committed edit, no commit line: blocked" || bad "(r) no commit line rc=$rc $err"
cp "$T/t18" "$T/t19"; commit_result "$T/t19" "$S3"; run lead-programmer "$T/t19"
[ "$rc" = 2 ] && ok "(r) committed edit, commit line: blocked" || bad "(r) commit line rc=$rc $err"
GIT_COMMITTER_DATE=2099-01-03T00:00:00Z g revert --no-edit HEAD >/dev/null; run lead-programmer "$T/t18"
[ "$rc" = 0 ] && ok "(r) committed then reverted: allowed" || bad "(r) reverted rc=$rc $err"
g reset -q --hard HEAD~2
printf 'r3\n' > README.md && dc -am 'another session' && printf 'a5\n' > src/a.js && dc -am 'lead: a'
mkt "$T/t20" "$LP" "$R/src/a.js"; run lead-programmer "$T/t20"
[ "$rc" = 0 ] && ok "(r) another session's commit after the start is not blamed" || bad "(r) concurrent rc=$rc $err"
g reset -q --hard HEAD~2
# (s) a malformed line is skipped, never the whole transcript; no readable record blocks.
printf 'c8\n' > CONTEXT.md; mk "$T/t21" "$LP"; printf '{"type":"assistant","mess\n' >> "$T/t21"
jq -nc --arg a "$R/CONTEXT.md" '{type:"assistant",message:{content:[{type:"tool_use",name:"Edit",input:{file_path:$a}}]}}' >> "$T/t21"
printf '{"type":"user","message":{"content":[{"type":"tool_res' >> "$T/t21"; run lead-programmer "$T/t21"
[ "$rc" = 2 ] && printf '%s' "$err" | grep -qF 'scope: CONTEXT.md.' && ok "(s) malformed and cut-off lines skipped" || bad "(s) malformed rc=$rc $err"
printf 'not json\n{"cut' > "$T/t22"; run lead-programmer "$T/t22"
[ "$rc" = 2 ] && printf '%s' "$err" | grep -qF 'no record this gate can read' && ok "(s) no readable record: blocked" || bad "(s) unreadable rc=$rc $err"
mkdir "$T/t23"; run lead-programmer "$T/t23"
[ "$rc" = 2 ] && ok "(s) transcript path is a directory: blocked" || bad "(s) directory rc=$rc $err"
# (t) jq missing: every hook needs it (README), so the gate allows, logs and says so on stderr.
NJ="$T/nojq"; mkdir -p "$NJ"
for c in bash cat cp date dirname env git grep head mkdir mktemp rm sed sort tr wc; do ln -s "$(command -v "$c")" "$NJ/$c"; done
err="$(printf '{"hook_event_name":"SubagentStop","agent_type":"lead-programmer","agent_transcript_path":"%s"}' "$T/t21" | PATH="$NJ" bash "$GATE" 2>&1 >/dev/null)"; rc=$?
[ "$rc" = 0 ] && printf '%s' "$err" | grep -qF 'jq is not installed' && grep -q 'unattributable: jq missing' "$R/.claude/bookkeeping/scope-gate.log" && ok "(t) jq missing: loud allow" || bad "(t) rc=$rc $err"
# (u) an Edit made through a symlinked project path is judged as the file it names.
ln -s "$R" "$T/link"; mk "$T/t24" "$LP" "$T/link/CONTEXT.md"; run lead-programmer "$T/t24"
[ "$rc" = 2 ] && printf '%s' "$err" | grep -qF 'scope: CONTEXT.md.' && ok "(u) symlinked project path judged" || bad "(u) rc=$rc $err"
# (v) identity policy: the `-<n>` collision suffix is gated, and a named dispatch through its .meta.json.
mk "$T/t29" "$LP" "$R/CONTEXT.md"; run lead-programmer-2 "$T/t29"; [ "$rc" = 2 ] && ok "(v) suffixed name gated" || bad "(v) suffix rc=$rc"
cp "$T/t29" "$T/t25.jsonl"; printf '{"agentType":"lead-programmer"}\n' > "$T/t25.meta.json"; run lead-u7 "$T/t25.jsonl"
[ "$rc" = 2 ] && ok "(v) named dispatch gated through its meta file" || bad "(v) meta rc=$rc"
run Lead-Programmer "$T/t29"; [ "$rc" = 0 ] && ok "(v) a name the harness never emits is not gated" || bad "(v) case rc=$rc"
# (w) us_classify output other than an in-scope class (here: empty) is out of scope.
LG2="$T/lg2"; mkdir -p "$LG2/lib" && cp "$GATE0" "$LG2/" && cp "$ROOT/hooks/scripts/lib/"*.sh "$LG2/lib/"
printf '\nus_classify() { :; }\n' >> "$LG2/lib/unit-scope.sh"; GATE="$LG2/writer-scope-gate.sh"; run lead-programmer "$T/t29"
[ "$rc" = 2 ] && ok "(w) empty us_classify output is out" || bad "(w) rc=$rc $err"
# (x) a library that runs `exit 0` while sourced blocks a writer, never another persona.
cp "$ROOT/hooks/scripts/lib/unit-scope.sh" "$LG2/lib/" && printf '\nexit 0\n' >> "$LG2/lib/state-access.sh"; run lead-programmer "$T/t29"
[ "$rc" = 2 ] && printf '%s' "$err" | grep -qF 'ended the gate while it was being sourced' && ok "(x) library exit: writer blocked" || bad "(x) rc=$rc $err"
run reviewer "$T/t29"; [ "$rc" = 0 ] && ok "(x) library exit: reviewer not gated" || bad "(x) reviewer rc=$rc"
GATE="$GATE0"; git checkout -q -- CONTEXT.md
# (y) a write to a gitignored path (a microworlds/<slug>/ bundle) never ships: allowed.
printf 'microworlds/\n' > .gitignore && mkdir -p microworlds/m1 && printf 'r\n' > microworlds/m1/run.sh
mk "$T/t26" "$LP" "$R/microworlds/m1/run.sh"; run lead-programmer "$T/t26"
[ "$rc" = 0 ] && ok "(y) gitignored write allowed" || bad "(y) rc=$rc $err"
rm -rf microworlds .gitignore
# (z) a C-quoted committed name passes once reverted; the block says how to restore each path.
printf 'q\n' > 'src/q"x.js' && g add -A && g commit -qm q && S4="$(git rev-parse HEAD)" && g rm -q 'src/q"x.js' && g commit -qm unq
mk "$T/t27" "$LP"; commit_result "$T/t27" "$S4"; run lead-programmer "$T/t27"
[ "$rc" = 0 ] && ok "(z) reverted C-quoted name allowed" || bad "(z) rc=$rc $err"
g reset -q --hard HEAD~2
printf 'c9\n' > CONTEXT.md && printf 'n\n' > src/new.js && printf 'k\n' > src/staged.js && g add src/staged.js
mkt "$T/t28" "$LP" "$R/CONTEXT.md" "$R/src/new.js" "$R/src/staged.js"; run lead-programmer "$T/t28"
printf '%s' "$err" | grep -qF "git checkout $(git rev-parse HEAD) -- CONTEXT.md" && printf '%s' "$err" | grep -qF 'rm -- src/new.js' \
  && printf '%s' "$err" | grep -qF 'git rm -qf -- src/staged.js' && ! printf '%s' "$err" | grep -qF 'git rm a file' && ok "(z) restore command per path" || bad "(z) message: $err"
g rm -qf -- src/staged.js; rm -f src/new.js; git checkout -q -- CONTEXT.md
# (l) registration (operator step O1): SubagentStop runs stop-gate.sh first, and writer-scope-gate.sh right
# after it once the operator has registered it; before O1 the gate is inert and nothing else changes.
r="$(jq -r '.hooks.SubagentStop[0].hooks | map(.command | split("/") | last) | join(",")' "$ROOT/hooks/hooks.json")"
case "$r" in stop-gate.sh|stop-gate.sh,writer-scope-gate.sh) ok "(l) stop-gate.sh first; the gate after it or not yet registered: $r" ;; *) bad "(l) registration: $r" ;; esac
[ -x "$GATE" ] && ok "(l) executable" || bad "(l) not executable"
exit "$fail"
