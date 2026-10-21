Unit: st-u3

## Objective
A SubagentStop gate for the writers the reviewer never sees, per operator ruling OQ3 = (a), 2026-10-20: it blocks all three writers (spec Step 3, variation f).
New `hooks/scripts/writer-scope-gate.sh` is registered as the second SubagentStop hook, after stop-gate.sh. For
`lead-programmer`, `scribe` and `spec-master` (namespaced forms included) it:
- attributes changed paths from the subagent's **own** transcript (`agent_transcript_path`): the paths of its
  Write, Edit and NotebookEdit calls, plus the files of every commit whose `[<branch> <sha>]` line appears in
  its Bash results. Another session's commits are never blamed;
- keeps only the paths whose net content still differs from where the subagent started (the parent of its
  first commit, else HEAD), so a reverted change passes;
- blocks the stop (exit 2, reason on stderr) when one of them is out of scope, and logs the block to
  `.claude/bookkeeping/scope-gate.log`.

Scope per persona:
- every persona may change `.claude/` and `docs/plans/`, checked before `## Do NOT touch` (rp-u9 review,
  F1): a `.claude/` copy changes only through `node bin/cli.js --update` and `docs/plans/` is the plan, so a
  bullet naming such a path (aof-u1-fix1's "`.claude/agents/orchestrator.md` and
  `.claude/agents/task-master.md`: no hand edits, only through `--update`") states how the file may change,
  which the reviewer's `cmp` mirror criteria enforce, never whether; the gate cannot tell a hand edit from a
  regeneration, and review-precheck (st-u2) leaves both trees out of its scope lines the same way;
- lead-programmer: st-u1's `us_classify` against the dispatch's `## Affected files` (or the contract file
  the dispatch names), its criteria and the unit's `.fail` record;
- spec-master: nothing else, except knowledge files under `knowledgeWrites: "apply"`;
- scribe: `docs/` except knowledge files, which need `apply` or a dispatch that lists or names them;
- spec-master and scribe may also change a path the dispatch lists or names (aof-u4's "a path the user's
  request names").

Knowledge files are CONTEXT.md, README.md, `docs/harness-glossary.md` and `docs/adr/*`. Other personas, a
missing config or a missing transcript are allowed (the last is logged as `unattributable`). A Write or Edit
path is normalised lexically first (`//`, `.` and `..` segments, a trailing `/`; rp-u9 review, F2), so
`src//a.js` is judged as `src/a.js` and `.claude/../CONTEXT.md` as `CONTEXT.md`; a committed name git prints
C-quoted cannot be judged and blocks. `## Do NOT touch`
is read with rp-u9's `us_exclusions` (whole-subject bullets only; a bullet carrying `partial:` never excludes). If
`hooks/scripts/lib/unit-scope.sh` is missing or leaves a function the gate needs undefined (`declare -F`),
the three writers' stops are blocked with a report-and-wait message (fail closed, as rp-u8 does for the
reviewer tier); other personas are still allowed. Claude-only:
the adapters have no transcript path. `docs/trust-model.md` gains row 26, which C8.2 of
tests/trust-model-bijection.test.js requires.

## Retrieval
Fast path, no tracker issue. Spec: `docs/plans/antislop-structural/spec.md`, "Step 3 (st-u3)" and "Context, f".
This file is the contract of record. Dispatch it only after rp-u11 has reached PASS (st-u2 landed at 952a8796); it needs
st-u1's library as corrected by rp-u9 and rp-u11, and qw-u1's gitignored `.claude/bookkeeping/`.

## Affected files
- `tests/writer-scope-gate.test.sh` (anchor: new file, mode 755)
- `hooks/scripts/writer-scope-gate.sh` (anchor: new file, mode 755)
- `hooks/hooks.json` (anchor: line matching `    "SubagentStop": [`)
- `docs/trust-model.md` (anchor: line matching `| 25 | A unit touching`)
- `tests/validate.sh` (anchor: line matching `echo "== review-precheck: the reviewer's mechanical pre-review, failure lines are FAIL grounds (Bash, st-u2) =="`)
- `.claude-plugin/plugin.json`, `package.json`, `CHANGELOG.md`
- generated only, by `node bin/cli.js --update`: `.claude/hooks/scripts/writer-scope-gate.sh`, the config's `fileHashes` and `pluginVersion`

## Ordered edits
1. file: `tests/writer-scope-gate.test.sh`
   anchor: new file (mode 755)
   indent: 0
   insert-after:
~~~
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
# (l) registration: SubagentStop runs stop-gate.sh and writer-scope-gate.sh, in that order.
[ "$(jq -r '.hooks.SubagentStop[0].hooks | map(.command | split("/") | last) | join(",")' "$ROOT/hooks/hooks.json")" = 'stop-gate.sh,writer-scope-gate.sh' ] && ok "(l) registered after stop-gate" || bad "(l) registration"
[ -x "$GATE" ] && ok "(l) executable" || bad "(l) not executable"
exit "$fail"
~~~
2. command: `bash tests/writer-scope-gate.test.sh`
   expect: 1
   The red step: the gate does not exist and is not registered.
3. file: `hooks/scripts/writer-scope-gate.sh`
   anchor: new file (mode 755; hooks.json runs it directly, so a missing +x disables it)
   indent: 0
   insert-after:
~~~
#!/usr/bin/env bash
# writer-scope-gate.sh (st-u3): SubagentStop gate for the three writing personas
# (lead-programmer, scribe, spec-master). It attributes changed paths from the
# subagent's OWN transcript (Write/Edit file paths, plus the files of every commit
# whose `[<branch> <sha>]` line appears in a Bash result), keeps the ones whose net
# content still differs from where the subagent started, and blocks the stop
# (exit 2, reason on stderr) when one of them is outside the dispatch's unit scope.
# Claude-only: it needs agent_transcript_path. Reads only; its one write is a log
# line in .claude/bookkeeping/scope-gate.log (gitignored since qw-u1).
set -uo pipefail
. "$(dirname "${BASH_SOURCE[0]}")/lib/agent-identity.sh"
# agent-identity.sh sources audit-log.sh, which turns on `set -e`; this gate decides by
# explicit checks, so errexit is switched back off.
set +e
. "$(dirname "${BASH_SOURCE[0]}")/lib/unit-scope.sh" 2>/dev/null

allow() { exit 0; }
input="$(cat)"
project_dir="${CLAUDE_PROJECT_DIR:-$(printf '%s' "$input" | jq -r '.cwd // empty' 2>/dev/null)}"
[ -n "$project_dir" ] || project_dir="$PWD"
dot="${project_dir}/.claude"
config="${dot}/persona-config.json"
[ -f "$config" ] || allow
[ "$(printf '%s' "$input" | jq -r '.hook_event_name // empty' 2>/dev/null)" = SubagentStop ] || allow
persona="$(identity_persona_name "$(printf '%s' "$input" | jq -r '.agent_type // empty' 2>/dev/null)")"
case "$persona" in lead-programmer|scribe|spec-master) ;; *) allow ;; esac
agent_id="$(printf '%s' "$input" | jq -r '.agent_id // "unknown"' 2>/dev/null)"
agent_id="${agent_id//[^a-zA-Z0-9._-]/_}"
tr_path="$(printf '%s' "$input" | jq -r '.agent_transcript_path // empty' 2>/dev/null)"
cd "$project_dir" 2>/dev/null || allow
git rev-parse --verify -q HEAD >/dev/null || allow
log() { mkdir -p "$dot/bookkeeping" && printf '%s agent=%s persona=%s %s\n' "$(date -u +%Y-%m-%dT%H:%M:%SZ)" "$agent_id" "$persona" "$1" >> "$dot/bookkeeping/scope-gate.log"; }
# A missing, empty or cut-short library would make every path look in scope (an undefined function
# only reads as "false"), so the writer's stop fails closed until the library is restored.
if ! declare -F us_section us_entries us_exclusions us_excluded us_listed us_named_in us_classify >/dev/null; then
  log "blocked: unit-scope library unavailable"
  echo "BLOCKED (writer-scope-gate): hooks/scripts/lib/unit-scope.sh is missing or incomplete, so your changes cannot be checked against your unit scope. Report this block to your dispatcher and wait; do not edit the library." >&2
  exit 2
