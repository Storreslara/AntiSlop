Unit: rp-u15

## Objective
Harden st-u3's writer scope gate (`hooks/scripts/writer-scope-gate.sh`, landed at abc6d195, 0.31.204) against
the st-u3 review's notes, before the operator registers it (operator step O1 is held until this unit lands).
Every case below was reproduced on a scratch clone of abc6d195 with the leak standing (Pre-resolved context
`evidence:`). After this unit the gate:
- judges each Write/Edit/NotebookEdit path against a baseline taken from the transcript, not from HEAD at
  stop time: the last commit on HEAD's first-parent line before the transcript's first `timestamp`, and no
  later than the parent of the first `[<branch> <sha>]` commit line it saw (`git merge-base` of the two). A
  committed out-of-scope edit now blocks whether or not its commit line is in the transcript;
- parses the transcript line by line (`jq -R 'fromjson?'`): a malformed or cut-off line is skipped and
  logged, never the whole file; a transcript path that exists but holds no readable record (a directory, a
  foreign format) blocks a writer;
- allows with a stderr warning and a log line when `jq` is missing (README: every hook needs it; without jq
  the gate cannot tell which persona stopped);
- resolves each path's directory with `pwd -P`, so an edit through a symlinked project path is judged;
- gates the exact persona name, its namespaced form, the harness's `-<n>` collision suffix
  (`lead-programmer-2`) and a named dispatch whose transcript's sibling `.meta.json` records a writer
  `agentType`; `Lead-Programmer` and `'lead-programmer '` are not names the harness emits and stay ungated;
- counts only `listed`, `criteria`, `fail-record`, `fix-contract`, `plugin-version` and `judge` from
  `us_classify` as in scope (`out`, `excluded`, empty or anything else is out);
- blocks a writer when a library ends the gate while it is sourced (EXIT trap; `agent-identity.sh` joins the
  guarded group and the `declare -F` list);
- skips an untracked file git ignores (`git check-ignore`; microworld bundles under `microworlds/<slug>/`);
- reads commit file names NUL-separated (`git show -z`), so a committed name git would C-quote passes once
  reverted, and blocks (for every persona) only while it still differs;
- names one restore command per blocked path: `git checkout <baseline> -- <path>` for a file that existed at
  the baseline, `git rm -qf -- <path>` for one the writer added to the index, `rm -- <path>` for one never
  added.
`docs/trust-model.md` row 26 states the new attribution and exactly what stays uncovered.

## Retrieval
Fast path, no tracker issue. Spec: `docs/plans/antislop-review-patches/spec.md`, "Step 12 (rp-u15)" and
Context "st-u3 review notes". This file is the contract of record. Dispatch it right after st-u4 reaches PASS
(Dispatch section); operator step O1 (st-u3 contract, `operator-step-O1:`) waits for this unit's PASS.

## Affected files
- `tests/writer-scope-gate.test.sh` (anchor: line matching `[ "$rc" = 2 ] && ok "(q) C-quoted committed path blocked" || bad "(q) rc=$rc $err"`)
- `hooks/scripts/writer-scope-gate.sh` (anchors: line matching `#!/usr/bin/env bash`; line matching `W="$(mktemp -d)"; trap 'rm -rf "$W"' EXIT`; line matching `top="$(pwd -P)"`; line matching `      case "$(us_classify "$p" "$start" "$W/listed" /dev/null "$W/crit" "$W/failrec")" in out) return 1 ;; *) return 0 ;; esac ;;`; line matching `viol=()`)
- `docs/trust-model.md` (anchor: line matching `| 26 | A writing persona (lead-programmer, scribe, spec-master) ends its turn`)
- `.claude-plugin/plugin.json`, `package.json`, `CHANGELOG.md`
- generated only, by `node bin/cli.js --update`: `.claude/hooks/scripts/writer-scope-gate.sh`, `.claude/agents/*.md`,
  `.claude/persona-protocol*.md` and `.claude/protocol-digest.md` (version stamps only), the config's
  `fileHashes` and `pluginVersion`

## Ordered edits
1. file: `tests/writer-scope-gate.test.sh`
   anchor: line matching `[ "$rc" = 2 ] && ok "(q) C-quoted committed path blocked" || bad "(q) rc=$rc $err"`
   indent: 0
   before:
~~~
[ "$rc" = 2 ] && ok "(q) C-quoted committed path blocked" || bad "(q) rc=$rc $err"
g reset -q --hard HEAD~1
~~~
   after:
