#!/usr/bin/env bash
# Behavioral regression suite for hooks/scripts/harness-integrity-gate.sh
# (docs/plans/2026-08-25-harness-trust-gaps.md Step 2). Canned hook-input
# JSON piped over stdin, fixtures seeded under mktemp -d - no claude CLI, no
# network, no live dispatch. Same idiom as tests/human-decision-gate.test.sh.
#
# Fixture hygiene: this suite runs FROM validate.sh and must never invoke
# `bash tests/validate.sh` itself.
set -euo pipefail
cd "$(dirname "$0")/.."
unset CLAUDE_PLUGIN_ROOT || true
fail=0

gate="${GATE_UNDER_TEST:-hooks/scripts/harness-integrity-gate.sh}"

tmproot="$(mktemp -d)"
trap 'rm -rf "$tmproot"' EXIT
errf="$tmproot/stderr"
outf="$tmproot/stdout"

# Fixture literals for the two frozen permissionDecisionReason strings
# (Step 1). Held here, not derived from the gate, so a reworded prompt is a
# red test rather than a tautology.
ASK_REASON_A="This write targets the harness persona-selection config, a protected path with no grant branch. The sanctioned route is node bin/cli.js --update (install-antislop section 6). Approve only if you intend to take that route right now."
ASK_REASON_B="This write targets the harness gate registration surface: this gate script, its hooks.json registration, or the settings file that arms it. Approving this can disable every future prompt from this gate, including this one. Route changes through node bin/cli.js --update (install-antislop section 6)."

pass() { echo "OK   $*"; }
bad()  { echo "FAIL $*"; fail=1; }

mk() {
  local d="$tmproot/$1"
  mkdir -p "$d/.claude"
  printf '%s' "$d"
}
proj="$(mk proj)"

run() {
  rc=0
  : > "$errf"
  : > "$outf"
  printf '%s' "$1" | CLAUDE_PROJECT_DIR="$2" bash "$gate" >"$outf" 2>"$errf" || rc=$?
}

check() {
  if [ "$2" = allowed ]; then
    [ "$rc" = 0 ] && pass "$1 -> allowed" || bad "$1 -> rc=$rc, expected 0 (allowed)"
  elif [ "$rc" = 2 ] && [ -s "$errf" ]; then
    pass "$1 -> blocked"
  else
    bad "$1 -> rc=$rc with $(wc -c < "$errf") bytes of stderr, expected rc=2 and a reason"
  fi
}

# ask_check <label> <expected set A|B> - asserts THREE conditions: exit 0,
# stdout parses as JSON, and its permissionDecision/permissionDecisionReason
# match the expected set exactly. Exit 0 alone is not sufficient - an
# "allowed" result would pass that weaker check (C3.1).
ask_check() {
  local decision reason expected
  if [ "$rc" != 0 ]; then
    bad "$1 -> rc=$rc, expected 0 (ask)"
    return
  fi
  if ! jq -e . >/dev/null 2>&1 < "$outf"; then
    bad "$1 -> stdout did not parse as JSON: $(cat "$outf")"
    return
  fi
  decision="$(jq -r '.hookSpecificOutput.permissionDecision // empty' < "$outf")"
  if [ "$decision" != ask ]; then
    bad "$1 -> permissionDecision='$decision', expected ask"
    return
  fi
  [ "$2" = A ] && expected="$ASK_REASON_A" || expected="$ASK_REASON_B"
  reason="$(jq -r '.hookSpecificOutput.permissionDecisionReason // empty' < "$outf")"
  if [ "$reason" = "$expected" ]; then
    pass "$1 -> ask (set $2)"
  else
    bad "$1 -> permissionDecisionReason did not match set $2's fixture literal"
  fi
}

# _pm_payload <tool_name> <file_path> <permission_mode|__ABSENT__> <agent_id|__ABSENT__>
_pm_payload() {
  jq -n --arg t "$1" --arg p "$2" --arg pm "$3" --arg aid "$4" '
    {tool_name:$t, tool_input:{file_path:$p}}
    + (if $pm  == "__ABSENT__" then {} else {permission_mode:$pm}  end)
    + (if $aid == "__ABSENT__" then {} else {agent_id:$aid} end)
  '
}

# $1 label, $2 verdict, $3 file_path, $4 tool_name (Write|Edit), $5 project dir,
# $6 permission_mode (default: absent key), $7 agent_id (default: absent key)
write_case() {
  run "$(_pm_payload "$4" "$3" "${6:-__ABSENT__}" "${7:-__ABSENT__}")" "${5:-$proj}"
  check "$1" "$2"
}

# $1 label, $2 file_path, $3 tool_name (Write|Edit), $4 expected set (A|B),
# $5 permission_mode (default: "default"), $6 agent_id (default: absent key),
# $7 project dir
ask_case() {
  run "$(_pm_payload "$3" "$2" "${5:-default}" "${6:-__ABSENT__}")" "${7:-$proj}"
  ask_check "$1" "$4"
}

# $1 label, $2 verdict, $3 command, $4 project dir
bash_case() {
  run "$(jq -n --arg c "$3" '{tool_name:"Bash",tool_input:{command:$c}}')" \
      "${4:-$proj}"
  check "$1" "$2"
}

echo "-- Set A: denied on Write/Edit --"
write_case "case a Write .claude/persona-config.json" blocked \
  ".claude/persona-config.json" Write
write_case "case a2 Edit .claude/persona-config.json" blocked \
  ".claude/persona-config.json" Edit
write_case "case a3 Write .claude/review-audit.log" blocked \
  ".claude/review-audit.log" Write
write_case "case a4 Write .claude/dispatch-audit.log" blocked \
  ".claude/dispatch-audit.log" Write
write_case "case a5 Write .claude/microworld-audit.log" blocked \
  ".claude/microworld-audit.log" Write
write_case "case a6 Write .claude/wip-audit.log" blocked \
  ".claude/wip-audit.log" Write
write_case "case a7 Write .claude/review-audit.log.seal" blocked \
  ".claude/review-audit.log.seal" Write
write_case "case a8 Write unrelated .claude/agents/foo.md" allowed \
  ".claude/agents/foo.md" Write
write_case "case a9 Write empty file_path fails closed" blocked "" Write
write_case "case a10 Write .claude/settings.local.json (GUARD)" allowed \
  ".claude/settings.local.json" Write

echo
echo "-- Set A: denied on Bash --"
bash_case "case b1 rm -f .claude/persona-config.json" blocked \
  "rm -f .claude/persona-config.json"
bash_case "case b2 truncate review-audit.log" blocked \
  ": > .claude/review-audit.log"
bash_case "case b3 truncate dispatch-audit.log" blocked \
  ": > .claude/dispatch-audit.log"
bash_case "case b4 truncate microworld-audit.log" blocked \
  ": > .claude/microworld-audit.log"
bash_case "case b5 truncate wip-audit.log" blocked \
  ": > .claude/wip-audit.log"

echo
echo "-- Set A: Bash GUARDs (read-only carve-out) --"
bash_case "case c1 node bin/cli.js --update" allowed \
  "node bin/cli.js --update"
bash_case "case c2 cat persona-config.json" allowed \
  "cat .claude/persona-config.json"
bash_case "case c3 jq -r .gatedAgents persona-config.json" allowed \
  "jq -r .gatedAgents .claude/persona-config.json"

echo
echo "-- Set A: glob-pattern bypass closed (glob metachars must not evade normalize_path substring match) --"
bash_case "case h1 git add glob evading substring match (persona*.json)" blocked \
  "git add .claude/persona*.json"
bash_case "case h2 git add glob evading substring match (persona?config.json)" blocked \
  "git add .claude/persona?config.json"
bash_case "case h3 git add unrelated glob, no Set A match (agents/*.md)" allowed \
  "git add .claude/agents/*.md"

