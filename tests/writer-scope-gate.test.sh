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
disp() { # <transcript> [<commit>]: the dispatch-baseline record (sgb-u1's format) of this transcript's dispatch
  local f="$1" id h ph m="${1%.jsonl}.meta.json"
  id="toolu_$(printf '%s' "$f" | cksum | cut -d' ' -f1)"
  h="$(git rev-parse --verify -q "${2:-HEAD}^{commit}")" || h=none
  ph="$(printf '%s' "$(jq -cR 'fromjson? | select(type == "object")' "$f" 2>/dev/null \
    | jq -rs 'try (map(select(.type == "user"))[0].message.content
        | if type == "string" then . else (map(select(.type? == "text") | .text) | join("\n")) end) catch ""' 2>/dev/null)" \
    | sha256sum | cut -d' ' -f1)"
  mkdir -p "$CLAUDE_PROJECT_DIR/.claude/reviewed"
  printf '2030-01-01T00:00:00Z tool_use_id=%s head=%s prompt=%s target=lead-programmer\n' "$id" "$h" "$ph" >> "$CLAUDE_PROJECT_DIR/.claude/reviewed/dispatch-baseline.log"
  { cat "$m" 2>/dev/null || echo '{}'; } | jq -c --arg u "$id" '. + {toolUseId:$u}' > "$m.n" && mv "$m.n" "$m"
}
commit_result() { # <file> <sha>: a Bash tool_result carrying git's commit line
  jq -nc --arg t "[master $(printf '%s' "$2" | cut -c1-7)] msg
 1 file changed" '{type:"user",message:{content:[{type:"tool_result",content:$t}]}}' >> "$1"
}
run() { # <agent_type> <transcript> -> sets rc and err; a transcript is dispatched once, at $BASE or HEAD
  [ -f "$2" ] && [ -z "$(jq -r '.toolUseId // empty' "${2%.jsonl}.meta.json" 2>/dev/null)" ] && disp "$2" "${BASE:-HEAD}"
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
BASE="$(git rev-parse HEAD)"; printf 'r2\n' > README.md && g commit -qam 'scribe: readme' && S="$(git rev-parse HEAD)"
mk "$T/t4" 'Close issue #1 for unit u1.'; commit_result "$T/t4" "$S"; run scribe "$T/t4"
[ "$rc" = 2 ] && printf '%s' "$err" | grep -qF 'README.md' && ok "(e) committed README write by scribe blocked (knowledgeWrites scoped)" || bad "(e) rc=$rc $err"
# (f) the same write passes when the dispatch names README.md.
mk "$T/t5" 'Update README.md with the new flag.'; commit_result "$T/t5" "$S"; run scribe "$T/t5"
[ "$rc" = 0 ] && ok "(f) named knowledge file allowed" || bad "(f) rc=$rc $err"
# (g) knowledgeWrites apply allows it unnamed.
printf '{"pluginVersion":"0","knowledgeWrites":"apply"}\n' > .claude/persona-config.json; run scribe "$T/t4"
[ "$rc" = 0 ] && ok "(g) apply mode allows knowledge writes" || bad "(g) rc=$rc $err"
printf '{"pluginVersion":"0"}\n' > .claude/persona-config.json
g reset -q --hard HEAD~1; unset BASE
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
BASE="$(git rev-parse HEAD)"; printf 'q\n' > 'src/q"x.js' && g add -A && g commit -qm q && S2="$(git rev-parse HEAD)"
mk "$T/t17" "$LP"; commit_result "$T/t17" "$S2"; run lead-programmer "$T/t17"
[ "$rc" = 2 ] && ok "(q) C-quoted committed path blocked" || bad "(q) rc=$rc $err"
g reset -q --hard HEAD~1
# rp-u15 fixtures replay the st-u3 review's fail-open and false-block cases. mkt is mk with a first
# timestamp; dc commits with a fixed date (neither decides the baseline: the dispatch record does, sgb-u2).
mkt() { mk "$@" && jq -c '. + {timestamp:"2099-01-01T00:00:00.000Z"}' "$1" > "$1.t" && mv "$1.t" "$1"; }
dc() { GIT_COMMITTER_DATE=2099-01-02T00:00:00Z g commit -q --date=2099-01-02T00:00:00Z "$@"; }
# (r) a committed Edit is judged against the baseline, with or without a visible commit line.
BASE="$(git rev-parse HEAD)"; printf 'c7\n' > CONTEXT.md && dc -am leak && S3="$(git rev-parse HEAD)"
mkt "$T/t18" "$LP" "$R/CONTEXT.md"; run lead-programmer "$T/t18"
[ "$rc" = 2 ] && printf '%s' "$err" | grep -qF 'scope: CONTEXT.md.' && ok "(r) committed edit, no commit line: blocked" || bad "(r) no commit line rc=$rc $err"
cp "$T/t18" "$T/t19"; commit_result "$T/t19" "$S3"; run lead-programmer "$T/t19"
[ "$rc" = 2 ] && ok "(r) committed edit, commit line: blocked" || bad "(r) commit line rc=$rc $err"
GIT_COMMITTER_DATE=2099-01-03T00:00:00Z g revert --no-edit HEAD >/dev/null; run lead-programmer "$T/t18"
[ "$rc" = 0 ] && ok "(r) committed then reverted: allowed" || bad "(r) reverted rc=$rc $err"
g reset -q --hard HEAD~2
BASE="$(git rev-parse HEAD)"; printf 'r3\n' > README.md && dc -am 'another session' && printf 'a5\n' > src/a.js && dc -am 'lead: a'
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
BASE="$(git rev-parse HEAD)"; printf 'q\n' > 'src/q"x.js' && g add -A && g commit -qm q && S4="$(git rev-parse HEAD)" && g rm -q 'src/q"x.js' && g commit -qm unq
mk "$T/t27" "$LP"; commit_result "$T/t27" "$S4"; run lead-programmer "$T/t27"
[ "$rc" = 0 ] && ok "(z) reverted C-quoted name allowed" || bad "(z) rc=$rc $err"
g reset -q --hard HEAD~2
printf 'c9\n' > CONTEXT.md && printf 'n\n' > src/new.js && printf 'k\n' > src/staged.js && g add src/staged.js
mkt "$T/t28" "$LP" "$R/CONTEXT.md" "$R/src/new.js" "$R/src/staged.js"; run lead-programmer "$T/t28"
printf '%s' "$err" | grep -qF "git checkout $(git rev-parse HEAD) -- CONTEXT.md" && printf '%s' "$err" | grep -qF 'rm -- src/new.js' \
  && printf '%s' "$err" | grep -qF 'git rm -qf -- src/staged.js' && ! printf '%s' "$err" | grep -qF 'git rm a file' && ok "(z) restore command per path" || bad "(z) message: $err"
g rm -qf -- src/staged.js; rm -f src/new.js; git checkout -q -- CONTEXT.md
# rp-u15 fix 1: a path the dispatch names counts for scribe and spec-master whatever prose punctuation
# follows it. Every row is replayed through the gate for both personas in a scratch repo, the way
# abt-u13h's close-out scribe ran: one Edit tool call, the change committed with `git commit -q` (no
# commit line in the transcript), the commit made after the dispatch recorded its baseline B2.
R2="$T/repo2"; mkdir -p "$R2/eval/abtest" "$R2/eval/other" "$R2/.claude" && cd "$R2" && git init -q . \
  && printf 'x\n' > eval/abtest/README.md && printf 'y\n' > eval/other/README.md && printf 'c\n' > CONTEXT.md \
  && printf '{"pluginVersion":"0"}\n' > .claude/persona-config.json && export CLAUDE_PROJECT_DIR="$R2" && g add -A \
  && GIT_COMMITTER_DATE=2000-01-01T00:00:00Z g commit -q --date=2000-01-01T00:00:00Z -m base2
B2="$(git rev-parse HEAD)"; BASE="$B2"; NP=eval/abtest/README.md
named_row() { # <n> <named|unnamed> <prompt; @P@ is the path, \n a newline>
  local n="$1" want="$2" pr who; pr="$(printf '%b' "${3//@P@/$NP}")"
  for who in scribe spec-master; do
    g reset -q --hard "$B2"; printf 'row %s\n' "$n" >> "$NP"; dc -a -m "row $n"
    mkt "$T/n$n.$who" "$pr" "$R2/$NP"; run "$who" "$T/n$n.$who"
    if [ "$want" = named ]; then
      [ "$rc" = 0 ] && ok "(aa) $who row $n: path named" || bad "(aa) $who row $n should be named: rc=$rc $err"
    else
      [ "$rc" = 2 ] && printf '%s' "$err" | grep -qF "scope: $NP." && ok "(aa) $who row $n: path not named" || bad "(aa) $who row $n should not be named: rc=$rc $err"
    fi
  done
}
named_row 1 named 'Scribe digest: affected files @P@. Changed API stays.'
named_row 2 named 'Edit `@P@` and nothing else.'
named_row 3 named 'Edit the readme (@P@.) today.'
named_row 4 named 'Edit @P@, then stop.'
named_row 5 named 'Edit @P@; then stop.'
named_row 6 named 'Files: @P@: add one line.'
named_row 7 named 'Edit @P@... then stop.'
named_row 8 named 'Edit @P@… then stop.'
named_row 9 named 'See [the readme](@P@) for it.'
named_row 10 named 'See @P@:12 for the line.'
named_row 11 named 'Is it @P@? Yes.'
named_row 12 named 'Do it in @P@!'
named_row 13 named 'Look at @P@:12.'
named_row 14 named 'Run:\n```\n@P@\n```\nthen stop.'
named_row 15 named 'Edit eval/other/README.md and @P@.'
named_row 16 named 'Edit @P@, eval/other/README.md.'
named_row 17 named 'Edit ./@P@ now.'
named_row 18 named 'Edit **@P@**. Done.'
named_row 26 named 'He said "edit @P@." and left.'
named_row 27 named "Edit '@P@.' now."
named_row 28 named 'Edit `@P@.` now.'
named_row 19 unnamed 'Edit x@P@ now.'
named_row 20 unnamed 'Edit @P@x now.'
named_row 21 unnamed 'Edit eval/other/README.md and README.md.'
named_row 22 unnamed 'Edit other/@P@.'
named_row 23 unnamed 'Edit @P@.bak now.'
named_row 24 unnamed 'Edit @P@/more now.'
named_row 25 unnamed 'Nothing is named here.'
# (ab) a block says when commits other than the writer's own changed the path after the baseline: the
# restore command would revert them too (another session's commit, or a commit made before the start
# and re-dated by an amend).
g reset -q --hard "$B2"; printf 'other\n' > CONTEXT.md; dc -a -m 'another session'; O="$(git rev-parse --short=10 HEAD)"
mkt "$T/w1" "$LP" "$R2/CONTEXT.md"; run lead-programmer "$T/w1"
[ "$rc" = 2 ] && printf '%s' "$err" | grep -qF "commit(s) $O" && printf '%s' "$err" | grep -qF 'not in your transcript' && ok "(ab) foreign commit named in the block" || bad "(ab) foreign rc=$rc $err"
cp "$T/w1" "$T/w2"; commit_result "$T/w2" "$(git rev-parse HEAD)"; run lead-programmer "$T/w2"
[ "$rc" = 2 ] && ! printf '%s' "$err" | grep -qF 'not in your transcript' && ok "(ab) the writer's own visible commit is not a foreign one" || bad "(ab) own rc=$rc $err"
g reset -q --hard "$B2"; printf 'early\n' > CONTEXT.md; GIT_COMMITTER_DATE=2000-06-01T00:00:00Z g commit -q -a --date=2000-06-01T00:00:00Z -m 'earlier unit'
GIT_COMMITTER_DATE=2099-01-03T00:00:00Z g commit -q --amend --no-edit --date=2099-01-03T00:00:00Z; O="$(git rev-parse --short=10 HEAD)"
run lead-programmer "$T/w1"
[ "$rc" = 2 ] && printf '%s' "$err" | grep -qF "commit(s) $O" && ok "(ab) re-dated earlier commit named in the block" || bad "(ab) amended rc=$rc $err"
g reset -q --hard "$B2"; unset BASE; cd "$R" && export CLAUDE_PROJECT_DIR="$R"
# (ac) tg-u2: a dispatch's `## Affected files` names its files as bare bullets (no backticks), or is prose
# that points at the unit's own contract and backticks some other token. Both shapes blocked listed files
# on the refutation-pass units. A file neither list names is still blocked.
mkdir -p tests docs/plans/p/contracts
printf 'Unit: u9\n\n## Affected files\n- `src/a.js`\n- `tests/u9.test.sh` (new, mode 755)\n\n## Do NOT touch\n- `README.md`\n' > docs/plans/p/contracts/u9.md
printf 'Unit: u8\n\n## Affected files\n- `CONTEXT.md`\n' > docs/plans/p/contracts/u8.md
# A contract is read as the baseline commit holds it (tg-u2 fix round 1): commit both before the cases run.
g add docs/plans/p && g commit -q -m 'tg-u2 contracts'; C0="$(git rev-parse HEAD)"
BARE='Unit: u9

## Affected files
- src/a.js
- tests/u9.test.sh (new, mode 755): its test
- Do not edit CONTEXT.md here
Nothing else.'
PROSE='Unit: u9

Objective: implement /home/u/repo/docs/plans/p/contracts/u9.md exactly as written.

## Affected files
Exactly the files under the contract `## Affected files` heading (nothing outside that list is in scope, including the generated `.claude/` mirrors only as the contract says to regenerate them).'
OTHER='Unit: u9

Objective: see docs/plans/p/contracts/u8.md for context.

## Affected files
Exactly the files your contract lists, and the generated `.claude/` mirrors only as it says.'
printf 'a9\n' > src/a.js; printf 't\n' > tests/u9.test.sh
mk "$T/x1" "$BARE" "$R/src/a.js" "$R/tests/u9.test.sh"; run lead-programmer "$T/x1"
[ "$rc" = 0 ] && ok "(ac) bare-bullet Affected files: listed edits allowed" || bad "(ac) bare rc=$rc $err"
printf 'c9\n' > CONTEXT.md; mk "$T/x2" "$BARE" "$R/src/a.js" "$R/tests/u9.test.sh" "$R/CONTEXT.md"; run lead-programmer "$T/x2"
[ "$rc" = 2 ] && printf '%s' "$err" | grep -qF "unit scope: CONTEXT.md." && ok "(ac) bare bullets: an unlisted file, even one a bullet's prose names, is blocked" || bad "(ac) bare unlisted rc=$rc $err"
git checkout -q -- CONTEXT.md
mk "$T/x3" "$PROSE" "$R/src/a.js" "$R/tests/u9.test.sh"; run lead-programmer "$T/x3"
[ "$rc" = 0 ] && ok "(ac) prose Affected files: the unit's own contract is read" || bad "(ac) prose rc=$rc $err"
printf 'c9\n' > CONTEXT.md; mk "$T/x4" "$PROSE" "$R/src/a.js" "$R/CONTEXT.md"; run lead-programmer "$T/x4"
[ "$rc" = 2 ] && printf '%s' "$err" | grep -qF "unit scope: CONTEXT.md." && ok "(ac) prose: a file the contract does not list is blocked" || bad "(ac) prose unlisted rc=$rc $err"
git checkout -q -- CONTEXT.md
printf 'r9\n' > README.md; mk "$T/x5" "$PROSE
- README.md" "$R/src/a.js" "$R/README.md"; run lead-programmer "$T/x5"
[ "$rc" = 2 ] && printf '%s' "$err" | grep -qF "unit scope: README.md." && ok "(ac) the contract's Do NOT touch still excludes a prompt-listed file" || bad "(ac) exclusion rc=$rc $err"
git checkout -q -- README.md
printf 'c9\n' > CONTEXT.md; mk "$T/x6" "$OTHER" "$R/CONTEXT.md"; run lead-programmer "$T/x6"
[ "$rc" = 2 ] && printf '%s' "$err" | grep -qF "unit scope: CONTEXT.md." && ok "(ac) another unit's cited contract does not widen the scope" || bad "(ac) other contract rc=$rc $err"
git checkout -q -- CONTEXT.md
# The writer's own contract edit must not widen its scope: the gate reads the contract at the baseline.
printf 'a9\n' > src/a.js; printf 'c9\n' > CONTEXT.md; printf 'Unit: u9\n\n## Affected files\n- `src/a.js`\n- `CONTEXT.md`\n\n## Do NOT touch\n- `README.md`\n' > docs/plans/p/contracts/u9.md
mk "$T/x7" "$PROSE" "$R/src/a.js" "$R/CONTEXT.md" "$R/docs/plans/p/contracts/u9.md"; run lead-programmer "$T/x7"
[ "$rc" = 2 ] && printf '%s' "$err" | grep -qF "unit scope: CONTEXT.md." && ok "(ac) a working-tree edit of the cited contract does not widen the scope" || bad "(ac) edited contract rc=$rc $err"
git checkout -q -- docs/plans/p/contracts/u9.md
printf 'Unit: u9\n\n## Affected files\n- `src/a.js`\n- `CONTEXT.md`\n\n## Do NOT touch\n- `README.md`\n' > docs/plans/p/contracts/u9.md
BASE="$C0"; g add -A docs/plans/p src CONTEXT.md && g commit -q -m 'writer: widen the contract and edit CONTEXT.md'; S9="$(git rev-parse HEAD)"
mk "$T/x8" "$PROSE" "$R/src/a.js" "$R/CONTEXT.md"; commit_result "$T/x8" "$S9"; run lead-programmer "$T/x8"
[ "$rc" = 2 ] && printf '%s' "$err" | grep -qF "unit scope: CONTEXT.md." && ok "(ac) a contract edit committed after the baseline does not widen the scope" || bad "(ac) committed contract rc=$rc $err"
g reset -q --hard "$C0"; unset BASE
printf 'r9\n' > README.md; printf 'Unit: u9\n\n## Affected files\n- `src/a.js`\n- `README.md`\n' > docs/plans/p/contracts/u9.md
mk "$T/x9" "$PROSE
- README.md" "$R/README.md" "$R/docs/plans/p/contracts/u9.md"; run lead-programmer "$T/x9"
[ "$rc" = 2 ] && printf '%s' "$err" | grep -qF "unit scope: README.md." && ok "(ac) a writer cannot drop the contract's own Do NOT touch entry" || bad "(ac) dropped exclusion rc=$rc $err"
git checkout -q -- README.md docs/plans/p/contracts/u9.md
printf 'Unit: u7\n\n## Affected files\n- `CONTEXT.md`\n' > docs/plans/p/contracts/u7.md; printf 'c9\n' > CONTEXT.md
mk "$T/x10" "$(printf '%s' "$PROSE" | sed 's#contracts/u9\.md#contracts/u7.md#; s#^Unit: u9#Unit: u7#')" "$R/CONTEXT.md" "$R/docs/plans/p/contracts/u7.md"; run lead-programmer "$T/x10"
[ "$rc" = 2 ] && printf '%s' "$err" | grep -qF "unit scope: CONTEXT.md." && ok "(ac) a contract the writer created after the baseline is not read" || bad "(ac) created contract rc=$rc $err"
git checkout -q -- CONTEXT.md
mkdir -p src/contracts; printf 'Unit: u9\n\n## Affected files\n- `CONTEXT.md`\n' > src/contracts/u9.md; g add src/contracts && g commit -q -m 'a look-alike contract'
printf 'c9\n' > CONTEXT.md
DOTS="$(printf '%s' "$PROSE" | sed 's#docs/plans/p/contracts/u9\.md#docs/plans/p/contracts/../../../../src/contracts/u9.md#')"
mk "$T/x11" "$DOTS" "$R/CONTEXT.md"; run lead-programmer "$T/x11"
[ "$rc" = 2 ] && printf '%s' "$err" | grep -qF "unit scope: CONTEXT.md." && ok "(ac) a cited path with .. segments is not read as a contract" || bad "(ac) dotdot citation rc=$rc $err"
g reset -q --hard "$C0"; rm -rf tests docs/plans/p src/contracts
g reset -q --hard "$C0~1"

# (ad) dispatch baseline (sgb-u1): dispatch-hygiene.sh records the main session's HEAD for each writer dispatch.
HYG="$ROOT/hooks/scripts/dispatch-hygiene.sh"
R3="$T/repo3"; mkdir -p "$R3/.claude" && cd "$R3" || exit 1
git init -q . && printf 'x\n' > x && g add -A && g commit -q -m base
printf '{"pluginVersion":"0"}\n' > .claude/persona-config.json
P="$R3"; BL="$R3/.claude/reviewed/dispatch-baseline.log"
DP='dispatch for the baseline record
'
PH="$(printf '%s' "$(printf '%s' "$DP")" | sha256sum | cut -d' ' -f1)"
pre() { # <tool_use_id> <subagent_type> <caller agent_type or -> [<name>]: echoes the hook's exit code
  jq -nc --arg u "$1" --arg s "$2" --arg c "$3" --arg n "${4-}" --arg p "$DP" \
    '{hook_event_name:"PreToolUse",tool_name:"Agent",tool_use_id:$u,tool_input:({subagent_type:$s,prompt:$p} + (if $n == "" then {} else {name:$n} end))} + (if $c == "-" then {} else {agent_type:$c} end)' \
    | CLAUDE_PROJECT_DIR="$P" bash "$HYG" >/dev/null 2>&1; echo $?
}
cnt() { { cat "$BL" 2>/dev/null || true; } | grep -cF -- "$1" || true; }
# The no-record cases below also require the log to exist already, so they cannot pass while nothing records.
TS='[0-9]{4}-[0-9]{2}-[0-9]{2}T[0-9]{2}:[0-9]{2}:[0-9]{2}Z'
rc="$(pre toolu_r1 lead-programmer -)"
grep -qxE "$TS tool_use_id=toolu_r1 head=$(git rev-parse HEAD) prompt=$PH target=lead-programmer" "$BL" 2>/dev/null && [ "$(cnt 'tool_use_id=toolu_r1 ')" = 1 ] \
  && ok "(ad) a main-session writer dispatch records HEAD and the dispatch message hash (trailing newlines stripped)" || bad "(ad) main-session writer rc=$rc"
pre toolu_r2 antislop:scribe orchestrator >/dev/null; pre toolu_r3 general-purpose - spec-master >/dev/null
[ "$(grep -cxE "$TS tool_use_id=toolu_r2 .* target=scribe" "$BL" 2>/dev/null)" = 1 ] && [ "$(grep -cxE "$TS tool_use_id=toolu_r3 .* target=spec-master" "$BL" 2>/dev/null)" = 1 ] \
  && ok "(ad) a namespaced writer, the orchestrator caller and a writer dispatch name are recorded" || bad "(ad) namespaced/orchestrator/name"
pre toolu_r4 explorer - >/dev/null; pre toolu_r5 reviewer - >/dev/null
[ -s "$BL" ] && [ "$(cnt 'tool_use_id=toolu_r4 ')$(cnt 'tool_use_id=toolu_r5 ')" = 00 ] && ok "(ad) a dispatch of a non-writer is not recorded" || bad "(ad) non-writer recorded"
pre toolu_r6 lead-programmer spec-master >/dev/null; pre toolu_r7 lead-programmer antislop:scribe >/dev/null
[ -s "$BL" ] && [ "$(cnt 'tool_use_id=toolu_r6 ')$(cnt 'tool_use_id=toolu_r7 ')" = 00 ] && ok "(ad) a writer dispatched by a subagent is not recorded" || bad "(ad) subagent dispatch recorded"
n0="$(cnt 'tool_use_id=')"; pre '../x' lead-programmer - >/dev/null; pre '' lead-programmer - >/dev/null
[ -s "$BL" ] && [ "$(cnt 'tool_use_id=')" = "$n0" ] && ok "(ad) an empty or malformed tool_use_id is not recorded" || bad "(ad) bad tool_use_id recorded"
printf '{"pluginVersion":"0","dispatchHygiene":{"mode":"off"}}\n' > .claude/persona-config.json
pre toolu_r8 lead-programmer - >/dev/null
[ "$(cnt 'tool_use_id=toolu_r8 ')" = 1 ] && ok "(ad) dispatchHygiene mode off still records" || bad "(ad) mode off not recorded"
printf '{"pluginVersion":"0","dispatchHygiene":{"mode":"warn"}}\n' > .claude/persona-config.json
rc="$(pre toolu_r9 lead-programmer -)"
[ "$rc" = 0 ] && [ "$(cnt 'tool_use_id=toolu_r9 ')" = 1 ] && ok "(ad) recording leaves the dispatch's own verdict unchanged (warn mode: exit 0)" || bad "(ad) warn mode rc=$rc"
R4="$T/repo4"; mkdir -p "$R4/.claude" && cd "$R4" && git init -q . || exit 1
printf '{"pluginVersion":"0"}\n' > .claude/persona-config.json
P="$R4"; BL="$R4/.claude/reviewed/dispatch-baseline.log"; rc="$(pre toolu_r10 lead-programmer -)"
[ "$(cnt ' tool_use_id=toolu_r10 head=none ')" = 1 ] && ok "(ad) a repository with no commit records head=none" || bad "(ad) no-commit repo rc=$rc"
cd "$R" && export CLAUDE_PROJECT_DIR="$R"

# (ae) sgb-u2: the gate takes its baseline only from the dispatch record, so none of the tg-u2 review's
# forgeries (a re-dated commit, a forged commit line, git replace, no timestamp, a replaced contract) nor a
# graft moves it. Each case runs end to end: the real dispatch-hygiene.sh records, the writer forges, the gate judges.
AE='Unit: u9

Objective: implement docs/plans/p/contracts/u9.md exactly as written.

## Affected files
- `src/a.js`'
TS0=2030-01-01T00:00:00.000Z
aenew() { # <name>: a fresh repo $T/ae-<name> with one base commit dated 2029 (AB); .claude/ stays untracked
  mkdir -p "$T/ae-$1/src" "$T/ae-$1/docs/plans/p/contracts" "$T/ae-$1/.claude" && cd "$T/ae-$1" && git init -q . || exit 1
  printf 'a\n' > src/a.js; printf 'c\n' > CONTEXT.md; printf '{"pluginVersion":"0"}\n' > .claude/persona-config.json
  printf 'Unit: u9\n\n## Affected files\n- `src/a.js`\n' > docs/plans/p/contracts/u9.md
  g add src docs CONTEXT.md && GIT_COMMITTER_DATE=2029-01-01T00:00:00Z g commit -q --date=2029-01-01T00:00:00Z -m base
  AB="$(git rev-parse HEAD)"; export CLAUDE_PROJECT_DIR="$T/ae-$1"
}
aedisp() { # <id>: the real hook records a main-session dispatch of $AE as toolu_ae_<id>
  jq -nc --arg u "toolu_ae_$1" --arg p "$AE" '{hook_event_name:"PreToolUse",tool_name:"Agent",tool_use_id:$u,tool_input:{subagent_type:"lead-programmer",prompt:$p}}' \
    | bash "$HYG" >/dev/null 2>&1
}
aemk() { # <id> <prompt> <first timestamp, or - for none> [<path edited>...]: transcript $T/ae-<id>.jsonl and its meta file
  local f="$T/ae-$1.jsonl" a
  jq -nc --arg p "$2" --arg ts "$3" '{type:"user",message:{role:"user",content:$p}} + (if $ts == "-" then {} else {timestamp:$ts} end)' > "$f"
  jq -nc --arg u "toolu_ae_$1" '{agentType:"lead-programmer",toolUseId:$u}' > "$T/ae-$1.meta.json"
  shift 3; for a in "$@"; do
    jq -nc --arg a "$PWD/$a" '{type:"assistant",message:{content:[{type:"tool_use",name:"Edit",input:{file_path:$a}}]}}' >> "$f"
  done
}
aeblk() { # <label>: rc=2 and the scope block on CONTEXT.md
  [ "$rc" = 2 ] && printf '%s' "$err" | grep -qF 'unit scope: CONTEXT.md.' && ok "(ae) $1" || bad "(ae) $1: rc=$rc $err"
}
aenew v1; aedisp v1; printf 'c2\n' > CONTEXT.md; GIT_COMMITTER_DATE=2029-06-01T00:00:00Z g commit -qam v1
aemk v1 "$AE" "$TS0" CONTEXT.md; run lead-programmer "$T/ae-v1.jsonl"
aeblk "a quiet commit backdated before the transcript's first timestamp: blocked"
aenew v2; aedisp v2; printf 'c2\n' > CONTEXT.md; GIT_COMMITTER_DATE=2030-01-01T00:00:00Z g commit -qam v2
aemk v2 "$AE" "$TS0" CONTEXT.md; run lead-programmer "$T/ae-v2.jsonl"
aeblk "a commit in the same second as the transcript's first timestamp: blocked"
aenew v3; aedisp v3; printf 'c2\n' > CONTEXT.md; g add CONTEXT.md
O="$(g commit-tree "$(git write-tree)" -m orphan)"; C="$(g commit-tree "$(git write-tree)" -p "$O" -m child)"
aemk v3 "$AE" "$TS0" CONTEXT.md
jq -nc --arg t "[x ${C:0:7}] msg" '{type:"user",message:{content:[{type:"tool_result",content:$t}]}}' >> "$T/ae-v3.jsonl"
run lead-programmer "$T/ae-v3.jsonl"
aeblk "a forged commit line whose parent is an orphan holding the edit: blocked"
aenew v4; aedisp v4; printf 'c2\n' > CONTEXT.md; g add CONTEXT.md
git replace "$AB" "$(g commit-tree "$(git write-tree)" -m replacement)"
aemk v4 "$AE" "$TS0" CONTEXT.md; run lead-programmer "$T/ae-v4.jsonl"
aeblk "a git replace of the dispatch commit: blocked"
aenew v5; aedisp v5; printf 'c2\n' > CONTEXT.md; g commit -qam v5
aemk v5 "$AE" - CONTEXT.md; run lead-programmer "$T/ae-v5.jsonl"
aeblk "a transcript with no timestamp: blocked"
aenew v6; aedisp v6
printf 'Unit: u9\n\n## Affected files\n- `src/a.js`\n- `CONTEXT.md`\n' > docs/plans/p/contracts/u9.md; g add docs/plans/p/contracts/u9.md
git replace "$AB" "$(g commit-tree "$(git write-tree)" -m replacement)"
GIT_NO_REPLACE_OBJECTS=1 git checkout "$AB" -- docs/plans/p/contracts/u9.md; printf 'c2\n' > CONTEXT.md
aemk v6 "$AE" "$TS0" CONTEXT.md; run lead-programmer "$T/ae-v6.jsonl"
aeblk "a replaced dispatch commit whose contract lists CONTEXT.md: blocked"
aenew v7; aedisp v7; printf 'c2\n' > CONTEXT.md; g add CONTEXT.md
RT="$(g commit-tree "$(git write-tree)" -m root)"; g reset -q --hard "$RT"; mkdir -p .git/info && printf '%s %s\n' "$RT" "$AB" > .git/info/grafts
aemk v7 "$AE" "$TS0" CONTEXT.md; run lead-programmer "$T/ae-v7.jsonl"
[ "$rc" = 2 ] && printf '%s' "$err" | grep -qF "no dispatch baseline for this writer (baseline ${AB:0:10} is not an ancestor of HEAD)" \
  && ok "(ae) a graft over a rewritten history: blocked, the baseline is not an ancestor" || bad "(ae) graft: rc=$rc $err"
aenew v8; printf 'a2\n' > src/a.js; GIT_COMMITTER_DATE=2029-02-01T00:00:00Z g commit -qam e; E="$(git rev-parse HEAD)"; aedisp v8
printf 'c2\n' > CONTEXT.md; g add CONTEXT.md; GIT_COMMITTER_DATE=2029-07-01T00:00:00Z g commit -q --amend --no-edit
aemk v8 "$AE" "$TS0" CONTEXT.md; run lead-programmer "$T/ae-v8.jsonl"
[ "$rc" = 2 ] && printf '%s' "$err" | grep -qF "(baseline ${E:0:10} is not an ancestor of HEAD)" \
  && ok "(ae) an amended pre-dispatch commit: blocked, the baseline is not an ancestor" || bad "(ae) amend: rc=$rc $err"
aenew c9; aedisp c9; printf 'a2\n' > src/a.js; g commit -qam a
aemk c9 "$AE" "$TS0" src/a.js; run lead-programmer "$T/ae-c9.jsonl"
[ "$rc" = 0 ] && ok "(ae) a committed in-scope edit is allowed against the dispatch baseline" || bad "(ae) in-scope: rc=$rc $err"
aenew c10; printf 'c2\n' > CONTEXT.md; aemk c10 "$AE" "$TS0" CONTEXT.md; run lead-programmer "$T/ae-c10.jsonl"
[ "$rc" = 2 ] && printf '%s' "$err" | grep -qF 'no dispatch baseline for this writer (no record)' \
  && grep -qF 'blocked: no dispatch baseline (no record)' "$T/ae-c10/.claude/bookkeeping/scope-gate.log" 2>/dev/null \
  && ok "(ae) no record and a changed path: blocked and logged" || bad "(ae) no record: rc=$rc $err"
aenew c11; aemk c11 "$AE" "$TS0"; run lead-programmer "$T/ae-c11.jsonl"
[ "$rc" = 0 ] && ok "(ae) no record and nothing changed: allowed" || bad "(ae) no record, no change: rc=$rc $err"
aenew c12; aedisp c12; printf 'c2\n' > CONTEXT.md
aemk c12 "$AE
- \`CONTEXT.md\`" "$TS0" CONTEXT.md; run lead-programmer "$T/ae-c12.jsonl"
[ "$rc" = 2 ] && printf '%s' "$err" | grep -qF '(record for another dispatch message)' \
  && ok "(ae) a record whose dispatch message differs is not used" || bad "(ae) other message: rc=$rc $err"
aenew fw; aedisp fw; printf 'c2\n' > CONTEXT.md; g commit -qam fw
printf '2030-01-01T00:00:00Z tool_use_id=toolu_ae_fw head=%s prompt=%s target=lead-programmer\n' "$(git rev-parse HEAD)" \
  "$(printf '%s' "$AE" | sha256sum | cut -d' ' -f1)" >> "$T/ae-fw/.claude/reviewed/dispatch-baseline.log"
aemk fw "$AE" "$TS0" CONTEXT.md; run lead-programmer "$T/ae-fw.jsonl"
aeblk "a later record line for the same dispatch (first record wins): blocked"
aenew two; aedisp d1; printf 'c2\n' > CONTEXT.md; g commit -qam d1; aedisp d2
aemk d1 "$AE" "$TS0" CONTEXT.md; aemk d2 "$AE" "$TS0" CONTEXT.md
run lead-programmer "$T/ae-d2.jsonl"; rc2="$rc"; run lead-programmer "$T/ae-d1.jsonl"
[ "$rc2" = 0 ] && [ "$rc" = 2 ] && printf '%s' "$err" | grep -qF 'unit scope: CONTEXT.md.' \
  && ok "(ae) each dispatch of one unit is judged against its own record" || bad "(ae) two dispatches: rc2=$rc2 rc=$rc $err"
cd "$R" && export CLAUDE_PROJECT_DIR="$R"

# (l) registration (operator step O1): SubagentStop runs stop-gate.sh first, and writer-scope-gate.sh right
# after it once the operator has registered it; before O1 the gate is inert and nothing else changes.
r="$(jq -r '.hooks.SubagentStop[0].hooks | map(.command | split("/") | last) | join(",")' "$ROOT/hooks/hooks.json")"
case "$r" in stop-gate.sh|stop-gate.sh,writer-scope-gate.sh) ok "(l) stop-gate.sh first; the gate after it or not yet registered: $r" ;; *) bad "(l) registration: $r" ;; esac
[ -x "$GATE" ] && ok "(l) executable" || bad "(l) not executable"
exit "$fail"