fi
if [ -z "$tr_path" ] || [ ! -r "$tr_path" ]; then log "unattributable: no transcript"; allow; fi

W="$(mktemp -d)"; trap 'rm -rf "$W"' EXIT
jq -rs 'map(select(.type == "user"))[0].message.content
        | if type == "string" then . else (map(select(.type? == "text") | .text) | join("\n")) end' \
  "$tr_path" > "$W/prompt" 2>/dev/null || : > "$W/prompt"
jq -r 'select(.type == "assistant") | .message.content[]?
       | select(type == "object" and .type == "tool_use" and (.name == "Write" or .name == "Edit" or .name == "NotebookEdit"))
       | .input.file_path // .input.notebook_path // empty' "$tr_path" 2>/dev/null > "$W/abs" || : > "$W/abs"
jq -r 'select(.type == "user") | .message.content[]?
       | select(type == "object" and .type == "tool_result") | .content
       | if type == "string" then . else (map(select(.type? == "text") | .text) | join("\n")) end' "$tr_path" 2>/dev/null \
  | grep -oE '^\[[^]]* [0-9a-f]{7,40}\]' | grep -oE '[0-9a-f]{7,40}\]$' | tr -d ']' > "$W/shas" || true

# norm_abs <absolute path>: `//`, `.` and `..` segments resolved lexically and no trailing `/`, so a
# tool-call path such as `src//a.js` or `.claude/../CONTEXT.md` is judged as the file it names (rp-u11).
norm_abs() {
  local rest="$1/" seg out=""
  while [ -n "$rest" ]; do
    seg="${rest%%/*}"; rest="${rest#*/}"
    case "$seg" in ''|.) ;; ..) out="${out%/*}" ;; *) out="$out/$seg" ;; esac
  done
  printf '%s\n' "${out:-/}"
}
top="$(pwd -P)"
pd="$(norm_abs "$project_dir")"
: > "$W/cand"
while IFS= read -r a; do
  [ -n "$a" ] || continue
  a="$(norm_abs "$a")"
  case "$a" in "$top"/*) printf '%s\n' "${a#"$top"/}" >> "$W/cand" ;; "$pd"/*) printf '%s\n' "${a#"$pd"/}" >> "$W/cand" ;; esac
done < "$W/abs"
start=""
while IFS= read -r s; do
  git cat-file -e "$s^{commit}" 2>/dev/null || continue
  [ -n "$start" ] || start="$(git rev-parse -q --verify "$s^" 2>/dev/null || git hash-object -t tree /dev/null)"
  git -c core.quotepath=false show --no-renames --name-only --format= "$s" >> "$W/cand"
done < "$W/shas"
[ -n "$start" ] || start="HEAD"

us_section "$W/prompt" "Affected files" > "$W/sec"
us_entries "$W/prompt" > "$W/listed"
us_exclusions "$W/prompt" > "$W/excl"
if [ ! -s "$W/listed" ]; then
  c="$(grep -oE 'docs/plans/[A-Za-z0-9._/-]*contracts/[A-Za-z0-9._#-]+\.md' "$W/prompt" | head -n1)"
  [ -n "$c" ] && [ -f "$c" ] && us_entries "$c" > "$W/listed"
  [ -n "$c" ] && [ -f "$c" ] && us_exclusions "$c" > "$W/excl"
fi
grep -oE 'file: `[^` ]+`' "$W/prompt" | sed 's/^file: `//; s/`$//' >> "$W/listed" || true
us_section "$W/prompt" "Acceptance criteria" | grep -E '^[0-9]+\. run: ' > "$W/crit" || true
unit="$(sed -n 's/^Unit: \([A-Za-z0-9][A-Za-z0-9._#-]*\)$/\1/p' "$W/prompt" | head -n1)"
: > "$W/failrec"; [ -z "$unit" ] || [ ! -f "$dot/reviewed/$unit.fail" ] || cp "$dot/reviewed/$unit.fail" "$W/failrec"
kw="$(jq -r '.knowledgeWrites // "scoped"' "$config" 2>/dev/null)"; [ "$kw" = apply ] || kw=scoped

knowledge() { case "$1" in CONTEXT.md|README.md|docs/harness-glossary.md|docs/adr/*) return 0 ;; esac; return 1; }
in_scope() { # <path> -> exit 0 when this persona may leave it changed
  local p="$1"
  # This standing exception comes before `## Do NOT touch`: a `.claude/` copy changes only through
  # `--update` and `docs/plans/` is the plan itself, so a bullet naming such a path says how it may
  # change (the reviewer's mirror checks enforce that), never whether; this gate cannot tell a hand edit
  # from a regeneration. review-precheck leaves both trees out of its scope lines the same way.
  case "$p" in .claude/*|docs/plans/*) return 0 ;; esac
  us_excluded "$p" "$W/excl" && return 1
  us_listed "$p" "$W/listed" && return 0
  us_named_in "$p" "$W/prompt" && [ "$persona" != lead-programmer ] && return 0
  case "$persona" in
    lead-programmer)
      case "$(us_classify "$p" "$start" "$W/listed" /dev/null "$W/crit" "$W/failrec")" in out) return 1 ;; *) return 0 ;; esac ;;
    spec-master)
      knowledge "$p" && [ "$kw" = apply ] && return 0; return 1 ;;
    scribe)
      if knowledge "$p"; then [ "$kw" = apply ] && return 0; return 1; fi
      case "$p" in docs/*) return 0 ;; esac; return 1 ;;
  esac
  return 1
}
viol=()
while IFS= read -r p; do
  [ -n "$p" ] || continue
  # git C-quotes a committed name holding a quote, a backslash or a control character; such a path
  # cannot be judged (review-precheck fails it as `unquotable`), so it is out of scope.
  case "$p" in '"'*) viol+=("$p"); continue ;; esac
  if git ls-files --error-unmatch -- "$p" >/dev/null 2>&1 || git cat-file -e "$start:$p" 2>/dev/null; then
    git diff --quiet "$start" -- "$p" 2>/dev/null && continue
  else
    [ -e "$p" ] || continue
  fi
  in_scope "$p" || viol+=("$p")
done < <(sort -u "$W/cand")
[ "${#viol[@]}" -eq 0 ] && allow
log "blocked: ${viol[*]}"
{
  echo "BLOCKED (writer-scope-gate): you left changes outside your dispatch's unit scope: ${viol[*]}."
  echo "Restore each one (git checkout $start -- <path>, or git rm a file you added) and commit, then report the change under \`Proposed out-of-scope changes:\` (or \`Knowledge proposals:\`) instead of applying it. In scope: the dispatch's \`## Affected files\` and your persona's standing exceptions; knowledge files (CONTEXT.md, README.md, docs/harness-glossary.md, docs/adr/) need knowledgeWrites \"apply\" or a dispatch that lists or names them."
} >&2
exit 2
~~~
4. file: `hooks/hooks.json`
   anchor: line matching `    "SubagentStop": [`
   indent: 0
   before:
~~~
    "SubagentStop": [
      {
        "hooks": [
          { "type": "command", "command": "${CLAUDE_PLUGIN_ROOT}/hooks/scripts/stop-gate.sh" }
        ]
~~~
   after:
~~~
    "SubagentStop": [
      {
        "hooks": [
          { "type": "command", "command": "${CLAUDE_PLUGIN_ROOT}/hooks/scripts/stop-gate.sh" },
          { "type": "command", "command": "${CLAUDE_PLUGIN_ROOT}/hooks/scripts/writer-scope-gate.sh" }
        ]
~~~
5. file: `docs/trust-model.md`
   anchor: line matching `| 25 | A unit touching` (the last numbered row of the table)
   indent: 0
   insert-after:
~~~
| 26 | A writing persona (lead-programmer, scribe, spec-master) ends its turn with no net change outside its dispatch's unit scope | lead-programmer, scribe, spec-master | `hooks/scripts/writer-scope-gate.sh` | SubagentStop gate (unit st-u3). Attributes paths from the subagent's own transcript (Write/Edit file paths, plus the files of each commit whose `[<branch> <sha>]` line it saw), so a concurrent writer is never blamed; Write/Edit paths are normalised lexically before they are judged; a Bash write that never went through Write/Edit and was never committed is not attributed (residual). A missing transcript is allowed and logged to `.claude/bookkeeping/scope-gate.log`. |
~~~
6. file: `tests/validate.sh`
   anchor: line matching `echo "== review-precheck: the reviewer's mechanical pre-review, failure lines are FAIL grounds (Bash, st-u2) =="`
   indent: 0
   before:
~~~
echo "== review-precheck: the reviewer's mechanical pre-review, failure lines are FAIL grounds (Bash, st-u2) =="
if bash tests/review-precheck.test.sh > /dev/null; then
  echo "OK   tests/review-precheck.test.sh"
else
  echo "FAIL tests/review-precheck.test.sh"
  fail=1
fi
~~~
   after:
~~~
echo "== review-precheck: the reviewer's mechanical pre-review, failure lines are FAIL grounds (Bash, st-u2) =="
if bash tests/review-precheck.test.sh > /dev/null; then
  echo "OK   tests/review-precheck.test.sh"
else
  echo "FAIL tests/review-precheck.test.sh"
  fail=1
fi

echo
echo "== writer-scope-gate: lead-programmer, scribe and spec-master cannot stop with an out-of-scope change (Bash, st-u3) =="
if bash tests/writer-scope-gate.test.sh > /dev/null; then
  echo "OK   tests/writer-scope-gate.test.sh"
else
  echo "FAIL tests/writer-scope-gate.test.sh"
  fail=1
fi
~~~
7. command: `bash tests/writer-scope-gate.test.sh`
   expect: 0
8. command: `perl -0pi -e 's/("version": "\d+\.\d+\.)(\d+)"/$1.($2+1)."\""/e' .claude-plugin/plugin.json package.json`
   expect: 0
   This adds one to the patch version in both files (expected 0.31.202 to 0.31.203). The bump is required: `--update`
   installs a new hook script only when `pluginVersion` moves.
9. file: `CHANGELOG.md`
   anchor: line matching `## [Unreleased]`
   indent: 0
   insert-after:
~~~

**Writer scope gate (st-u3, VERSION).** New SubagentStop hook `hooks/scripts/writer-scope-gate.sh`, registered after stop-gate.sh: lead-programmer, scribe and spec-master cannot end a turn while a change they made (Write/Edit paths and their own commits, read from their own transcript) is outside the dispatch's unit scope; knowledge files need `knowledgeWrites: "apply"` or a dispatch that lists or names them. `.claude/` and `docs/plans/` are allowed before `## Do NOT touch` is read (a bullet naming a `.claude/` copy says it changes only through `--update`); Write/Edit paths are normalised lexically, and a C-quoted committed name blocks. A reverted change passes. Blocks are logged to `.claude/bookkeeping/scope-gate.log`. docs/trust-model.md row 26. New test tests/writer-scope-gate.test.sh.
~~~
   Replace `VERSION` with the version that edit 8 wrote.
10. command: `node bin/cli.js --update`
   expect: 0
11. command: `git add tests/writer-scope-gate.test.sh hooks/scripts/writer-scope-gate.sh .claude/hooks/scripts/writer-scope-gate.sh && git add -u && git commit -m "feat(st-u3): writer scope gate at SubagentStop for lead-programmer, scribe and spec-master"`
   expect: 0
   Run `git status --short` first: if a tracked file outside "Affected files" is modified, stop and report it.

## Do NOT touch
- `hooks/scripts/stop-gate.sh` and `hooks/scripts/lib/stop-gate-core.sh` (the new gate is a separate script; criterion 4)
- `hooks/scripts/lib/unit-scope.sh` (st-u1's library as corrected by rp-u9 and rp-u11; this unit only sources it)
- `adapters/` (Claude-only: the codex and cursor hook inputs carry no `agent_transcript_path`; criterion 4)
- `agents/` and `templates/` (the gate's block message is the instruction; no persona prose changes; criterion 4)
- `.claude/hooks/` by hand (only `node bin/cli.js --update` writes it)

## Acceptance criteria
1. run: `bash -c 'bash tests/writer-scope-gate.test.sh >/dev/null; echo $?'`
   exit: 0
   stdout: `0`
   mutation: delete the gate's `set +e` line; agent-identity.sh's sourced audit-log.sh leaves errexit on, cases (e) to (h) exit 1 instead of 0 or 2, and stdout is `1` (spec-master observed this on a clone). Deleting the `declare -F` block fails both (n) writer cases; calling `us_entries "$W/prompt"` instead of `us_exclusions "$W/prompt"` fails the (m) partial case. Moving the `.claude/*|docs/plans/*` allowance below the `us_excluded` line fails (o); deleting the `a="$(norm_abs "$a")"` line fails both (p) rows; deleting the C-quoted `case` line fails (q) (spec-master ran all three).
2. run: `cmp hooks/scripts/writer-scope-gate.sh .claude/hooks/scripts/writer-scope-gate.sh`
   exit: 0
   stdout: empty
   mutation: append a line to `.claude/hooks/scripts/writer-scope-gate.sh`; cmp reports the difference and exits 1.
3. run: `bash -c 'node tests/trust-model-bijection.test.js >/dev/null 2>&1 && node tests/cli-hook-propagation.test.js >/dev/null 2>&1 && bash tests/harness-integrity-gate.test.sh >/dev/null 2>&1 && bash tests/abtest-arms.test.sh >/dev/null 2>&1; echo $?'` (Bash tool timeout 600000 ms)
   exit: 0
   stdout: `0`
   mutation: skip edit 5; trust-model-bijection C8.2 prints `writer-scope-gate.sh is not mentioned anywhere in docs/trust-model.md` and stdout is `1` (spec-master observed this on a clone).
4. run: `bash -c 'b=$(git log --format=%H --grep="(st-u3)" | tail -1); l=$(git log --format=%H --grep="(st-u3)" | head -1); git diff --name-only "$b^..$l" -- adapters agents templates hooks/scripts/stop-gate.sh hooks/scripts/lib | wc -l'`
   exit: 0
   stdout: `0`
   mutation: also register the gate in `adapters/cursor/hooks/hooks.json`; stdout is at least `1`.
5. run: `bash -c 'jq -r ".hooks.SubagentStop[0].hooks | map(.command | split(\"/\") | last) | join(\",\")" hooks/hooks.json'`
   exit: 0
   stdout: `stop-gate.sh,writer-scope-gate.sh`
   mutation: skip edit 4; stdout is `stop-gate.sh`.
6. run: `bash -c 'b=$(git log --format=%H --grep="(st-u3)" | tail -1); l=$(git log --format=%H --grep="(st-u3)" | head -1); test "$(git show "$b^:.claude-plugin/plugin.json" | grep "\"version\"")" != "$(git show "$l:.claude-plugin/plugin.json" | grep "\"version\"")" && test "$(git show "$l:CHANGELOG.md" | grep -c "(st-u3, ")" = 1 && echo moved'`
   exit: 0
   stdout: `moved`
   mutation: skip edit 8; the versions are equal, stdout is empty and the exit is 1.
7. run: `bash -c 'bash tests/validate.sh >/dev/null 2>&1; echo $?'` (Bash tool timeout 600000 ms)
   exit: 0
   stdout: `0`
   mutation: put `exit 1` as line 2 of tests/writer-scope-gate.test.sh; validate.sh exits 1 and stdout is `1`.

## Pre-resolved context
tdd: yes the test (edit 1) fails first (edit 2). spec-master applied edits 1 to 6 to a clone at eb59e217 with st-u1 and st-u2 applied: 17 checks pass; `--update` installs the gate (cmp clean); trust-model-bijection, cli-hook-propagation, protected-paths-coverage, cli-backfill, harness-integrity-gate, state-access-constraints, reviewer-route-gate-caller, rollout-preflight, human-decision-gate and abtest-arms (on the committed clone; it reads `git archive HEAD`) all exit 0. validate.sh was not run by spec-master.
blast-radius: hooks/hooks.json:47-53 (SubagentStop), docs/trust-model.md:63 (row 25), tests/trust-model-bijection.test.js:63 (C8.2, every hooks/scripts/*.sh named in the doc), tests/abtest-arms.test.sh (reads hooks.json in the plugin copy), hooks/scripts/lib/agent-identity.sh:61 (identity_persona_name), hooks/scripts/lib/audit-log.sh:18 (`set -euo pipefail`, inherited by sourcing). Line numbers are at eb59e217.
errexit: agent-identity.sh sources audit-log.sh, which runs `set -euo pipefail` at source time. The gate branches on exit codes (grep with no match, `[ -n ]` tests), so it switches errexit off right after sourcing. Without that line, five cases exit 1.
attribution: transcript records are JSON lines; the first `type: user` record is the dispatch prompt (string, or an array of text blocks); Write/Edit tool_use inputs carry absolute `file_path`; Bash tool_result text carries `[<branch> <sha>] <subject>` for each commit. Paths outside the project (scratch files) are ignored.
start-point: the parent of the first attributed commit, else HEAD; a path counts only if `git diff --quiet <start> -- <path>` fails, or it is a new file that exists. The block text tells the writer to restore with `git checkout <start> -- <path>` and commit; never a reset (R4).
loop-bound: the gate blocks on every stop while the violation stands; Claude Code ends a stop-hook loop after 8 continuations. It does not honour the WIP sentinel, which stop-gate.sh consumes concurrently.
residual: a Bash heredoc write that is neither committed nor made through Write/Edit is not attributed (trust-model row 26 says so).
version: .claude-plugin/plugin.json and package.json read 0.31.202 after rp-u11 if no fix round bumped; edit 8 adds one (expected 0.31.203).
amended-2: 2026-10-21, after rp-u9's review (review-patches spec Step 10, findings F1 and F2): `in_scope` checks the `.claude/` and `docs/plans/` allowance before `## Do NOT touch` (aof-u1-fix1's bullet excluded the two `.claude/agents/` copies its own mandated `--update` regenerated, so the old order would have blocked a correct unit; st-u2's precheck already leaves both trees out); a Write/Edit path is normalised lexically by `norm_abs` before it is judged (a doubled slash used to classify `out` and block a legitimate edit, and `.claude/../CONTEXT.md` fell under the `.claude/` allowance); a C-quoted committed name blocks (it used to be skipped as a missing file). Cases (o), (p) and (q) pin the three. A deliberate exclusion of a `.claude/` path is reviewer-enforced prose ("only through `--update`"), not a gate input; a contract that must stop a writer from regenerating a mirror says so in its Objective. Re-proven on a clone at 952a8796 with rp-u11 applied: every payload matched once, the test printed 0 FAIL lines after `--update`, criteria 1 to 6 held, and (o), (p) and (q) failed under their mutations.
amended: 2026-10-21, after st-u1's review (review-patches spec Step 9): the gate sources unit-scope.sh after `set +e` and blocks a writer's stop when a function it needs is undefined (`declare -F`; a missing library used to exit 1 under the inherited `set -e`, which Claude Code treats as allow, and an empty one made every path in scope); `## Do NOT touch` is read with rp-u9's `us_exclusions` (a bullet carrying `partial:` never excludes); cases (m) and (n) pin both; criteria 4 and 6 name the unit's last commit. Re-proven on a clone at 0b45bd46 with rp-u8, rp-u9 and the amended st-u2 applied: every payload matched once, the test printed 0 FAIL lines after `--update`, and (m) and (n) failed with the `us_exclusions` call or the guard reverted.
mirrors: `.claude/` copies change only through `node bin/cli.js --update` (constitution P2).
commit-message: feat(st-u3): writer scope gate at SubagentStop for lead-programmer, scribe and spec-master
diagnosis: none
review-packet:
~~~
unit: st-u3
changed files: <FILL: changed files>
commit: <FILL: commit SHA>
criterion 1: <FILL: exit and stdout>
criterion 2: <FILL: exit and stdout>
criterion 3: <FILL: exit and stdout>
criterion 4: <FILL: exit and stdout>
criterion 5: <FILL: exit and stdout>
criterion 6: <FILL: exit and stdout>
criterion 7: <FILL: exit and stdout>
~~~

## Escalation
If a `before:` payload is not found verbatim, stop and
report the current text. If a hook suite other than the ones in criterion 3 fails because of the new registration,
quote it and stop. If a gate blocks a command, report it and wait. Anything outside "Affected files" goes to your
report as a proposal.