echo
echo "-- Set A: glob bypass stays closed for ALL nine literals when shell metacharacters sit flush against the pathspec --"
# h1/h2 above only cover one literal, with the glob as the final token and no
# adjacent punctuation. Chunking that splits on whitespace ALONE lets a single
# flush metachar (`;` `|` `>` `(` `)` `&`) carry into the chunk and defeat the
# glob match, so sweep every Set A literal x two glob spellings x six command
# shapes. Both spellings are chosen to contain no Set A literal as a substring
# (except the `.seal` members' tail-`?` form), so they exercise the glob path
# rather than the cheap substring cases above.
t_persona_cfg=".claude/persona-config.json"
t_review_log=".claude/review-audit.log"
t_dispatch_log=".claude/dispatch-audit.log"
t_microworld_log=".claude/microworld-audit.log"
t_wip_log=".claude/wip-audit.log"

for lit in "$t_persona_cfg" "$t_review_log" "$t_review_log.seal" \
           "$t_dispatch_log" "$t_dispatch_log.seal" \
           "$t_microworld_log" "$t_microworld_log.seal" \
           "$t_wip_log" "$t_wip_log.seal"; do
  leaked=0; leaks=""; total=0
  for g in "${lit%?}?" "${lit%%-*}*${lit##*.}"; do
    for cmd in "git add $g" "git add $g; git commit -m x" "git add $g|cat" \
               "git add $g>/dev/null" "(git add $g)" "rm -f $g && echo done"; do
      total=$((total + 1))
      run "$(jq -n --arg c "$cmd" '{tool_name:"Bash",tool_input:{command:$c}}')" "$proj"
      if [ "$rc" != 2 ]; then leaked=$((leaked + 1)); leaks="$leaks {$cmd}"; fi
    done
  done
  if [ "$leaked" = 0 ]; then
    pass "case h4 [$lit] all $total glob+metachar spellings blocked"
  else
    bad "case h4 [$lit] $leaked/$total glob+metachar spellings ALLOWED:$leaks"
  fi
done

echo
echo "-- Set A: escape/expansion spellings that name a protected file without spelling it --"
bash_case "case h5 backslash-escaped glob metachar (persona\\*.json)" blocked \
  "git add .claude/persona\\*.json"
bash_case "case h6 backslash-escaped glob, audit log" blocked \
  "rm -f .claude/review-audit\\*.log"
bash_case "case h7 brace expansion naming the protected config" blocked \
  "git add .claude/{persona-config,other}.json"
bash_case "case h8 brace expansion naming an audit log" blocked \
  "rm -f .claude/{review-audit,other}.log"
bash_case "case h9 brace expansion, no Set A match (agents/commands *.md)" allowed \
  "git add .claude/{agents,commands}/*.md"

echo
echo "-- Set A: glob spellings with junk to the LEFT of the pathspec (the == test anchors; the substring cases above do not) --"
bash_case "case h10 absolute-path glob" blocked \
  "git add /home/u/repo/.claude/persona*.json"
bash_case "case h11 absolute-path glob, audit log" blocked \
  "rm -f /home/u/repo/.claude/review-audit*.log"
bash_case "case h12 \$VAR-prefixed glob" blocked \
  "git add \$CLAUDE_PROJECT_DIR/.claude/persona*.json"
bash_case "case h13 assignment-prefixed glob" blocked \
  "F=.claude/persona*.json; git add \$F"
bash_case "case h14 absolute-path glob, no Set A match (agents/*.md)" allowed \
  "git add /home/u/repo/.claude/agents/*.md"
bash_case "case h15 .claude-lookalike directory, no Set A match" allowed \
  "grep -rn TODO docs/.claude-notes/*.json"

echo
echo "-- Family table: the frozen closure condition for the Bash-branch glob fallback --"
# Per docs/plans/2026-09-09-debug-spec-harness-integrity-gate-hardening.md.
# The closure condition for that fallback is THIS TABLE, not "no bypass
# exists" - the latter is an unbounded universal over arbitrary shell text
# that a single counterexample falsifies, and it cost the unit two FAIL
# cycles. Each row is either a closed family (BLOCKED), a documented residual
# (ALLOWED on purpose), or the one accepted over-block. A spelling outside
# the table is out of scope for the unit that froze it, not a silent gap.
# The slugs are the shared token with
# .claude/agent-memory/lead-programmer/project_harness_integrity_gate_persona_config_commit.md;
# parity in both directions is checked at the end of this section.
fam_rows="anchoring:closed
backslash-escape:closed
brace-depth1:closed
brace-nested:closed
prefixed-path:closed
hidden-claude-segment:residual
wd-relative:residual
foreign-claude-dir:overblock"

set_a_lits=(".claude/persona-config.json" \
  ".claude/review-audit.log" ".claude/review-audit.log.seal" \
  ".claude/dispatch-audit.log" ".claude/dispatch-audit.log.seal" \
  ".claude/microworld-audit.log" ".claude/microworld-audit.log.seal" \
  ".claude/wip-audit.log" ".claude/wip-audit.log.seal")

# Reachability fixture: a real git repo holding real Set A files, so that
# "this spelling reaches a protected file" is demonstrated by running the
# expansion rather than asserted in a comment.
reachdir="$tmproot/reach"
mkdir -p "$reachdir/.claude"
for _l in "${set_a_lits[@]}"; do : > "$reachdir/$_l"; done
git init -q "$reachdir" >/dev/null 2>&1 || true

seen_slugs=""

# Run snippet $1 with cwd=$reachdir; true when some output line names a Set A
# path outright, or as the tail of an absolute one. This is the reachability
# precondition: a BLOCKED row is credited as a closed bypass only once its
# spelling is PROVEN to reach a protected file. Its absence is what let a
# depth-1-only brace collapse hide behind 62 green syntactic examples.
reach_proves() {
  local out line l
  out="$( cd "$reachdir" && export CLAUDE_PROJECT_DIR="$reachdir" && eval "$1" 2>/dev/null )" || return 1
  [ -n "$out" ] || return 1
  while IFS= read -r line; do
    line="${line#add \'}"; line="${line%\'}"
    for l in "${set_a_lits[@]}"; do
      if [ "$line" = "$l" ] || [ "$line" != "${line%"/$l"}" ]; then return 0; fi
    done
  done <<< "$out"
  return 1
}

# $1 slug, $2 probe mode (expand|gitspec), $3 path expression, $4 command.
# The command must literally contain the probed expression, so the proof and
# the assertion cannot drift apart.
blocked_row() {
  local probe
  seen_slugs="$seen_slugs $1"
  case "$4" in
    *"$3"*) ;;
    *) bad "[$1] table defect: command does not contain the probed path expression '$3'"; return ;;
  esac
  case "$2" in
    expand)  probe="printf '%s\n' $3" ;;
    gitspec) probe="git add -n -f -- $3" ;;
    *) bad "[$1] table defect: unknown probe mode '$2'"; return ;;
  esac
  if ! reach_proves "$probe"; then
    bad "[$1] reachability precondition FAILED ($2: $3) - NOT credited as a closed bypass"
    return
  fi
  bash_case "[$1] $4" blocked "$4"
}

# ALLOWED on purpose. Characterization tests: they record a known, still-open
# hole so the documentation about it stays falsifiable. Never read these rows
# as desired behavior.
residual_row() {
  seen_slugs="$seen_slugs $1"
  bash_case "[$1] residual, ALLOWED by design: $2" allowed "$2"
}

# BLOCKED although it cannot reach this project's Set A at all - a
# fail-closed false positive that arrived with the re-anchoring which closed
# `prefixed-path`. Accepted deliberately and pinned here so it stays a
# choice rather than becoming an accident nobody made.
overblock_row() {
  seen_slugs="$seen_slugs $1"
  bash_case "[$1] accepted over-block: $2" blocked "$2"
}

