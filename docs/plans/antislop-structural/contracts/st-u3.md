Unit: st-u3

## Objective
A SubagentStop gate for the writers the reviewer never sees, written for OQ3 = (a) (spec Step 3, variation f).
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
- every persona may change `.claude/` and `docs/plans/`;
- lead-programmer: st-u1's `us_classify` against the dispatch's `## Affected files` (or the contract file
  the dispatch names), its criteria and the unit's `.fail` record;
- spec-master: nothing else, except knowledge files under `knowledgeWrites: "apply"`;
- scribe: `docs/` except knowledge files, which need `apply` or a dispatch that lists or names them;
- spec-master and scribe may also change a path the dispatch lists or names (aof-u4's "a path the user's
  request names").

Knowledge files are CONTEXT.md, README.md, `docs/harness-glossary.md` and `docs/adr/*`. Other personas, a
missing config or a missing transcript are allowed (the last is logged as `unattributable`). Claude-only:
the adapters have no transcript path. `docs/trust-model.md` gains row 26, which C8.2 of
tests/trust-model-bijection.test.js requires.

Under OQ3 = (b), change the persona `case` line to `scribe|spec-master` and drop test cases (a) to (d) and
(k); under (c) this unit is replaced.

## Retrieval
Fast path, no tracker issue. Spec: `docs/plans/antislop-structural/spec.md`, "Step 3 (st-u3)" and "Context, f".
This file is the contract of record. Dispatch it only after st-u2 has reached PASS and the operator has ruled
OQ3; it needs st-u1's library and qw-u1's gitignored `.claude/bookkeeping/`.

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
. "$(dirname "${BASH_SOURCE[0]}")/lib/unit-scope.sh"
# agent-identity.sh sources audit-log.sh, which turns on `set -e`; this gate decides by
# explicit checks, so errexit is switched back off.
set +e

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

top="$(pwd -P)"
: > "$W/cand"
while IFS= read -r a; do
  [ -n "$a" ] || continue
  case "$a" in "$top"/*) printf '%s\n' "${a#"$top"/}" >> "$W/cand" ;; "$project_dir"/*) printf '%s\n' "${a#"$project_dir"/}" >> "$W/cand" ;; esac
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
if [ ! -s "$W/listed" ]; then
  c="$(grep -oE 'docs/plans/[A-Za-z0-9._/-]*contracts/[A-Za-z0-9._#-]+\.md' "$W/prompt" | head -n1)"
  [ -n "$c" ] && [ -f "$c" ] && us_entries "$c" > "$W/listed"
fi
grep -oE 'file: `[^` ]+`' "$W/prompt" | sed 's/^file: `//; s/`$//' >> "$W/listed" || true
us_section "$W/prompt" "Acceptance criteria" | grep -E '^[0-9]+\. run: ' > "$W/crit" || true
unit="$(sed -n 's/^Unit: \([A-Za-z0-9][A-Za-z0-9._#-]*\)$/\1/p' "$W/prompt" | head -n1)"
: > "$W/failrec"; [ -z "$unit" ] || [ ! -f "$dot/reviewed/$unit.fail" ] || cp "$dot/reviewed/$unit.fail" "$W/failrec"
kw="$(jq -r '.knowledgeWrites // "scoped"' "$config" 2>/dev/null)"; [ "$kw" = apply ] || kw=scoped

knowledge() { case "$1" in CONTEXT.md|README.md|docs/harness-glossary.md|docs/adr/*) return 0 ;; esac; return 1; }
in_scope() { # <path> -> exit 0 when this persona may leave it changed
  local p="$1"
  case "$p" in .claude/*|docs/plans/*) return 0 ;; esac
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
| 26 | A writing persona (lead-programmer, scribe, spec-master) ends its turn with no net change outside its dispatch's unit scope | lead-programmer, scribe, spec-master | `hooks/scripts/writer-scope-gate.sh` | SubagentStop gate (unit st-u3). Attributes paths from the subagent's own transcript (Write/Edit file paths, plus the files of each commit whose `[<branch> <sha>]` line it saw), so a concurrent writer is never blamed; a Bash write that never went through Write/Edit and was never committed is not attributed (residual). A missing transcript is allowed and logged to `.claude/bookkeeping/scope-gate.log`. |
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
   This adds one to the patch version in both files (expected 0.31.195 to 0.31.196). The bump is required: `--update`
   installs a new hook script only when `pluginVersion` moves.
9. file: `CHANGELOG.md`
   anchor: line matching `## [Unreleased]`
   indent: 0
   insert-after:
~~~

**Writer scope gate (st-u3, VERSION).** New SubagentStop hook `hooks/scripts/writer-scope-gate.sh`, registered after stop-gate.sh: lead-programmer, scribe and spec-master cannot end a turn while a change they made (Write/Edit paths and their own commits, read from their own transcript) is outside the dispatch's unit scope; knowledge files need `knowledgeWrites: "apply"` or a dispatch that lists or names them. A reverted change passes. Blocks are logged to `.claude/bookkeeping/scope-gate.log`. docs/trust-model.md row 26. New test tests/writer-scope-gate.test.sh.
~~~
   Replace `VERSION` with the version that edit 8 wrote.
10. command: `node bin/cli.js --update`
   expect: 0
11. command: `git add tests/writer-scope-gate.test.sh hooks/scripts/writer-scope-gate.sh .claude/hooks/scripts/writer-scope-gate.sh && git add -u && git commit -m "feat(st-u3): writer scope gate at SubagentStop for lead-programmer, scribe and spec-master"`
   expect: 0
   Run `git status --short` first: if a tracked file outside "Affected files" is modified, stop and report it.

## Do NOT touch
- `hooks/scripts/stop-gate.sh` and `hooks/scripts/lib/stop-gate-core.sh` (the new gate is a separate script; criterion 4)
- `hooks/scripts/lib/unit-scope.sh` (st-u1's library; this unit only sources it)
- `adapters/` (Claude-only: the codex and cursor hook inputs carry no `agent_transcript_path`; criterion 4)
- `agents/` and `templates/` (the gate's block message is the instruction; no persona prose changes; criterion 4)
- `.claude/hooks/` by hand (only `node bin/cli.js --update` writes it)

## Acceptance criteria
1. run: `bash -c 'bash tests/writer-scope-gate.test.sh >/dev/null; echo $?'`
   exit: 0
   stdout: `0`
   mutation: delete the gate's `set +e` line; agent-identity.sh's sourced audit-log.sh leaves errexit on, cases (e) to (h) exit 1 instead of 0 or 2, and stdout is `1` (spec-master observed this on a clone).
2. run: `cmp hooks/scripts/writer-scope-gate.sh .claude/hooks/scripts/writer-scope-gate.sh`
   exit: 0
   stdout: empty
   mutation: append a line to `.claude/hooks/scripts/writer-scope-gate.sh`; cmp reports the difference and exits 1.
3. run: `bash -c 'node tests/trust-model-bijection.test.js >/dev/null 2>&1 && node tests/cli-hook-propagation.test.js >/dev/null 2>&1 && bash tests/harness-integrity-gate.test.sh >/dev/null 2>&1 && bash tests/abtest-arms.test.sh >/dev/null 2>&1; echo $?'` (Bash tool timeout 600000 ms)
   exit: 0
   stdout: `0`
   mutation: skip edit 5; trust-model-bijection C8.2 prints `writer-scope-gate.sh is not mentioned anywhere in docs/trust-model.md` and stdout is `1` (spec-master observed this on a clone).
4. run: `bash -c 'b=$(git log --format=%H --grep="(st-u3)" | tail -1); git diff --name-only "$b^..HEAD" -- adapters agents templates hooks/scripts/stop-gate.sh hooks/scripts/lib | wc -l'`
   exit: 0
   stdout: `0`
   mutation: also register the gate in `adapters/cursor/hooks/hooks.json`; stdout is at least `1`.
5. run: `bash -c 'jq -r ".hooks.SubagentStop[0].hooks | map(.command | split(\"/\") | last) | join(\",\")" hooks/hooks.json'`
   exit: 0
   stdout: `stop-gate.sh,writer-scope-gate.sh`
   mutation: skip edit 4; stdout is `stop-gate.sh`.
6. run: `bash -c 'b=$(git log --format=%H --grep="(st-u3)" | tail -1); test "$(git show "$b^:.claude-plugin/plugin.json" | grep "\"version\"")" != "$(grep "\"version\"" .claude-plugin/plugin.json)" && test "$(grep -c "(st-u3, " CHANGELOG.md)" = 1 && echo moved'`
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
version: .claude-plugin/plugin.json and package.json read 0.31.195 after st-u2 if no fix round bumped; edit 8 adds one (expected 0.31.196).
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
If OQ3 has not been ruled, do not start: report and wait. If a `before:` payload is not found verbatim, stop and
report the current text. If a hook suite other than the ones in criterion 3 fails because of the new registration,
quote it and stop. If a gate blocks a command, report it and wait. Anything outside "Affected files" goes to your
report as a proposal.