~~~
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
~~~
2. command: `bash -c 'bash tests/writer-scope-gate.test.sh | grep -c "^FAIL"'`
   expect: 0
   The red step: it prints `13` (the (r) no-commit-line, three (s), (t), (u), two (v), (w), (x), (y) and two (z)
   rows fail against st-u3's gate).
3. file: `hooks/scripts/writer-scope-gate.sh`
   anchor: line matching `#!/usr/bin/env bash` (the header, the input and identity checks and the library sourcing, down to the transcript check)
   indent: 0
   before:
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
# explicit checks, so errexit is switched back off, before the two libraries below are
# sourced (a missing one must reach the `declare -F` check, not exit 1 under errexit).
set +e
# state-access.sh owns the unit-id grammar (UNIT_ID_CHARCLASS, unit_id_valid, unit_id_sanitize;
# tests/state-access-constraints.test.sh M5 allows no second spelling under hooks/scripts/).
{ . "$(dirname "${BASH_SOURCE[0]}")/lib/state-access.sh" && . "$(dirname "${BASH_SOURCE[0]}")/lib/unit-scope.sh"; } >/dev/null 2>&1 || true
# state-access.sh turns errexit on again when sourced (hence `|| true` above: a missing
# unit-scope.sh must not end the gate with exit 1, which Claude Code reads as allow).
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
agent_id="$(unit_id_sanitize "$(printf '%s' "$input" | jq -r '.agent_id // "unknown"' 2>/dev/null)" 2>/dev/null)"
tr_path="$(printf '%s' "$input" | jq -r '.agent_transcript_path // empty' 2>/dev/null)"
cd "$project_dir" 2>/dev/null || allow
git rev-parse --verify -q HEAD >/dev/null || allow
log() { mkdir -p "$dot/bookkeeping" && printf '%s agent=%s persona=%s %s\n' "$(date -u +%Y-%m-%dT%H:%M:%SZ)" "$agent_id" "$persona" "$1" >> "$dot/bookkeeping/scope-gate.log"; }
# A missing, empty or cut-short library would make every path look in scope (an undefined function
# only reads as "false"), so the writer's stop fails closed until the library is restored.
if ! declare -F us_section us_entries us_exclusions us_excluded us_listed us_named_in us_classify unit_id_valid unit_id_sanitize >/dev/null; then
  log "blocked: unit-scope library unavailable"
  echo "BLOCKED (writer-scope-gate): hooks/scripts/lib/unit-scope.sh is missing or incomplete (or state-access.sh is), so your changes cannot be checked against your unit scope. Report this block to your dispatcher and wait; do not edit the library." >&2
  exit 2
fi
if [ -z "$tr_path" ] || [ ! -r "$tr_path" ]; then log "unattributable: no transcript"; allow; fi
~~~
   after:
~~~
#!/usr/bin/env bash
# writer-scope-gate.sh (st-u3, hardened by rp-u15): SubagentStop gate for the three writing
# personas (lead-programmer, scribe, spec-master). It attributes changed paths from the
# subagent's OWN transcript (Write/Edit file paths, plus the files of every commit
# whose `[<branch> <sha>]` line appears in a Bash result), keeps the ones whose net
# content still differs from where the subagent started (the last commit before its
# transcript's first timestamp), and blocks the stop
# (exit 2, reason on stderr) when one of them is outside the dispatch's unit scope.
# Claude-only: it needs agent_transcript_path. Reads only; its one write is a log
# line in .claude/bookkeeping/scope-gate.log (gitignored since qw-u1).
set -uo pipefail
here="$(dirname "${BASH_SOURCE[0]}")"
allow() { exit 0; }
input="$(cat)"
# jq is a hard dependency of every hook (README). Without it the gate cannot tell which persona
# stopped, so a block would stop every subagent: it allows, logs and says so (rp-u15).
if ! command -v jq >/dev/null 2>&1; then
  d="${CLAUDE_PROJECT_DIR:-$PWD}/.claude"
  [ -d "$d" ] && { mkdir -p "$d/bookkeeping" && printf '%s agent=unknown persona=unknown unattributable: jq missing\n' "$(date -u +%Y-%m-%dT%H:%M:%SZ)" >> "$d/bookkeeping/scope-gate.log"; } 2>/dev/null
  echo "writer-scope-gate: jq is not installed, so no writer's unit scope is checked; install it (README: every hook needs jq)." >&2
  allow
fi
at="$(printf '%s' "$input" | jq -r '.agent_type // empty' 2>/dev/null)"
tr_path="$(printf '%s' "$input" | jq -r '.agent_transcript_path // empty' 2>/dev/null)"
# A named dispatch reports its dispatch name as agent_type; the transcript's sibling .meta.json
# records the persona it runs as agentType, so either one naming a writer gates the stop.
mt=""; [ -z "$tr_path" ] || mt="$(jq -r '.agentType // empty' "${tr_path%.jsonl}.meta.json" 2>/dev/null)"
# writer_of <persona name>: the writer it names, also with the harness's `-<n>` collision suffix.
writer_of() { [[ ${1-} =~ ^(lead-programmer|scribe|spec-master)(-[0-9]+)?$ ]] && printf '%s' "${BASH_REMATCH[1]}"; }
guess="$(writer_of "${at##*:}")$(writer_of "${mt##*:}")"
# A library that runs `exit` while it is sourced would end the gate with its status (0 is an
# allow), so an EXIT trap turns that into a block for a writer until sourcing is done.
# fd 3 keeps stderr: the trap runs inside the group's `>/dev/null 2>&1`.
sourced=0; exec 3>&2
trap '[ "$sourced" = 1 ] || [ -z "$guess" ] || { echo "BLOCKED (writer-scope-gate): a library under hooks/scripts/lib/ ended the gate while it was being sourced, so your changes cannot be checked against your unit scope. Report this block to your dispatcher and wait; do not edit the library." >&3; exit 2; }' EXIT
# agent-identity.sh (through audit-log.sh) and state-access.sh turn on `set -e` when sourced; this
# gate decides by explicit checks, so errexit is switched off after the group. `|| true`: a missing
# library must reach the `declare -F` check below, not exit 1, which Claude Code reads as allow.
# state-access.sh owns the unit-id grammar (UNIT_ID_CHARCLASS, unit_id_valid, unit_id_sanitize;
# tests/state-access-constraints.test.sh M5 allows no second spelling under hooks/scripts/).
{ . "$here/lib/agent-identity.sh" && . "$here/lib/state-access.sh" && . "$here/lib/unit-scope.sh"; } >/dev/null 2>&1 || true
set +e
sourced=1; trap - EXIT; exec 3>&-

project_dir="${CLAUDE_PROJECT_DIR:-$(printf '%s' "$input" | jq -r '.cwd // empty' 2>/dev/null)}"
[ -n "$project_dir" ] || project_dir="$PWD"
dot="${project_dir}/.claude"
config="${dot}/persona-config.json"
[ -f "$config" ] || allow
[ "$(printf '%s' "$input" | jq -r '.hook_event_name // empty' 2>/dev/null)" = SubagentStop ] || allow
# Policy: the exact persona name, its namespaced form (identity_persona_name) and the `-<n>` suffix are
# gated; `Lead-Programmer` or a trailing space are not values the harness emits.
pn() { if declare -F identity_persona_name >/dev/null; then identity_persona_name "$1"; else printf '%s' "${1##*:}"; fi; }
persona="$(writer_of "$(pn "$at")")"; [ -n "$persona" ] || persona="$(writer_of "$(pn "$mt")")"
[ -n "$persona" ] || allow
agent_id="$(unit_id_sanitize "$(printf '%s' "$input" | jq -r '.agent_id // "unknown"' 2>/dev/null)" 2>/dev/null)"
cd "$project_dir" 2>/dev/null || allow
git rev-parse --verify -q HEAD >/dev/null || allow
log() { mkdir -p "$dot/bookkeeping" && printf '%s agent=%s persona=%s %s\n' "$(date -u +%Y-%m-%dT%H:%M:%SZ)" "$agent_id" "$persona" "$1" >> "$dot/bookkeeping/scope-gate.log"; }
# A missing, empty or cut-short library would make every path look in scope (an undefined function
# only reads as "false"), so the writer's stop fails closed until the library is restored.
if ! declare -F identity_persona_name us_section us_entries us_exclusions us_excluded us_listed us_named_in us_classify unit_id_valid unit_id_sanitize >/dev/null; then
  log "blocked: unit-scope library unavailable"
  echo "BLOCKED (writer-scope-gate): hooks/scripts/lib/unit-scope.sh is missing or incomplete (or state-access.sh or agent-identity.sh is), so your changes cannot be checked against your unit scope. Report this block to your dispatcher and wait; do not edit the library." >&2
  exit 2
fi
if [ -z "$tr_path" ] || [ ! -e "$tr_path" ]; then log "unattributable: no transcript"; allow; fi
~~~
4. file: `hooks/scripts/writer-scope-gate.sh`
   anchor: line matching `W="$(mktemp -d)"; trap 'rm -rf "$W"' EXIT` (the transcript parse)
   indent: 0
   before:
~~~
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
~~~
   after:
~~~
W="$(mktemp -d)"; trap 'rm -rf "$W"' EXIT
# Each line is parsed on its own: a malformed or cut-off line is skipped, never the whole file. A
# transcript with no readable record (a directory, a foreign format) blocks the writer's stop.
jq -cR 'fromjson? | select(type == "object")' "$tr_path" > "$W/tr" 2>/dev/null
if [ ! -s "$W/tr" ]; then
  log "blocked: transcript unreadable"
  echo "BLOCKED (writer-scope-gate): your transcript ($tr_path) has no record this gate can read, so your changes cannot be checked against your unit scope. Report this block to your dispatcher and wait." >&2
  exit 2
fi
bad=$(( $(grep -c . "$tr_path" 2>/dev/null) - $(wc -l < "$W/tr") ))
[ "$bad" -le 0 ] || log "skipped: $bad malformed transcript line(s)"
jq -rs 'try (map(select(.type == "user"))[0].message.content
        | if type == "string" then . else (map(select(.type? == "text") | .text) | join("\n")) end) catch ""' \
  "$W/tr" > "$W/prompt" 2>/dev/null
jq -j 'try (select(.type == "assistant") | .message.content[]?
       | select(type == "object" and .type == "tool_use" and (.name == "Write" or .name == "Edit" or .name == "NotebookEdit"))
       | (.input.file_path // .input.notebook_path // empty) | strings | . + "\u0000") catch empty' "$W/tr" > "$W/abs" 2>/dev/null
jq -r 'try (select(.type == "user") | .message.content[]?
       | select(type == "object" and .type == "tool_result") | .content
       | if type == "string" then . else (map(select(.type? == "text") | .text) | join("\n")) end) catch empty' "$W/tr" 2>/dev/null \
  | grep -oE '^\[[^]]* [0-9a-f]{7,40}\]' | grep -oE '[0-9a-f]{7,40}\]$' | tr -d ']' > "$W/shas" || true