blocked_row anchoring expand '.claude/persona*.json' 'git add .claude/persona*.json;'
blocked_row anchoring expand '.claude/persona*.json' 'git add .claude/persona*.json|cat'
blocked_row anchoring expand '.claude/persona*.json' 'git add .claude/persona*.json>/dev/null'
blocked_row anchoring expand '.claude/persona*.json' '(git add .claude/persona*.json)'
# Backslash-escaped: the shell hands the metachar through verbatim, so the
# reachability proof is git's OWN pathspec globbing, not shell expansion.
blocked_row backslash-escape gitspec '.claude/persona\*.json' 'git add .claude/persona\*.json'
blocked_row brace-depth1 expand '.claude/{persona-config,x}.json' 'git add .claude/{persona-config,x}.json'
blocked_row brace-depth1 expand '.claude/{review-audit,other}.log' 'rm -f .claude/{review-audit,other}.log'
blocked_row prefixed-path expand "$reachdir/.claude/persona*.json" "git add $reachdir/.claude/persona*.json"
blocked_row prefixed-path expand '$CLAUDE_PROJECT_DIR/.claude/persona*.json' 'git add $CLAUDE_PROJECT_DIR/.claude/persona*.json'
blocked_row prefixed-path expand '.claude/persona*.json' 'F=.claude/persona*.json; git add $F'
blocked_row brace-nested expand '.claude/{persona-config,{x,y}}.json' 'git add .claude/{persona-config,{x,y}}.json'
blocked_row brace-nested expand '.claude/{{persona-config,q},x}.json' 'git add .claude/{{persona-config,q},x}.json'
blocked_row brace-nested expand '.claude/{review-audit,{x,y}}.log' 'rm -f .claude/{review-audit,{x,y}}.log'

residual_row hidden-claude-segment 'rm -f .c*/persona-config.json'
residual_row wd-relative 'cd .claude; rm -f persona-config.json'
residual_row wd-relative 'cd .claude && git add persona*.json'
residual_row wd-relative 'git -C .claude add persona*.json'
residual_row wd-relative 'a=.claude; b=persona-config.json; git add $a/$b'

overblock_row foreign-claude-dir 'rm -rf ~/.claude/*'
overblock_row foreign-claude-dir 'rm -rf /tmp/x/.claude/*'

# The residual rows above are only honest if the holes they record are real.
if reach_proves 'printf "%s\n" .c*/persona-config.json'; then
  pass "[hidden-claude-segment] residual is a real hole: the spelling expands to a Set A path"
else
  bad "[hidden-claude-segment] residual reachability probe produced no Set A path - the row may be mis-stated"
fi
if reach_proves 'cd .claude && printf "%s\n" "$PWD/persona-config.json"'; then
  pass "[wd-relative] residual is a real hole: the spelling names a Set A path from the changed directory"
else
  bad "[wd-relative] residual reachability probe produced no Set A path - the row may be mis-stated"
fi

echo
echo "-- [brace-nested] normalizer property: the brace collapse reaches a fixpoint --"
# Examples alone cannot catch a transform that is correct at depth 1 and
# wrong at depth >=2 unless an example happens to use depth 2. The property
# that catches it in one line is an invariant on the transform's OUTPUT:
# after collapse the candidate contains no brace at all. Extracted from the
# gate's own source by sentinel comments, so this checks shipped code rather
# than a re-implementation of it.
collapse_src="$(awk '/# >>> brace-collapse/{f=1;next} /# <<< brace-collapse/{f=0} f' "$gate")"
if [ -z "$collapse_src" ]; then
  bad "[brace-nested] could not extract the brace-collapse block from $gate (sentinels '# >>> brace-collapse' / '# <<< brace-collapse' missing)"
else
  collapse() { local g="$1" pre="" post=""; eval "$collapse_src"; printf '%s' "$g"; }
  inv_bad=""
  for _c in ".claude/{persona-config,x}.json" \
            ".claude/{review-audit,other}.log" \
            ".claude/{persona-config,{x,y}}.json" \
            ".claude/{{persona-config,q},x}.json" \
            ".claude/{review-audit,{x,y}}.log" \
            ".claude/{agents,commands}/*.md" \
            ".claude/{a,{b,{c,d}}}/{e,{f,g}}.json" \
            ".claude/{{{a,b},c},{d,{e,f}}}.log" \
            ".claude/{a,{b,{c,{d,e}}}}-audit.log" \
            ".claude/weird{name.md" \
            ".claude/dangling}brace.json"; do
    _out="$(collapse "$_c")"
    case "$_out" in *[{}]*) inv_bad="$inv_bad {$_c -> $_out}" ;; esac
  done
  if [ -z "$inv_bad" ]; then
    pass "[brace-nested] post-collapse candidate contains no { and no } across all 11 brace inputs (incl. three depth>=3 nestings and two lone braces)"
  else
    bad "[brace-nested] post-collapse candidate still contains a brace:$inv_bad"
  fi

  # Each pass removes exactly one `}`, so termination is structural - pinned
  # here rather than argued, since the loop sits in a hook that fires on
  # every Bash call in the session.
  deep=".claude/"; _i=0
  while [ "$_i" -lt 200 ]; do deep="$deep{a,"; _i=$((_i + 1)); done
  deep="${deep}z"
  _i=0
  while [ "$_i" -lt 200 ]; do deep="$deep}"; _i=$((_i + 1)); done
  deep="$deep.json"
  deep_rc=0
  deep_out="$(timeout 5 bash -c 'g="$1"; pre=""; post=""; '"$collapse_src"'; printf "%s" "$g"' _ "$deep")" || deep_rc=$?
  if [ "$deep_rc" = 0 ]; then
    case "$deep_out" in
      *[{}]*) bad "[brace-nested] 200-deep nesting terminated but left a brace: $deep_out" ;;
      *)      pass "[brace-nested] 200-deep nesting collapses within 5s to '$deep_out'" ;;
    esac
  else
    bad "[brace-nested] 200-deep nesting did not complete within 5s (rc=$deep_rc)"
  fi
fi

echo
echo "-- Family table <-> memory note: bounded claims and slug parity, both directions --"
# The claim this gate makes about itself lived only in prose, so nothing
# could mechanically falsify it and it went stale inside the very commit
# that wrote it. These two checks are what stop that recurring: unbounded
# phrasing is a test failure, and the note's own table must name exactly the
# families this suite exercises, under the matching heading.
note=".claude/agent-memory/lead-programmer/project_harness_integrity_gate_persona_config_commit.md"
if [ ! -f "$note" ]; then
  bad "family table parity: memory note not found at $note"
