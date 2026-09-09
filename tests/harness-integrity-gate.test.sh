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
  printf '%s' "$1" | CLAUDE_PROJECT_DIR="$2" bash "$gate" >/dev/null 2>"$errf" || rc=$?
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

# $1 label, $2 verdict, $3 file_path, $4 tool_name (Write|Edit), $5 project dir
write_case() {
  run "$(jq -n --arg t "$4" --arg p "$3" '{tool_name:$t,tool_input:{file_path:$p}}')" \
      "${5:-$proj}"
  check "$1" "$2"
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
if [ "$fail" -eq 0 ]; then
  echo "All harness-integrity-gate tests passed."
else
  echo "$fail test group(s) failed."
fi
exit "$fail"