t0="$(jq -r 'try (.timestamp | strings) catch empty' "$W/tr" 2>/dev/null | head -n1)"
~~~
5. file: `hooks/scripts/writer-scope-gate.sh`
   anchor: line matching `top="$(pwd -P)"` (the candidate paths and the baseline)
   indent: 0
   before:
~~~
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
~~~
   after:
~~~
# canon <absolute path>: norm_abs, then the directory's symlinks resolved (pwd -P), so an edit made
# through a symlinked project path is judged as the file it names (rp-u15). The file name itself is
# kept: an edit through a symlinked file changes the link's target, not the link.
canon() {
  local a d; a="$(norm_abs "$1")"; d="${a%/*}"; [ -n "$d" ] || d=/
  [ -d "$d" ] && d="$(cd "$d" 2>/dev/null && pwd -P)" && a="${d%/}/${a##*/}"
  printf '%s' "$a"
}
top="$(pwd -P)"
pd="$(norm_abs "$project_dir")"
: > "$W/cand"
while IFS= read -r -d '' a; do
  [ -n "$a" ] || continue
  a="$(canon "$a")"
  case "$a" in "$top"/*) printf '%s\0' "${a#"$top"/}" >> "$W/cand" ;; "$pd"/*) printf '%s\0' "${a#"$pd"/}" >> "$W/cand" ;; esac
done < "$W/abs"
# The baseline is the last commit on HEAD's first-parent line before the transcript's first
# timestamp, so a Write/Edit path the writer committed is judged even when no commit line shows
# (rp-u15). A commit line still proves the commit is the writer's: the baseline is then also no
# later than that commit's parent. No timestamp and no commit line: HEAD (logged).
first=""
while IFS= read -r s; do
  git cat-file -e "$s^{commit}" 2>/dev/null || continue
  [ -n "$first" ] || first="$(git rev-parse -q --verify "$s^" 2>/dev/null || git hash-object -t tree /dev/null)"
  git show --no-renames --name-only -z --format= "$s" >> "$W/cand"
done < "$W/shas"
start=""
if [ -n "$t0" ]; then
  start="$(git rev-list -1 --first-parent --before="$t0" HEAD 2>/dev/null)"
  [ -n "$start" ] || start="$(git hash-object -t tree /dev/null)"
fi
if [ -n "$first" ] && [ -n "$start" ]; then
  start="$(git merge-base "$start" "$first" 2>/dev/null || printf '%s' "$first")"
elif [ -n "$first" ]; then
  start="$first"
elif [ -z "$start" ]; then
  start="HEAD"; log "baseline: HEAD (no timestamp and no commit line)"
fi
~~~
6. file: `hooks/scripts/writer-scope-gate.sh`
   anchor: line matching `      case "$(us_classify "$p" "$start" "$W/listed" /dev/null "$W/crit" "$W/failrec")" in out) return 1 ;; *) return 0 ;; esac ;;` (the lead-programmer `us_classify` line)
   indent: 0
   before:
~~~
      case "$(us_classify "$p" "$start" "$W/listed" /dev/null "$W/crit" "$W/failrec")" in out) return 1 ;; *) return 0 ;; esac ;;
~~~
   after:
~~~
      # Only the classes us_classify names as in scope count; `out`, `excluded`, empty or any other
      # output is out (rp-u15).
      case "$(us_classify "$p" "$start" "$W/listed" /dev/null "$W/crit" "$W/failrec")" in
        listed|criteria|fail-record|fix-contract|plugin-version|judge) return 0 ;; *) return 1 ;;
      esac ;;
~~~
7. file: `hooks/scripts/writer-scope-gate.sh`
   anchor: line matching `viol=()` (the judging loop and the block message)
   indent: 0
   before:
~~~
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
   after:
~~~
viol=()
while IFS= read -r -d '' p; do
  [ -n "$p" ] || continue
  if git ls-files --error-unmatch -- "$p" >/dev/null 2>&1 || git cat-file -e "$start:$p" 2>/dev/null; then
    git diff --quiet "$start" -- "$p" 2>/dev/null && continue
  else
    [ -e "$p" ] || continue
    # An untracked file git ignores (a microworlds/<slug>/ bundle, scratch) never ships (rp-u15).
    git check-ignore -q -- "$p" 2>/dev/null && continue
  fi
  # A name holding a quote, a backslash or a control character cannot be judged (review-precheck
  # fails it as `unquotable`): while it still differs it is out of scope for every persona.
  case "$p" in *'"'*|*'\'*|*[[:cntrl:]]*) viol+=("$p"); continue ;; esac
  in_scope "$p" || viol+=("$p")
done < <(sort -zu "$W/cand")
[ "${#viol[@]}" -eq 0 ] && allow
shown=(); for p in "${viol[@]}"; do shown+=("$(printf '%q' "$p")"); done
log "blocked: ${shown[*]}"
{
  echo "BLOCKED (writer-scope-gate): you left changes outside your dispatch's unit scope: ${shown[*]}."
  echo "Restore each one, and commit if you had committed it:"
  for p in "${viol[@]}"; do
    q="$(printf '%q' "$p")"
    if git cat-file -e "$start:$p" 2>/dev/null; then echo "  git checkout $start -- $q"
    elif git ls-files --error-unmatch -- "$p" >/dev/null 2>&1; then echo "  git rm -qf -- $q   (a file you added)"
    else echo "  rm -- $q   (a new file you never added)"
    fi
  done
  echo "Then report the change under \`Proposed out-of-scope changes:\` (or \`Knowledge proposals:\`) instead of applying it. In scope: the dispatch's \`## Affected files\` and your persona's standing exceptions; knowledge files (CONTEXT.md, README.md, docs/harness-glossary.md, docs/adr/) need knowledgeWrites \"apply\" or a dispatch that lists or names them."
} >&2
exit 2
~~~
8. command: `bash -c 'test -x hooks/scripts/writer-scope-gate.sh && bash tests/writer-scope-gate.test.sh | grep -c "^FAIL"'`
   expect: 1
   `grep -c` prints `0` (no FAIL line) and exits 1. The file keeps mode 755 (hooks.json runs it directly).
9. file: `docs/trust-model.md`
   anchor: line matching `| 26 | A writing persona (lead-programmer, scribe, spec-master) ends its turn`
   indent: 0
   before:
~~~
| 26 | A writing persona (lead-programmer, scribe, spec-master) ends its turn with no net change outside its dispatch's unit scope | lead-programmer, scribe, spec-master | `hooks/scripts/writer-scope-gate.sh` | SubagentStop gate (unit st-u3). Attributes paths from the subagent's own transcript (Write/Edit file paths, plus the files of each commit whose `[<branch> <sha>]` line it saw), so a concurrent writer is never blamed; Write/Edit paths are normalised lexically before they are judged; a Bash write that never went through Write/Edit and was never committed is not attributed (residual). A missing transcript is allowed and logged to `.claude/bookkeeping/scope-gate.log`. |
~~~
   after:
~~~
| 26 | A writing persona (lead-programmer, scribe, spec-master) ends its turn with no net change outside its dispatch's unit scope | lead-programmer, scribe, spec-master | `hooks/scripts/writer-scope-gate.sh` | SubagentStop gate (units st-u3, rp-u15). Attributes paths from the subagent's own transcript (its Write/Edit/NotebookEdit file paths, plus the files of each commit whose `[<branch> <sha>]` line it saw), so another session's commit is blamed only for a path this subagent also wrote. Each path is judged by its net content against the baseline: the last commit on HEAD's first-parent line before the transcript's first timestamp, and no later than the parent of the first commit line it saw. So a Write/Edit change the subagent committed is judged whether or not its commit line shows. Paths are normalised lexically and through their directory's symlinks; an untracked gitignored file is skipped; a named dispatch is gated through its transcript's `.meta.json` `agentType`. Residual: a file written only by Bash (never through Write/Edit) is attributed only through a visible commit line, so one left uncommitted, or committed with no commit line in the transcript (`-q`, redirected output), is not checked. A missing transcript or a missing `jq` is allowed and logged to `.claude/bookkeeping/scope-gate.log`; a transcript with no readable record, or a library that is incomplete or ends the gate while sourced, blocks the writer. |
~~~
10. command: `perl -0pi -e 's/("version": "\d+\.\d+\.)(\d+)"/$1.($2+1)."\""/e' .claude-plugin/plugin.json package.json`
   expect: 0
   This adds one to the patch version in both files (expected 0.31.205 to 0.31.206). The bump is required:
   `--update` installs a changed hook script only when `pluginVersion` moves.
11. file: `CHANGELOG.md`
   anchor: line matching `## [Unreleased]`
   indent: 0
   insert-after:
~~~

**Writer scope gate hardening (rp-u15, VERSION).** `hooks/scripts/writer-scope-gate.sh` (registered by the operator's step O1 only after this unit): a Write/Edit path is judged against the last commit before the transcript's first timestamp, so a committed out-of-scope edit blocks with or without a visible commit line; each transcript line is parsed on its own (a malformed or cut-off line is skipped, a transcript with no readable record blocks); a library that ends the gate while sourced, or a `us_classify` result outside the in-scope classes, blocks; edits through a symlinked project path are resolved; a `-<n>` suffixed name or a named dispatch (through its `.meta.json`) is gated; untracked gitignored files (microworld bundles) are skipped; a reverted C-quoted committed name passes; the block names a restore command per path (`git checkout <baseline> --`, `git rm -qf --` or `rm --`). A missing `jq` is allowed with a warning and a log line. docs/trust-model.md row 26 states the residual. tests/writer-scope-gate.test.sh cases (r) to (z).
~~~
   Replace `VERSION` with the version that edit 10 wrote.
12. command: `node bin/cli.js --update`
   expect: 0
13. command: `git add tests/writer-scope-gate.test.sh hooks/scripts/writer-scope-gate.sh docs/trust-model.md .claude/hooks/scripts/writer-scope-gate.sh && git add -u && git commit -m "fix(rp-u15): writer scope gate judges committed edits without a commit line and fails closed on unreadable input"`
   expect: 0
   Run `git status --short` first: if a tracked file outside "Affected files" is modified, stop and report it.

## Do NOT touch
- `hooks/hooks.json` (the registration is the operator's step O1, held until this unit's PASS; no agent identity may write it; criterion 6)
- `hooks/scripts/lib/unit-scope.sh`, `hooks/scripts/lib/state-access.sh` and `hooks/scripts/lib/agent-identity.sh` (the gate only sources them; rp-u13 edits unit-scope.sh; criterion 6)
- `tests/validate.sh` (it has run the test since st-u3; st-u4 anchors that section's echo line; criterion 6)
- `adapters/`, `agents/` and `templates/` (Claude-only gate; its block message is the instruction; criterion 6)
- `.claude/hooks/` by hand (only `node bin/cli.js --update` writes it; criterion 2)

## Acceptance criteria
1. run: `bash -c 'bash tests/writer-scope-gate.test.sh >/dev/null; echo $?'`
   exit: 0
   stdout: `0`
   mutation: change `if [ -n "$t0" ]; then` to `if false; then`; `(r) no commit line` fails and stdout is `1`. Each of these also fails its case (spec-master ran all twelve on a clone): `jq -cR 'fromjson? | select(type == "object")'` to `jq -c '.'` fails (s) malformed; `if [ ! -s "$W/tr" ]; then` to `if false; then` fails (s) unreadable and directory; the jq-missing `echo` to `:` fails (t); `a="$(canon "$a")"` to `a="$(norm_abs "$a")"` fails (u); deleting `(-[0-9]+)?` fails (v) suffix; `mt=""; [ -z "$tr_path" ] || mt=` to `mt=""; false && mt=` fails (v) meta; the in-scope class list to `out) return 1 ;; *) return 0 ;;` fails (w); `trap` to `true` on the sourcing trap line fails (x); deleting the `git check-ignore` line fails (y); a `case "$p" in *'"'*) viol+=("$p"); continue ;; esac` line above `if git ls-files` fails (z) reverted; the old `git rm a file you added` wording fails (z) message.
2. run: `bash -c 'cmp hooks/scripts/writer-scope-gate.sh .claude/hooks/scripts/writer-scope-gate.sh && test -x .claude/hooks/scripts/writer-scope-gate.sh && echo same'`
   exit: 0
   stdout: `same`
   mutation: skip edit 12 (`--update`); this unit bumps the version, so without it the installed copy stays st-u3's, `cmp` reports a difference and the command exits 1.
3. run: `bash -c 'node tests/trust-model-bijection.test.js >/dev/null 2>&1 && node tests/cli-hook-propagation.test.js >/dev/null 2>&1 && bash tests/harness-integrity-gate.test.sh >/dev/null 2>&1 && bash tests/state-access-constraints.test.sh >/dev/null 2>&1 && bash tests/scope-libs.test.sh >/dev/null 2>&1 && bash tests/abtest-arms.test.sh >/dev/null 2>&1; echo $?'` (Bash tool timeout 600000 ms)
   exit: 0
   stdout: `0`
   mutation: delete row 26 from `docs/trust-model.md`; trust-model-bijection C8.2 (every hooks/scripts/*.sh is in the table) fails and stdout is `1`. abtest-arms reads `git archive HEAD`, so run this after edit 13.
4. run: `bash -c 't=$(grep "^| 26 |" docs/trust-model.md | tr -s " \n" " "); n=0; for p in "units st-u3, rp-u15" "before the transcript'"'"'s first timestamp" "whether or not its commit line shows" "Residual: a file written only by Bash (never through Write/Edit) is attributed only through a visible commit line" "committed with no commit line in the transcript" "A missing transcript or a missing \`jq\` is allowed" "a transcript with no readable record, or a library that is incomplete or ends the gate while sourced, blocks the writer"; do printf "%s" "$t" | grep -qF -- "$p" && n=$((n+1)); done; echo $n'`
   exit: 0
   stdout: `7`
   mutation: skip edit 9; stdout is `0`.
5. run: `bash -c 'b=$(git log --format=%H --grep="^[a-z]*(rp-u15): " | tail -1); l=$(git log --format=%H --grep="^[a-z]*(rp-u15): " | head -1); git diff --name-only "$b^..$l" -- . ":(exclude).claude" | LC_ALL=C sort | tr "\n" " "'`
   exit: 0
   stdout: `.claude-plugin/plugin.json CHANGELOG.md docs/trust-model.md hooks/scripts/writer-scope-gate.sh package.json tests/writer-scope-gate.test.sh `
   mutation: also edit `tests/validate.sh` in an rp-u15 commit; it joins the list.
6. run: `bash -c 'b=$(git log --format=%H --grep="^[a-z]*(rp-u15): " | tail -1); l=$(git log --format=%H --grep="^[a-z]*(rp-u15): " | head -1); git diff --name-only "$b^..$l" -- hooks/hooks.json hooks/scripts/lib tests/validate.sh adapters agents templates | wc -l'`
   exit: 0
   stdout: `0`
   mutation: register the gate in `hooks/hooks.json` in an rp-u15 commit (the operator's O1, done by the lead); stdout is `1`.
7. run: `bash -c 'b=$(git log --format=%H --grep="^[a-z]*(rp-u15): " | tail -1); l=$(git log --format=%H --grep="^[a-z]*(rp-u15): " | head -1); test "$(git show "$b^:.claude-plugin/plugin.json" | grep "\"version\"")" != "$(git show "$l:.claude-plugin/plugin.json" | grep "\"version\"")" && test "$(git show "$l:CHANGELOG.md" | grep -c "(rp-u15, ")" = 1 && echo moved'`
   exit: 0
   stdout: `moved`
   mutation: skip edit 10; the versions are equal, stdout is empty and the exit is 1.
8. run: `bash -c 'bash tests/validate.sh >/dev/null 2>&1; echo $?'` (Bash tool timeout 600000 ms)
   exit: 0
   stdout: `0`
   mutation: put `exit 1` as line 2 of tests/writer-scope-gate.test.sh; validate.sh exits 1 and stdout is `1`.

## Pre-resolved context
tdd: yes edit 1 adds cases (r) to (z) from fixture transcripts (no live agent); edit 2 shows them red (`13`) against st-u3's gate before edits 3 to 7.
evidence: verified 2026-10-22 against abc6d195 (0.31.204) on a scratch clone, each with an out-of-scope change standing (want: exit 2): committed CONTEXT.md Edit with no commit line exit 0, with one exit 2 (G1); a cut-off last line exit 0 (G2); a directory as transcript exit 0; `jq` absent from PATH exit 0; Edit through a symlink to the project exit 0; `agent_type` `lead-programmer-2` exit 0 (G3); a gitignored `microworlds/x/run.sh` Write exit 2 and a C-quoted committed name removed by a later commit exit 2 (G4, want 0). `us_classify` with any output but `out` and a library `exit 0` while sourced are allows by the code (`*) return 0`; sourcing at top level) and are now pinned by (w) and (x). Corpus: 386 of 405 real lead-programmer transcripts ran `git commit`; 144 of them show no commit line (the reviewer's figure, reproduced). Every writer transcript's first record carries `timestamp` (0 of 690 without).
payload-fields: the SubagentStop input carries `agent_id`, `agent_type`, `agent_transcript_path`, `cwd`, `session_id`, `transcript_path`, `stop_hook_active`, `last_assistant_message` (docs/experiments/2026-07-probe-hook-payloads.md); no start commit. The transcript's records carry `timestamp`, `cwd`, `gitBranch` but no sha; `<transcript>.meta.json` (sibling, `.jsonl` replaced) carries `agentType`, the persona type, for every one of this repo's 1584 subagent transcripts.
baseline-decision: the last commit on HEAD's first-parent line with a committer date at or before the transcript's first `timestamp` (`git rev-list -1 --first-parent --before=<t0> HEAD`; git parses the millisecond ISO form), or the empty tree when none is that old; a visible commit line moves it back to `git merge-base` with that commit's parent. Only the writer's own Write/Edit paths and commit-line files are judged against it, so a concurrent session's later commit is blamed only for a path this writer also wrote (case (r), README row). No timestamp and no commit line (a fixture, never a real transcript): HEAD, logged `baseline: HEAD`. Reflog (`HEAD@{<date>}`) was rejected: it is absent in some clones and silently returns its oldest entry when the date predates it. The session baseline commit (`.claude/.session-baseline.<session_id>`) was rejected too: it predates every earlier unit of the session, so a path an earlier unit changed, which this writer touched and restored, would block.
parse-decision: line by line, skip and log `skipped: <n> malformed transcript line(s)`; total parse failure (the path exists but no record parses) blocks the writer with a report-and-wait message. A missing path stays a logged allow (st-u3 ruling: older harness or adapter).
jq-decision: loud allow. README line 44 makes jq a hard requirement ("every hook needs it"); `bin/cli.js` does not check for it. Without jq the gate cannot read `agent_type`, so a block would hit every subagent (reviewer and explorer included). Recovery: the operator installs jq; the log line `unattributable: jq missing` and the stderr warning say why nothing was gated.
loop-bound: every new block (unreadable transcript, library exit, a standing out-of-scope path) repeats on each stop while it stands; Claude Code ends a stop-hook loop after 8 continuations, so a writer that cannot clear it (it must not edit the library or the transcript) spends up to 8 turns reporting, then stops. Operator recovery: read `.claude/bookkeeping/scope-gate.log`, restore the library or fix the cause, or revert the O1 registration line until fixed.
identity-decision: real harness values are the bare persona name (unnamed dispatch), the `antislop:` form (plugin namespace), a `-<n>` suffix on a name collision and any dispatch name for a named dispatch (agent-identity memory, 2026-08-09); case and whitespace variants are not emitted, because agent names are lowercase-hyphen identifiers. The meta check only adds gating: a writer whose meta names another persona is still gated by its `agent_type`.
classify-decision: us_classify prints one of `out`, `excluded`, `listed`, `criteria`, `fail-record`, `fix-contract`, `plugin-version`, `judge` (hooks/scripts/lib/unit-scope.sh:157-168); the last six are in scope, the gate passes no exclusion file, so `excluded` cannot occur today and is out if it ever does.
contracts-before-rp-u9: (finding G5) document only, no gate change and no glossary line. abt-u21a and its fix4 to fix6 contracts restrict `tests/validate.sh` inside a Do NOT touch bullet without `partial:`, so `us_exclusions` (and review-precheck) read the whole file as excluded; those units landed, and a re-dispatch must add `partial:` first. Recorded in the spec's Context.
chained: spec-master applied st-u4 (its "eight to nine helpers" prose edit by hand), this contract, rp-u10, rp-u12, rp-u7, rp-u4, rp-u5, rp-u6, rp-u13 and rp-u14 in that order to a fresh clone of the current master with an applier that requires each `before:` payload once and each command's exit as stated, and ran every contract's criteria 1 to n-1 right after its commit (see the spec's Dispatch section). No queued contract edits the gate, its test or row 26; st-u4 anchors the validate.sh echo line this unit leaves alone; rp-u13 changes `us_exclusions`, which no new case uses.
blast-radius: hooks/scripts/writer-scope-gate.sh:1-140 (the whole file), tests/writer-scope-gate.test.sh:187-188 (end of case (q)), docs/trust-model.md:64 (row 26), tests/trust-model-bijection.test.js:63 (C8.2), tests/validate.sh:795 (the section that runs the test, unchanged), hooks/hooks.json:47-53 (SubagentStop, unchanged until O1). Line numbers are at abc6d195.
version: .claude-plugin/plugin.json and package.json read 0.31.205 after st-u4 if no fix round bumped; edit 10 adds one (expected 0.31.206).
mirrors: `.claude/` copies change only through `node bin/cli.js --update` (constitution P2).
commit-message: fix(rp-u15): writer scope gate judges committed edits without a commit line and fails closed on unreadable input
diagnosis: none
review-packet:
~~~
unit: rp-u15
changed files: <FILL: changed files>
commit: <FILL: commit SHA>
criterion 1: <FILL: exit and stdout>
criterion 2: <FILL: exit and stdout>
criterion 3: <FILL: exit and stdout>
criterion 4: <FILL: exit and stdout>
criterion 5: <FILL: exit and stdout>
criterion 6: <FILL: exit and stdout>
criterion 7: <FILL: exit and stdout>
criterion 8: <FILL: exit and stdout>
~~~

## Escalation
If a `before:` payload is not found verbatim (the gate or its test is no longer st-u3's text), stop and
report the current text. If a case (a) to (q) changes result, quote it and stop. If `node bin/cli.js
--update` reports a mirror as diverged, quote it and stop. If a gate blocks a command, report it and wait.
Anything outside "Affected files" goes to your report as a proposal.