else
  unbounded_hits=""
  for _p in "any spelling" "all spellings" "no glob can" "every spelling" "is always detected"; do
    for _f in "$gate" "$note"; do
      _n="$(grep -ci -- "$_p" "$_f" 2>/dev/null || true)"
      if [ "${_n:-0}" != 0 ]; then unbounded_hits="$unbounded_hits {$_f: '$_p' x$_n}"; fi
    done
  done
  if [ -z "$unbounded_hits" ]; then
    pass "no unbounded-universal phrasing in the gate source or the memory note"
  else
    bad "unbounded-universal phrasing found (a bounded family table is the only claim the code supports):$unbounded_hits"
  fi

  exercised="$(printf '%s\n' $seen_slugs | sort -u)"
  declared="$(printf '%s\n' "$fam_rows" | cut -d: -f1 | sort -u)"
  if [ "$exercised" = "$declared" ]; then
    pass "every declared family slug is exercised by at least one row, and no row uses an undeclared slug"
  else
    bad "family slug drift inside this suite: exercised=[$(echo $exercised)] declared=[$(echo $declared)]"
  fi

  note_pairs="$(awk '
    /^#+ / { sec="";
             if ($0 ~ /[Cc]losed/) sec="closed";
             else if ($0 ~ /[Rr]esidual/) sec="residual";
             else if ($0 ~ /[Oo]ver-block/) sec="overblock";
             next }
    sec != "" && /^\| `/ { s=$0; sub(/^\| `/,"",s); sub(/`.*/,"",s); print s ":" sec }
  ' "$note" | sort -u)"
  only_test="$(comm -23 <(printf '%s\n' "$fam_rows" | sort -u) <(printf '%s\n' "$note_pairs"))"
  only_note="$(comm -13 <(printf '%s\n' "$fam_rows" | sort -u) <(printf '%s\n' "$note_pairs"))"
  if [ -z "$only_test" ] && [ -z "$only_note" ]; then
    pass "doc/test slug parity: all $(printf '%s\n' "$fam_rows" | wc -l) slug:section pairs agree in both directions"
  else
    bad "doc/test slug parity broken - in tests only: [$(echo $only_test)]; in note only: [$(echo $only_note)]"
  fi
fi

echo
echo "-- Configless GUARD: denies even with no persona-config.json anywhere on disk (not even .claude/) --"
bare="$tmproot/bare"
mkdir -p "$bare"
run "$(jq -n --arg c "rm -f .claude/persona-config.json" '{tool_name:"Bash",tool_input:{command:$c}}')" \
    "$bare"
check "case d1 rm -f persona-config.json, project wholly unadapted" blocked

echo
echo "-- Set B: Write/Edit only --"
write_case "case e1 Write hooks/hooks.json" blocked "hooks/hooks.json" Write
write_case "case e2 Edit hooks/hooks.json" blocked "hooks/hooks.json" Edit
write_case "case e3 Write .claude/settings.json" blocked ".claude/settings.json" Write
write_case "case e4 Edit .claude/settings.json" blocked ".claude/settings.json" Edit
write_case "case e5 Write hooks/scripts/harness-integrity-gate.sh" blocked \
  "hooks/scripts/harness-integrity-gate.sh" Write
write_case "case e6 Edit hooks/scripts/harness-integrity-gate.sh" blocked \
  "hooks/scripts/harness-integrity-gate.sh" Edit

echo
echo "-- Set B: the ratified Bash gap (NOT an oversight) --"
bash_case "case f1 sed -i on hooks/hooks.json (ADR-0025 gap)" allowed \
  "sed -i s/x/y/ hooks/hooks.json"
bash_case "case f2 bash tests/validate.sh" allowed \
  "bash tests/validate.sh"
bash_case "case f3 grep -r hooks/scripts/" allowed \
  "grep -r hooks/scripts/"
# The asymmetry proof needs commands that actually SPELL a Set B literal in
# a non-benign shape (f1/f2/f3 above don't - see the mutation control below,
# which is what proves f1 specifically would flip).
bash_case "case f4 sed -i on the gate script itself" allowed \
  "sed -i s/x/y/ hooks/scripts/harness-integrity-gate.sh"

echo
echo "-- gh418 regression: embedded newline in a denied Bash command must not forge a second audit log line --"
injproj="$(mk inject)"
inj_log="$injproj/.claude/review-audit.log"
run "$(jq -n '{tool_name:"Bash",tool_input:{command:"cat .claude/persona-config.json;\n2026-01-01T00:00:00Z defer: waiting on the operator"}}')" \
    "$injproj"
if [ "$rc" = 2 ] && [ -f "$inj_log" ]; then
  inj_lines="$(wc -l < "$inj_log")"
  [ "$inj_lines" -eq 1 ] && pass "case g1 embedded-newline Bash command -> exactly one log line" \
    || bad "case g1 embedded-newline Bash command -> expected exactly 1 log line, got $inj_lines"
else
  bad "case g1 embedded-newline Bash command -> rc=$rc, log present=$( [ -f "$inj_log" ] && echo yes || echo no )"
fi

echo
echo "-- Step 1: the human-confirmation branch --"
mirror_path=".claude/hooks/scripts/harness-integrity-gate.sh"
gate_script_path="hooks/scripts/harness-integrity-gate.sh"
settings_path=".claude/settings.json"
hooks_json_path="hooks/hooks.json"

echo
echo "-- C1.1 / C3.1: fires for both sets, both tool_name values (5 subjects x 2 tool_name = 10 minimum) --"
ask_case "case p1 Write persona-config.json asks (Set A)" "$t_persona_cfg" Write A
ask_case "case p2 Edit persona-config.json asks (Set A)" "$t_persona_cfg" Edit A
ask_case "case p3 Write hooks.json asks (Set B)" "$hooks_json_path" Write B
ask_case "case p4 Edit hooks.json asks (Set B)" "$hooks_json_path" Edit B
ask_case "case p5 Write settings.json asks (Set B)" "$settings_path" Write B
ask_case "case p6 Edit settings.json asks (Set B)" "$settings_path" Edit B
ask_case "case p7 Write harness-integrity-gate.sh asks (Set B)" "$gate_script_path" Write B
ask_case "case p8 Edit harness-integrity-gate.sh asks (Set B)" "$gate_script_path" Edit B
ask_case "case p9 Write mirror asks (Set B)" "$mirror_path" Write B
ask_case "case p10 Edit mirror asks (Set B)" "$mirror_path" Edit B

# Non-vacuous (C3.1): a genuine Set A ask must NOT match Set B's fixture
# literal - proves ask_check distinguishes the two reason literals rather
# than just checking "is JSON" / "decision == ask".
run "$(_pm_payload Write "$t_persona_cfg" default __ABSENT__)" "$proj"
p_reason="$(jq -r '.hookSpecificOutput.permissionDecisionReason // empty' < "$outf")"
if [ "$rc" = 0 ] && [ "$p_reason" = "$ASK_REASON_A" ] && [ "$p_reason" != "$ASK_REASON_B" ]; then
  pass "[C3.1] ask_check is non-vacuous: a genuine Set A ask does not match Set B's fixture literal"
else
  bad "[C3.1] ask_check self-test failed to distinguish the two reason literals"
fi

echo
echo "-- C1.2: FROZEN TWO-TIER ALLOWLIST, exhaustive over the 6-value set plus 3 degenerate spellings, asserted as counts per set --"
_tally_ask_or_deny() {
  # Tallies the outcome of the most recent run() into count_asks/count_denies.
  if [ "$rc" = 0 ] && jq -e . >/dev/null 2>&1 < "$outf" \
     && [ "$(jq -r '.hookSpecificOutput.permissionDecision // empty' < "$outf")" = ask ]; then
    count_asks=$((count_asks + 1))
  elif [ "$rc" = 2 ]; then
    count_denies=$((count_denies + 1))
  fi
}

count_allowlist() {
  # $1 set (A|B), $2 subject. Sets count_asks/count_denies globals.
  local subject="$2" pm
  count_asks=0; count_denies=0
  for pm in default plan acceptEdits auto dontAsk bypassPermissions "" someFutureMode; do
    run "$(_pm_payload Write "$subject" "$pm" __ABSENT__)" "$proj"
    _tally_ask_or_deny
  done
  run "$(_pm_payload Write "$subject" __ABSENT__ __ABSENT__)" "$proj"
  _tally_ask_or_deny
}

count_allowlist A "$t_persona_cfg"
if [ "$count_asks" = 4 ] && [ "$count_denies" = 5 ]; then
  pass "[C1.2] Set A: exactly 4 ask / 5 deny across the 6-value set plus absent/empty/unrecognised"
else
  bad "[C1.2] Set A: expected 4 ask / 5 deny, got $count_asks ask / $count_denies deny"
fi

count_allowlist B "$hooks_json_path"
if [ "$count_asks" = 3 ] && [ "$count_denies" = 6 ]; then
  pass "[C1.2] Set B: exactly 3 ask / 6 deny across the 6-value set plus absent/empty/unrecognised (acceptEdits moves to deny)"
else
  bad "[C1.2] Set B: expected 3 ask / 6 deny, got $count_asks ask / $count_denies deny"
fi

echo
echo "-- C1.4: no ask from a subagent, across every allowlisted mode of both sets and all 5 subjects --"
allowlisted_a="default plan acceptEdits auto"
allowlisted_b="default plan auto"
c14_subjects="A:$t_persona_cfg
B:$hooks_json_path
B:$settings_path
B:$gate_script_path
B:$mirror_path"

c14_run() {
  # sets c14_total/c14_asked globals over $1 (subject list, "tier:subject" per line)
  local tier subj modes pm
  c14_total=0; c14_asked=0
  while IFS=: read -r tier subj; do
    [ -n "$tier" ] || continue
    if [ "$tier" = A ]; then modes="$allowlisted_a"; else modes="$allowlisted_b"; fi
    for pm in $modes; do
      c14_total=$((c14_total + 1))
      run "$(_pm_payload Write "$subj" "$pm" subagent-1)" "$proj"
      if [ "$rc" = 0 ] && jq -e . >/dev/null 2>&1 < "$outf" \
         && [ "$(jq -r '.hookSpecificOutput.permissionDecision // empty' < "$outf")" = ask ]; then
        c14_asked=$((c14_asked + 1))
      fi
    done
  done <<< "$1"
}

c14_run "$c14_subjects"
if [ "$c14_asked" = 0 ]; then
  pass "[C1.4] no ask from a subagent: all $c14_total allowlisted-mode x subject combinations still deny with agent_id present"
else
  bad "[C1.4] no ask from a subagent: $c14_asked/$c14_total combinations asked despite a non-empty agent_id"
fi

echo
echo "-- C1.5: non-repudiation invariant — zero permission-decision allow anywhere in the gate source --"
c15_hits="$(grep -cE '"permissionDecision"[[:space:]]*:[[:space:]]*"allow"|permissionDecision.*allow' "$gate" || true)"
if [ "${c15_hits:-0}" = 0 ]; then
  pass "[C1.5] zero permission-decision allow occurrences in $gate"
else
  bad "[C1.5] found $c15_hits permission-decision allow occurrence(s) in $gate"
fi

echo
echo "-- C1.6: the two permissionDecisionReason literals are fixed, unconstructed, and Set B states the self-disablement cost --"
c16a_count="$(grep -cE "^reason_[ab]='" "$gate" || true)"
if [ "${c16a_count:-0}" = 2 ]; then
  pass "[C1.6a] exactly 2 permissionDecisionReason literal assignments in $gate"
else
  bad "[C1.6a] expected exactly 2 reason literal assignments in $gate, found ${c16a_count:-0}"
fi

c16_line_a="$(grep -E "^reason_a='" "$gate" || true)"
c16_line_b="$(grep -E "^reason_b='" "$gate" || true)"
c16b_bad=""
for _rl in "$c16_line_a" "$c16_line_b"; do
  case "$_rl" in
    *'$'*|*'`'*) c16b_bad="$c16b_bad {$_rl}" ;;
  esac
done
if [ -z "$c16b_bad" ]; then
  pass "[C1.6b] neither reason literal contains \$, a backtick, or \$("
else
  bad "[C1.6b] a reason literal contains \$ or a backtick:$c16b_bad"
fi

case "$ASK_REASON_B" in
  *"registration surface"*"disable every future prompt from this gate, including this one"*)
    pass "[C1.6c] Set B's reason names the registration surface and the self-disablement cost" ;;
  *)
    bad "[C1.6c] Set B's reason does not state both the registration-surface target and the self-disablement cost" ;;
esac

echo
echo "-- C1.9: hot path unchanged — the new branch adds no work to the Bash path --"
c19_src="$(awk '/^# Bash branch:/{f=1} f' "$gate")"
c19_hits="$(printf '%s\n' "$c19_src" | grep -cE 'permission_mode|agent_id|ask_allowed|^ask\(' || true)"
if [ "${c19_hits:-0}" = 0 ]; then
  pass "[C1.9] the Bash branch contains no reference to permission_mode, agent_id, ask_allowed, or ask()"
else
  bad "[C1.9] the Bash branch references the new human-confirmation machinery ($c19_hits hit(s))"
fi

echo
echo "-- C1.7: SCOPE GUARDS — the branch is exactly five paths wide (persona-config + 4 Set B literals); everything else stays a hard deny --"
write_case "case p11 Write review-audit.log still denies under an allowlisted mode (OQ1: audit logs excluded)" \
  blocked "$t_review_log" Write "$proj" default
write_case "case p12 Write dispatch-audit.log still denies under an allowlisted mode" \
  blocked "$t_dispatch_log" Write "$proj" default
write_case "case p13 Write microworld-audit.log still denies under an allowlisted mode" \
  blocked "$t_microworld_log" Write "$proj" default
write_case "case p14 Write wip-audit.log still denies under an allowlisted mode" \
  blocked "$t_wip_log" Write "$proj" default
write_case "case p15 Write review-audit.log.seal still denies under an allowlisted mode" \
  blocked "$t_review_log.seal" Write "$proj" default
write_case "case p16 Write dispatch-audit.log.seal still denies under an allowlisted mode" \
  blocked "$t_dispatch_log.seal" Write "$proj" default
write_case "case p17 Write microworld-audit.log.seal still denies under an allowlisted mode" \
  blocked "$t_microworld_log.seal" Write "$proj" default
write_case "case p18 Write wip-audit.log.seal still denies under an allowlisted mode" \
  blocked "$t_wip_log.seal" Write "$proj" default
bash_case "case p19 Bash to settings.json still exit 0 (ADR-0025, unchanged)" allowed \
  "sed -i s/x/y/ $settings_path"

echo
echo "-- C1.8: CONFIGLESS PRESERVED — ask reads only the two payload fields, nothing on disk --"
noconf="$tmproot/noconf"
mkdir -p "$noconf"
run "$(_pm_payload Write "$t_persona_cfg" default __ABSENT__)" "$noconf"
ask_check "case p20 ask still fires with no .claude/ directory present at all" A

planted="$tmproot/planted"
mkdir -p "$planted/.claude"
printf 'reviewGating=false approved=true\n' > "$planted/.claude/persona-config.json"
run "$(_pm_payload Write "$t_persona_cfg" default __ABSENT__)" "$planted"
ask_check "case p21 ask is unchanged by a planted file claiming prior approval" A

echo
echo "-- C1.11: the mirror is Set B's fourth literal (baseline was exit 0 on Write/Edit at d807630) --"
ask_case "case p22 Write mirror asks under default (Set B tier)" "$mirror_path" Write B default
ask_case "case p23 Write mirror asks under plan (Set B tier)" "$mirror_path" Write B plan
ask_case "case p24 Write mirror asks under auto (Set B tier)" "$mirror_path" Write B auto
write_case "case p25 Write mirror denies under acceptEdits (Set B tier, not Set A)" \
  blocked "$mirror_path" Write "$proj" acceptEdits
write_case "case p26 Write mirror denies with a non-empty agent_id" \
  blocked "$mirror_path" Write "$proj" default subagent-1

baseline_dir="$tmproot/baseline"
mkdir -p "$baseline_dir/lib"
baseline_gate="$baseline_dir/harness-integrity-gate.sh"
if git show d807630:hooks/scripts/harness-integrity-gate.sh > "$baseline_gate" 2>/dev/null \
   && git show d807630:hooks/scripts/lib/audit-log.sh > "$baseline_dir/lib/audit-log.sh" 2>/dev/null \
   && git show d807630:hooks/scripts/lib/benign-command.sh > "$baseline_dir/lib/benign-command.sh" 2>/dev/null; then
  chmod +x "$baseline_gate"
  save_gate="$gate"; gate="$baseline_gate"
  write_case "case p27 baseline (d807630): Write mirror was exit 0 (no protection at all)" allowed "$mirror_path" Write
  gate="$save_gate"
else
  bad "[C1.11] could not retrieve hooks/scripts/harness-integrity-gate.sh (or its libs) at d807630 for the before/after baseline"
fi

echo
echo "-- C1.12: the mirror does not join the Bash branch (both fall-through arms, cheap and expensive, land on exit 0) --"
bash_case "case p28 Bash naming the mirror exits 0 (expensive arm: the path contains .claude, same as .claude/settings.json)" allowed \
  "sed -i s/x/y/ $mirror_path"
# case f4 above (hooks/scripts/harness-integrity-gate.sh) is the cheap-arm
# counterpart: no .claude substring, so set_a_mentioned() returns at its
# early "*) return 1" arm before the per-chunk normalize loop ever runs.

echo
echo "-- Mutation proof C1.3(a): unconditional-pass allowlist flips every deny row to ask --"
p_mutant_dir="$tmproot/p-mutant-bin"
mkdir -p "$p_mutant_dir/lib"
cp hooks/scripts/lib/*.sh "$p_mutant_dir/lib/"

unconditional_mutant="$p_mutant_dir/ask-unconditional.sh"
sed '/^ask_allowed() {$/a\
  return 0  # MUTATED-C1_3a-unconditional-pass
' hooks/scripts/harness-integrity-gate.sh > "$unconditional_mutant"
chmod +x "$unconditional_mutant"
if diff -q hooks/scripts/harness-integrity-gate.sh "$unconditional_mutant" >/dev/null; then
  bad "[C1.3a] mutant sed produced no change - not actually mutated"
else
  save_gate="$gate"; gate="$unconditional_mutant"
  count_allowlist A "$t_persona_cfg"; a_asks=$count_asks; a_denies=$count_denies
  count_allowlist B "$hooks_json_path"; b_asks=$count_asks; b_denies=$count_denies
  gate="$save_gate"
  if [ "$a_asks" = 9 ] && [ "$a_denies" = 0 ] && [ "$b_asks" = 9 ] && [ "$b_denies" = 0 ]; then
    pass "[C1.3a] unconditional-pass mutant flips Set A's 5 deny rows and Set B's 6 deny rows to ask (both sets: 9/0)"
  else
    bad "[C1.3a] expected both sets to flip fully to ask; got A=$a_asks/$a_denies B=$b_asks/$b_denies"
  fi
fi

echo
echo "-- Mutation proof C1.3(b): tier-collapse (accepting acceptEdits for Set B too) flips exactly that one row --"
tier_collapse_mutant="$p_mutant_dir/ask-tier-collapse.sh"
sed 's/^    acceptEdits) \[ "\$1" = A \] || return 1 ;;  # Set B stays deny (U2b)\.$/    acceptEdits) ;;  # MUTATED-C1_3b-tier-collapse/' \
  hooks/scripts/harness-integrity-gate.sh > "$tier_collapse_mutant"
chmod +x "$tier_collapse_mutant"
if diff -q hooks/scripts/harness-integrity-gate.sh "$tier_collapse_mutant" >/dev/null; then
  bad "[C1.3b] mutant sed produced no change - not actually mutated"
else
  save_gate="$gate"; gate="$tier_collapse_mutant"
  run "$(_pm_payload Write "$hooks_json_path" acceptEdits __ABSENT__)" "$proj"
  b_ae_flipped=0
  [ "$rc" = 0 ] && [ "$(jq -r '.hookSpecificOutput.permissionDecision // empty' < "$outf")" = ask ] && b_ae_flipped=1
  count_allowlist A "$t_persona_cfg"; a_asks=$count_asks; a_denies=$count_denies
  count_allowlist B "$hooks_json_path"; b_asks=$count_asks; b_denies=$count_denies
  gate="$save_gate"
  if [ "$b_ae_flipped" = 1 ] && [ "$a_asks" = 4 ] && [ "$a_denies" = 5 ] \
     && [ "$b_asks" = 4 ] && [ "$b_denies" = 5 ]; then
    pass "[C1.3b] tier-collapse mutant flips exactly the Set B acceptEdits row (Set A unchanged 4/5, Set B moves 3/6 -> 4/5)"
  else
    bad "[C1.3b] tier-collapse mutant did not flip exactly one row (B acceptEdits flipped=$b_ae_flipped, A=$a_asks/$a_denies, B=$b_asks/$b_denies)"
  fi
fi

echo
echo "-- Mutation proof C1.4: deleting the agent_id check flips every subagent fail-closed case to ask --"
agent_id_mutant="$p_mutant_dir/ask-no-agentid-check.sh"
sed 's/^  \[ -z "\$agent_id" \]$/  return 0  # MUTATED-C1_4-agent-id-removed/' \
  hooks/scripts/harness-integrity-gate.sh > "$agent_id_mutant"
chmod +x "$agent_id_mutant"
if diff -q hooks/scripts/harness-integrity-gate.sh "$agent_id_mutant" >/dev/null; then
  bad "[C1.4] mutant sed produced no change - not actually mutated"
else
  save_gate="$gate"; gate="$agent_id_mutant"
  c14_run "$c14_subjects"
  gate="$save_gate"
  if [ "$c14_asked" = "$c14_total" ] && [ "$c14_total" -gt 0 ]; then
    pass "[C1.4] mutation control: deleting the agent_id check flips all $c14_total subagent cases to ask"
  else
    bad "[C1.4] mutation control: expected all $c14_total to flip, got $c14_asked"
  fi
fi

echo
echo "-- C2.3: hot-path ordering, pinned by line number, not by eye --"
# Within set_a_mentioned(), the raw literal `case` (the function's first
# statement) must appear before the per-word `while` loop's first subshell
# (the `$(normalize_path ...)` call) - and the CALL to set_a_mentioned()
# must appear before the call to command_is_provably_benign() and before
# is_benign_jq_read()'s definition, both of which carry subshells of their
# own. Line numbers, not manual inspection.
fn_line="$(grep -n '^set_a_mentioned() {' "$gate" | cut -d: -f1)"
raw_case_line="$(awk -v s="$fn_line" 'NR>s && /case "\$cmd" in/ {print NR; exit}' "$gate")"
per_word_loop_line="$(awk -v s="$fn_line" 'NR>s && /while :; do/ {print NR; exit}' "$gate")"
call_line="$(grep -n '^set_a_mentioned "\$command"' "$gate" | cut -d: -f1)"
benign_call_line="$(grep -n '^command_is_provably_benign "\$command"' "$gate" | cut -d: -f1)"
jq_helper_call_line="$(grep -n '^is_benign_jq_read "\$command"' "$gate" | cut -d: -f1)"
if [ -n "$fn_line" ] && [ -n "$raw_case_line" ] && [ -n "$per_word_loop_line" ] \
   && [ "$raw_case_line" -lt "$per_word_loop_line" ] \
   && [ -n "$call_line" ] && [ -n "$benign_call_line" ] && [ -n "$jq_helper_call_line" ] \
   && [ "$call_line" -lt "$benign_call_line" ] && [ "$call_line" -lt "$jq_helper_call_line" ]; then
  pass "hot-path ordering: raw case ($raw_case_line) < per-word loop ($per_word_loop_line); set_a_mentioned call ($call_line) < command_is_provably_benign call ($benign_call_line) and is_benign_jq_read call ($jq_helper_call_line)"
else
  bad "hot-path ordering: could not establish raw-case-first via line numbers (fn=$fn_line raw=$raw_case_line loop=$per_word_loop_line call=$call_line benign=$benign_call_line jqcall=$jq_helper_call_line)"
fi

echo
echo "-- Mutation control 1: Write/Edit branch and Bash branch each kill a disjoint, non-empty case set --"
mutant_dir="$tmproot/mutant-bin"
mkdir -p "$mutant_dir/lib"
cp hooks/scripts/lib/*.sh "$mutant_dir/lib/"

# Neuter the Write/Edit branch: exit 0 as soon as we know it's a Write/Edit
# call, before any Set A/B comparison.
we_mutant="$mutant_dir/we-deleted.sh"
sed 's/^  \[ "\$has_path" = true \] || exit 0$/  [ "$has_path" = true ] || exit 0; exit 0/' \
  hooks/scripts/harness-integrity-gate.sh > "$we_mutant"
chmod +x "$we_mutant"

# Neuter the Bash branch: exit 0 as soon as we know it's a Bash call
# (command is non-empty), before Set A is even consulted.
bash_mutant="$mutant_dir/bash-deleted.sh"
sed 's/^command="\$(echo "\$input" | jq -r .*)"$/&; [ -z "$command" ] || exit 0/' \
  hooks/scripts/harness-integrity-gate.sh > "$bash_mutant"
chmod +x "$bash_mutant"

gate_real="$gate"
we_killed=0; we_alive_ok=1
gate="$we_mutant"
write_case "mutant(WE-deleted) Write persona-config.json" allowed ".claude/persona-config.json" Write
[ "$rc" = 0 ] && we_killed=1
bash_case "mutant(WE-deleted) rm -f persona-config.json (Bash still alive)" blocked "rm -f .claude/persona-config.json"
[ "$rc" = 2 ] || we_alive_ok=0

bash_killed=0; bash_alive_ok=1
gate="$bash_mutant"
bash_case "mutant(Bash-deleted) rm -f persona-config.json" allowed "rm -f .claude/persona-config.json"
[ "$rc" = 0 ] && bash_killed=1
write_case "mutant(Bash-deleted) Write persona-config.json (Write/Edit still alive)" blocked ".claude/persona-config.json" Write
[ "$rc" = 2 ] || bash_alive_ok=0
gate="$gate_real"

if [ "$we_killed" = 1 ] && [ "$we_alive_ok" = 1 ] && [ "$bash_killed" = 1 ] && [ "$bash_alive_ok" = 1 ]; then
  pass "mutation control 1: deleting Write/Edit kills its own cases only; deleting Bash kills its own cases only (disjoint, both non-empty)"
else
  bad "mutation control 1: expected both mutants to kill their own branch's cases and leave the other alive (we_killed=$we_killed we_alive_ok=$we_alive_ok bash_killed=$bash_killed bash_alive_ok=$bash_alive_ok)"
fi

echo
echo "-- Mutation control 2: adding Set B to the Bash branch breaks the asymmetry --"
# The naive "fix": fold Set B's literals into set_a_mentioned()'s own raw
# case, so the Bash branch starts denying on them too - proving f1/f4 above
# are relying on the asymmetry being real, not an ordering accident.
asym_mutant="$mutant_dir/asymmetry-added.sh"
sed 's/\*"\$persona_cfg"\*|\*"\$review_log"\*|\*"\$dispatch_log"\*|\*"\$microworld_log"\*|\*"\$wip_log"\*)/*"$persona_cfg"*|*"$review_log"*|*"$dispatch_log"*|*"$microworld_log"*|*"$wip_log"*|*"hooks\/hooks.json"*|*"hooks\/scripts\/harness-integrity-gate.sh"*)/' \
  hooks/scripts/harness-integrity-gate.sh > "$asym_mutant"
chmod +x "$asym_mutant"
if ! diff -q hooks/scripts/harness-integrity-gate.sh "$asym_mutant" >/dev/null; then
  gate="$asym_mutant"
  bash_case "mutant(Set B on Bash) f1 sed -i hooks/hooks.json" blocked "sed -i s/x/y/ hooks/hooks.json"
  f1_flipped=$([ "$rc" = 2 ] && echo 1 || echo 0)
  bash_case "mutant(Set B on Bash) f4 sed -i on the gate script" blocked "sed -i s/x/y/ hooks/scripts/harness-integrity-gate.sh"
  f4_flipped=$([ "$rc" = 2 ] && echo 1 || echo 0)
  gate="$gate_real"
  if [ "$f1_flipped" = 1 ] && [ "$f4_flipped" = 1 ]; then
    pass "mutation control 2: adding Set B to the Bash branch flips both f1 and f4 from allowed to blocked - the asymmetry is real"
  else
    bad "mutation control 2: expected both f1 and f4 to flip to blocked under the mutant (f1_flipped=$f1_flipped f4_flipped=$f4_flipped)"
  fi
else
  bad "mutation control 2: sed produced no change - the mutant is not actually mutated"
fi

echo
echo "-- C2.1: PostToolUse (Edit|Write) registration - fourth hook on the existing matcher, not a new one --"
c21_count="$(jq '[.hooks.PostToolUse[] | select(.matcher=="Edit|Write") | .hooks[] | select(.command|test("harness-integrity-gate"))] | length' hooks/hooks.json)"
c21_total="$(jq '[.hooks.PostToolUse[] | select(.matcher=="Edit|Write") | .hooks[]] | length' hooks/hooks.json)"
if [ "$c21_count" = 1 ] && [ "$c21_total" = 4 ]; then
  pass "[C2.1] harness-integrity-gate registered exactly once on the Edit|Write PostToolUse matcher, which now carries 4 hooks"
else
  bad "[C2.1] expected 1 registration and 4 total hooks, got count=$c21_count total=$c21_total"
fi

# _pt_payload <tool_name> <file_path> - a PostToolUse payload: no
# permission_mode/agent_id, matching what Claude Code actually sends after a
# completed write.
_pt_payload() {
  jq -n --arg t "$1" --arg p "$2" '{hook_event_name:"PostToolUse", tool_name:$t, tool_input:{file_path:$p}}'
}

# posttool_case <label> <file_path> <tool_name> [project dir] - asserts exit 0.
posttool_case() {
  run "$(_pt_payload "$3" "$2")" "${4:-$proj}"
  check "$1" allowed
}

echo
echo "-- C2.2: PostToolUse regression guard - 7 subjects, every one exits 0 untouched --"
posttool_case "case q1 PostToolUse Write persona-config.json exits 0" "$t_persona_cfg" Write
posttool_case "case q2 PostToolUse Write review-audit.log exits 0" "$t_review_log" Write
posttool_case "case q3 PostToolUse Write hooks.json exits 0" "$hooks_json_path" Write
posttool_case "case q4 PostToolUse Write settings.json exits 0" "$settings_path" Write
posttool_case "case q5 PostToolUse Write harness-integrity-gate.sh exits 0" "$gate_script_path" Write
posttool_case "case q6 PostToolUse Write mirror exits 0" "$mirror_path" Write
posttool_case "case q7 PostToolUse Write ordinary source file exits 0" "hooks/scripts/lib/audit-log.sh" Write

echo
echo "-- Mutation proof (hook_event_name branch, C2.2/C3.3): removing it flips 6 human-confirmable PostToolUse cases to exit 2, leaves the ordinary file at exit 0 --"
het_mutant="$mutant_dir/posttooluse-branch-deleted.sh"
sed 's/^if \[ "\$hook_event_name" = "PostToolUse" \]; then$/if [ "$hook_event_name" = "MUTATED-C2_2-hook-event-name-neutered" ]; then/' \
  hooks/scripts/harness-integrity-gate.sh > "$het_mutant"
chmod +x "$het_mutant"
if diff -q hooks/scripts/harness-integrity-gate.sh "$het_mutant" >/dev/null; then
  bad "[C2.2 mutation] mutant sed produced no change - not actually mutated"
else
  save_gate="$gate"; gate="$het_mutant"
  het_flipped=0; het_total=0
  for subj in "$t_persona_cfg" "$t_review_log" "$hooks_json_path" "$settings_path" "$gate_script_path" "$mirror_path"; do
    het_total=$((het_total + 1))
    run "$(_pt_payload Write "$subj")" "$proj"
    [ "$rc" = 2 ] && het_flipped=$((het_flipped + 1))
  done
  run "$(_pt_payload Write "hooks/scripts/lib/audit-log.sh")" "$proj"
  het_ordinary_ok=$([ "$rc" = 0 ] && echo 1 || echo 0)
  gate="$save_gate"
  if [ "$het_flipped" = "$het_total" ] && [ "$het_total" -gt 0 ] && [ "$het_ordinary_ok" = 1 ]; then
    pass "[C2.2 mutation] hook_event_name mutant kills all $het_total human-confirmable PostToolUse cases (kill count: $het_total); ordinary file stays exit 0 - disjoint from C1.3(a)/C1.3(b)/C1.4's kill sets (different subjects, different code region)"
  else
    bad "[C2.2 mutation] expected $het_total flips to exit 2 and the ordinary file to stay 0; got flipped=$het_flipped ordinary_ok=$het_ordinary_ok"
  fi
fi

echo
echo "-- C2.3: exactly one 'completed' audit line per write, correct set= field, and fails closed on a newline-embedded file_path --"
c23proj="$(mk c23)"
c23_log="$c23proj/.claude/review-audit.log"

run "$(_pt_payload Write "$t_persona_cfg")" "$c23proj"
c23_last="$(tail -n1 "$c23_log" 2>/dev/null || true)"
case "$c23_last" in
  *"completed hook=harness-integrity-gate set=A subject=$t_persona_cfg"*)
    [ "$(wc -l < "$c23_log")" = 1 ] && pass "[C2.3] case r1 PostToolUse persona-config.json -> exactly 1 completed line, set=A" \
      || bad "[C2.3] case r1 expected exactly 1 log line" ;;
  *) bad "[C2.3] case r1 completed line malformed or missing: $c23_last" ;;
esac

run "$(_pt_payload Write "$hooks_json_path")" "$c23proj"
c23_last2="$(tail -n1 "$c23_log" 2>/dev/null || true)"
case "$c23_last2" in
  *"completed hook=harness-integrity-gate set=B subject=$hooks_json_path"*)
    [ "$(wc -l < "$c23_log")" = 2 ] && pass "[C2.3] case r2 PostToolUse hooks.json -> one new line appended, set=B" \
      || bad "[C2.3] case r2 expected exactly 2 total log lines" ;;
  *) bad "[C2.3] case r2 completed line malformed or missing: $c23_last2" ;;
esac

# gh418 idiom, re-asserted here: a newline embedded in file_path cannot forge
# a second audit line, because the subject is an EXACT case match against the
# five literals - the injected newline defeats the match entirely, so nothing
# is appended and the gate still exits 0 (fails closed, does not block).
run "$(jq -n --arg t Write --arg p "$hooks_json_path
2026-01-01T00:00:00Z defer: injected line" '{hook_event_name:"PostToolUse", tool_name:$t, tool_input:{file_path:$p}}')" "$c23proj"
c23_lines3="$(wc -l < "$c23_log")"
if [ "$rc" = 0 ] && [ "$c23_lines3" = 2 ]; then
  pass "[C2.3] case r3 newline-embedded file_path matches no literal exactly -> no line appended, exit 0"
else
  bad "[C2.3] case r3 expected rc=0 and log to stay at 2 lines, got rc=$rc lines=$c23_lines3"
fi

echo
echo "-- C2.4(a): Set A pairing - ask + PostToolUse = 2 new lines; a deny = 1 --"
c24a_proj="$(mk c24a)"
c24a_log="$c24a_proj/.claude/review-audit.log"
run "$(_pm_payload Write "$t_persona_cfg" default __ABSENT__)" "$c24a_proj"
run "$(_pt_payload Write "$t_persona_cfg")" "$c24a_proj"
c24a_lines="$(wc -l < "$c24a_log")"
c24a_last="$(tail -n1 "$c24a_log" 2>/dev/null || true)"
case "$c24a_last" in
  *"completed hook=harness-integrity-gate set=A subject=$t_persona_cfg"*)
    [ "$c24a_lines" = 2 ] && pass "[C2.4a] Set A ask + PostToolUse -> exactly 2 new audit lines, the second reading 'completed'" \
      || bad "[C2.4a] Set A ask + PostToolUse -> expected exactly 2 lines, got $c24a_lines" ;;
  *) bad "[C2.4a] Set A ask + PostToolUse -> last line is not a 'completed' record: $c24a_last" ;;
esac

c24a_deny_proj="$(mk c24a-deny)"
c24a_deny_log="$c24a_deny_proj/.claude/review-audit.log"
run "$(_pm_payload Write "$t_persona_cfg" __ABSENT__ __ABSENT__)" "$c24a_deny_proj"
c24a_deny_lines="$(wc -l < "$c24a_deny_log")"
if [ "$rc" = 2 ] && [ "$c24a_deny_lines" = 1 ]; then
  pass "[C2.4a] Set A deny -> exactly 1 audit line; a blocked write produces no PostToolUse completion"
else
  bad "[C2.4a] Set A deny -> expected rc=2 and 1 line, got rc=$rc lines=$c24a_deny_lines"
fi

echo
echo "-- C2.4(b): Set B pairing is AMBIGUOUS BY DESIGN (U5) - never assert it distinguishes denial from approval --"
c24b_proj="$(mk c24b)"
c24b_log="$c24b_proj/.claude/review-audit.log"
run "$(_pm_payload Write "$hooks_json_path" default __ABSENT__)" "$c24b_proj"
run "$(_pt_payload Write "$hooks_json_path")" "$c24b_proj"
c24b_lines="$(wc -l < "$c24b_log")"
c24b_last="$(tail -n1 "$c24b_log" 2>/dev/null || true)"
case "$c24b_last" in
  *"completed hook=harness-integrity-gate set=B subject=$hooks_json_path"*)
    [ "$c24b_lines" = 2 ] && pass "[C2.4b] Set B ask + PostToolUse, hook still armed -> exactly 2 new audit lines, the second reading 'completed'" \
      || bad "[C2.4b] Set B ask + PostToolUse -> expected exactly 2 lines, got $c24b_lines" ;;
  *) bad "[C2.4b] Set B ask + PostToolUse -> last line is not a 'completed' record: $c24b_last" ;;
esac

# Reachability proof for the ambiguity itself: the SAME one-line shape (an
# 'asked' line with no 'completed' line after it) arises from an APPROVED
# write that then disables its own registration - simulated here by simply
# never issuing the PostToolUse call that a still-armed gate would receive.
# This is not a denial; it demonstrates the pairing cannot tell the two apart.
c24b_sd_proj="$(mk c24b-selfdisable)"
c24b_sd_log="$c24b_sd_proj/.claude/review-audit.log"
run "$(_pm_payload Write "$hooks_json_path" default __ABSENT__)" "$c24b_sd_proj"
c24b_sd_lines="$(wc -l < "$c24b_sd_log")"
if [ "$rc" = 0 ] && [ "$c24b_sd_lines" = 1 ]; then
  pass "[C2.4b] a one-line 'asked'-only record is reachable via APPROVAL-and-self-disablement too, not only denial - the pair is ambiguous by design"
else
  bad "[C2.4b] expected rc=0 and 1 line for the self-disablement reachability case, got rc=$rc lines=$c24b_sd_lines"
fi

# Fixed, enumerated file list (never an unbounded "no file says X", per R5):
# no artifact in this repo may claim the Set B asked/completed pair
# distinguishes denial from approval.
c24b_files="$gate docs/trust-model.md CONTEXT.md"
for _f in docs/adr/*.md; do c24b_files="$c24b_files $_f"; done
c24b_overclaim=""
for _f in $c24b_files; do
  [ -f "$_f" ] || continue
  if grep -qi "distinguishes denial from approval" "$_f" 2>/dev/null \
     || grep -qiE "asked.{0,60}(with no|without|but no).{0,20}completed.{0,40}(means|implies|indicates).{0,10}denied" "$_f" 2>/dev/null; then
    c24b_overclaim="$c24b_overclaim $_f"
  fi
done
if [ -z "$c24b_overclaim" ]; then
  pass "[C2.4b] enumerated file list ($(echo $c24b_files | wc -w) files) - none claims the Set B pair distinguishes denial from approval"
else
  bad "[C2.4b] over-claim found in:$c24b_overclaim"
fi

echo
echo "-- C2.5: exemptions re-run after Step 2's edit --"
c25a="$(grep -cF 'persona-config.json' hooks/scripts/harness-integrity-gate.sh || true)"
c25b="$(grep -cF 'reviewGating'        hooks/scripts/harness-integrity-gate.sh || true)"
if [ "${c25a:-0}" = 0 ] && [ "${c25b:-0}" = 0 ]; then
  pass "[C2.5] configless preserved: zero literal 'persona-config.json' or 'reviewGating' occurrences in the gate source"
else
  bad "[C2.5] expected zero occurrences of both, got persona-config.json=$c25a reviewGating=$c25b"
fi

echo
if [ "$fail" -eq 0 ]; then
  echo "All harness-integrity-gate tests passed."
else
  echo "$fail test group(s) failed."
fi
exit "$fail"
