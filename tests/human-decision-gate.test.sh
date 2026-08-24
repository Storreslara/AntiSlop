#!/usr/bin/env bash
# Behavioral regression suite for hooks/scripts/human-decision-gate.sh: blocks
# every agent identity from writing .claude/human-review/<task-id>/DECISION,
# no grant branch, no fallback. Canned hook-input JSON piped over stdin,
# fixtures seeded under mktemp -d - no claude CLI, no network, no live
# dispatch. Same idiom as tests/reviewed-path-gate.test.sh.
#
# Fixture hygiene: testAndLintCommand is "true", NEVER this repo's
# `bash tests/validate.sh` - this suite runs FROM validate.sh and would recurse.
set -euo pipefail
cd "$(dirname "$0")/.."
unset CLAUDE_PLUGIN_ROOT || true
fail=0

gate="hooks/scripts/human-decision-gate.sh"

tmproot="$(mktemp -d)"
trap 'rm -rf "$tmproot"' EXIT
errf="$tmproot/stderr"

pass() { echo "OK   $*"; }
bad()  { echo "FAIL $*"; fail=1; }

mk() {
  local d="$tmproot/$1"
  mkdir -p "$d/.claude/human-review/u1"
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

# $1 label, $2 verdict, $3 agent_type, $4 file_path, $5 project dir
write_case() {
  run "$(jq -n --arg a "$3" --arg p "$4" '{tool_name:"Write",agent_type:$a,tool_input:{file_path:$p}}')" \
      "${5:-$proj}"
  check "$1" "$2"
}

# $1 label, $2 verdict, $3 agent_type, $4 command, $5 project dir (default $proj)
bash_case() {
  run "$(jq -n --arg a "$3" --arg c "$4" '{tool_name:"Bash",agent_type:$a,tool_input:{command:$c}}')" \
      "${5:-$proj}"
  check "$1" "$2"
}

echo "-- Write/Edit path: DECISION is unwritable, no grant branch --"
write_case "case a Write DECISION as reviewer" blocked antislop:reviewer \
  ".claude/human-review/u1/DECISION"
write_case "case b Write DECISION, empty agent_type (main session)" blocked "" \
  ".claude/human-review/u1/DECISION"
write_case "case c Write DECISION as orchestrator" blocked antislop:orchestrator \
  ".claude/human-review/u1/DECISION"
write_case "case g Write PACKET.md as reviewer (gate is DECISION-specific)" allowed \
  antislop:reviewer ".claude/human-review/u1/PACKET.md"
write_case "case h Write DECISION via dot-segments (normalization holds)" blocked \
  antislop:reviewer ".claude/human-review/u1/../u1/DECISION"

echo
echo "-- Bash path: substring early-exit, then command_is_provably_benign() --"
for id in antislop:reviewer "" antislop:orchestrator; do
  bash_case "case d printf > DECISION as '$id'" blocked "$id" \
    "printf 'DECISION u1 approved' > .claude/human-review/u1/DECISION"
done
bash_case "case e cat DECISION (reads allowed)" allowed antislop:reviewer \
  "cat .claude/human-review/u1/DECISION"
bash_case "case f heredoc mentioning both (lexer fails closed)" blocked antislop:reviewer \
  "cat <<EOF
human-review DECISION
EOF"
bash_case "case i rm -rf the whole packet dir (sanctioned deletion path)" allowed \
  antislop:reviewer "rm -rf .claude/human-review/u1"

echo
echo "-- sanctioned marker-write template: allowed (N1-N5) --"
bash_case "N1 template writes .pass, body quotes the DECISION path" allowed antislop:reviewer \
  "cat > .claude/reviewed/u1.pass <<'EOF'
PASS u1 2026-08-12T00:00:00Z commit: abc123 criteria: bash tests/validate.sh
human: approved, quoting .claude/human-review/u1/DECISION verbatim:
EOF"
bash_case "N2 same via >> append" allowed antislop:reviewer \
  "cat >> .claude/reviewed/u1.pass <<'EOF'
human: approved, quoting .claude/human-review/u1/DECISION verbatim:
EOF"
bash_case "N3 body carries \$(), backticks, > and ; as inert data" allowed antislop:reviewer \
  "cat > .claude/reviewed/u1.pass <<'EOF'
quoting .claude/human-review/u1/DECISION verbatim:
\$(id) \`id\` > /tmp/x ; rm -rf /
EOF"
bash_case "N4 .fail target" allowed antislop:reviewer \
  "cat > .claude/reviewed/u1.fail <<'EOF'
FAIL u1 - see .claude/human-review/u1/DECISION
EOF"
bash_case "N5 .directed target" allowed antislop:reviewer \
  "cat > .claude/reviewed/u1.directed <<'EOF'
DIRECTED u1 - fix per .claude/human-review/u1/DECISION
EOF"

echo
echo "-- the invariant: DECISION-targeting shapes stay denied (N6-N20) --"
bash_case "N6 P7 early terminator, second command writes the DECISION path" blocked \
  antislop:reviewer "cat > .claude/reviewed/u1.pass <<'EOF'
PASS u1 quoting .claude/human-review/u1/DECISION
EOF
printf approved > .claude/human-review/u1/DECISION"
# N6 above is denied by the last-line rule alone (its final line is the second
# command, not the delimiter), so it does NOT exercise the early-terminator
# guard. N6b does: the delimiter is repeated at the end so the last line still
# looks like a terminator, and only "the FIRST line equal to the delimiter must
# be the last" rejects it. Deleting that guard flips N6b to allowed - verified
# by mutation, which is the whole reason this case exists.
bash_case "N6b early terminator WITH a trailing delimiter line (binds the guard)" \
  blocked antislop:reviewer "cat > .claude/reviewed/u1.pass <<'EOF'
PASS u1 quoting .claude/human-review/u1/DECISION
EOF
printf approved > .claude/human-review/u1/DECISION
EOF"
bash_case "N7 template whose target IS the DECISION path" blocked antislop:reviewer \
  "cat > .claude/human-review/u1/DECISION <<'EOF'
approved
EOF"
bash_case "N8 unquoted heredoc delimiter" blocked antislop:reviewer \
  "cat > .claude/reviewed/u1.pass <<EOF
quoting .claude/human-review/u1/DECISION
EOF"
bash_case "N9 double-quoted heredoc delimiter" blocked antislop:reviewer \
  "cat > .claude/reviewed/u1.pass <<\"EOF\"
quoting .claude/human-review/u1/DECISION
EOF"
bash_case "N10 command substitution in the target" blocked antislop:reviewer \
  "cat > \$(echo .claude/reviewed)/u1.pass <<'EOF'
quoting .claude/human-review/u1/DECISION
EOF"
bash_case "N11 shell variable in the target" blocked antislop:reviewer \
  "cat > \$M/u1.pass <<'EOF'
quoting .claude/human-review/u1/DECISION
EOF"
bash_case "N12 quoted target" blocked antislop:reviewer \
  "cat > '.claude/reviewed/u1.pass' <<'EOF'
quoting .claude/human-review/u1/DECISION
EOF"
bash_case "N13 target escapes the reviewed dir via .." blocked antislop:reviewer \
  "cat > .claude/reviewed/../human-review/u1/DECISION <<'EOF'
approved
EOF"
bash_case "N14 non-sanctioned suffix (.txt)" blocked antislop:reviewer \
  "cat > .claude/reviewed/u1.txt <<'EOF'
quoting .claude/human-review/u1/DECISION
EOF"
bash_case "N15 a command precedes cat" blocked antislop:reviewer \
  "printf x; cat > .claude/reviewed/u1.pass <<'EOF'
quoting .claude/human-review/u1/DECISION
EOF"
bash_case "N16 pipeline into the template" blocked antislop:reviewer \
  "printf x | cat > .claude/reviewed/u1.pass <<'EOF'
quoting .claude/human-review/u1/DECISION
EOF"
bash_case "N17 extra redirection on the command line" blocked antislop:reviewer \
  "cat > .claude/reviewed/u1.pass <<'EOF' 2> .claude/human-review/u1/DECISION
PASS u1
EOF"
bash_case "N18 tee in place of cat" blocked antislop:reviewer \
  "tee .claude/reviewed/u1.pass <<'EOF'
quoting .claude/human-review/u1/DECISION
EOF"
bash_case "N19 unterminated heredoc" blocked antislop:reviewer \
  "cat > .claude/reviewed/u1.pass <<'EOF'
quoting .claude/human-review/u1/DECISION"
bash_case "N20 terminator only as a substring of a longer line" blocked antislop:reviewer \
  "cat > .claude/reviewed/u1.pass <<'EOF'
quoting .claude/human-review/u1/DECISION
EOF and then some"

echo
echo "-- pinned residual R-2: split-variable target stays ALLOWED, deliberately --"
bash_case "N21 split-variable write to the DECISION path (documented residual)" allowed \
  antislop:reviewer "d=human-rev; e=iew; printf x > .claude/\$d\$e/u1/DECISION"

echo
echo "-- the deny message is instructional (N22-N23) --"
bash_case "N22/N23 setup: a denied DECISION-targeting write" blocked antislop:reviewer \
  "cat > .claude/human-review/u1/DECISION <<'EOF'
approved
EOF"
if grep -qF "cat > .claude/reviewed/<task-id>.pass <<'EOF'" "$errf"; then
  pass "N22 deny message prints the sanctioned template literally"
else
  bad "N22 deny message does not print the sanctioned template line"
fi
if grep -qF 'self-authorized bypass' "$errf"; then
  pass "N23 deny message names the self-authorized bypass class"
else
  bad "N23 deny message does not name 'self-authorized bypass'"
fi
if grep -qF 'rm -rf .claude/human-review/<task-id>' "$errf"; then
  pass "N23b deny message keeps the rm -rf packet-discard guidance"
else
  bad "N23b deny message dropped the rm -rf guidance"
fi
if grep -qF 'needs no workaround' "$errf"; then
  pass "N23c deny message scopes the rule to commands TARGETING the path"
else
  bad "N23c deny message dropped the clarifying sentence"
fi

echo
echo "-- P13: a backslash inside single quotes no longer denies a pure read --"
bash_case "P13-a grep with an escaped alternation over the packet file" allowed \
  antislop:reviewer "grep -n 'DECISION\\|human-review' .claude/human-review/u1/DECISION"
bash_case "P13-b grep -E with an escaped word boundary" allowed antislop:reviewer \
  "grep -nE 'DECISION\\b' .claude/human-review/u1/DECISION"
bash_case "P13-c recursive grep over the whole human-review tree" allowed \
  antislop:reviewer "grep -rn 'DECISION\\|approve' .claude/human-review/"
# The narrowing must not widen the write surface: every backslash construct that
# changes bash's own lexing stays denied. P13-l binds the `$'`/`$"` branch and
# P13-g the backslash-inside-double-quotes branch (delete either and the gate
# allows the case, with real bash then creating the file); P13-d/e/f/h/i/j are
# the surrounding regression net.
bash_case "P13-d ANSI-C quoted write" blocked antislop:reviewer \
  "sh -c \$'printf x > .claude/human-review/u1/DECISION'"
bash_case "P13-e locale-quoted write" blocked antislop:reviewer \
  "sh -c \$\"printf x > .claude/human-review/u1/DECISION\""
bash_case "P13-f escaped quote inside a double-quoted span" blocked antislop:reviewer \
  "echo \"a\\\" ; printf x > .claude/human-review/u1/DECISION\""
bash_case "P13-g two escaped quotes re-balance the naive count, hiding a >" blocked \
  antislop:reviewer "echo \"a\\\"\" ; printf x > .claude/human-review/u1/DECISION\\\""
bash_case "P13-h escaped space in the redirection target" blocked antislop:reviewer \
  "printf x > .claude/human-review/u1/DECISION\\ b"
bash_case "P13-i line continuation before the redirect" blocked antislop:reviewer \
  "printf x \\
 > .claude/human-review/u1/DECISION"
bash_case "P13-j backslash ending a single-quoted span, then a real write" blocked \
  antislop:reviewer "printf 'a\\' ; printf x > .claude/human-review/u1/DECISION"
# P13-l: bash reads $'a\'' as ONE ANSI-C word - the \' does not close it - so the
# write that follows is live. A lexer treating $' as an ordinary single quote
# pairs the quotes one position off and masks that write. First word is
# allowlisted, so this branch is the only thing denying it.
bash_case "P13-l \$'...' mis-pairing hides a live write (binds the guard)" blocked \
  antislop:reviewer "printf \$'a\\'' ; printf x > .claude/human-review/u1/DECISION\\'"
# R-11: the comment allowance the shared lexer grants is for TRAILING comments
# only. A comment on its own line still fails closed, because the skeleton splits
# segments on newlines and the masked '#' becomes the segment's program. That is
# the ratified issue-#183 residual, deliberately NOT fixed here - pinned so a
# later implementer does not read it as an oversight.
bash_case "P13-k own-line comment after a read stays blocked (R-11 residual)" blocked \
  antislop:reviewer "cat .claude/human-review/u1/DECISION
# note"

echo
echo "-- FP-B: a prose-only git commit is allowed (C1-C8) --"
bash_case "C1 the operator's exact commit, both tokens in the message" allowed \
  antislop:reviewer \
  "git commit -m \"fix(human-review-cleanup-1): pin the unreadable DECISION file\""
bash_case "C2 single-quoted message" allowed antislop:reviewer \
  "git commit -m 'fix(human-review-cleanup-1): unreadable DECISION file'"
bash_case "C3 -am" allowed antislop:reviewer \
  "git commit -am \"fix(human-review-cleanup-1): unreadable DECISION file\""
bash_case "C4 --amend" allowed antislop:reviewer \
  "git commit --amend -m \"fix(human-review-cleanup-1): unreadable DECISION file\""
bash_case "C5 two -m parts" allowed antislop:reviewer \
  "git commit -m \"fix(human-review-cleanup-1): headline\" -m \"body names the DECISION file\""
# C6: the newline sits INSIDE the quoted span, so command_skeleton() masks it and
# the one-segment test still sees a single command. An unquoted newline splits.
bash_case "C6 multi-line message" allowed antislop:reviewer \
  "git commit -m \"fix(human-review-cleanup-1): headline

body names the DECISION file\""
bash_case "C7 apostrophe inside a double-quoted message" allowed antislop:reviewer \
  "git commit -m \"fix(human-review-cleanup-1): don't lose the DECISION file\""
# C8 is the measured glob hazard: a tokenizer built on \$(printf ... | tr ...)
# expands this bare * to every filename in the repository (22 of them) before
# the path-shape test ever runs. The pure-bash scan must not.
bash_case "C8 a bare * in the message (glob hazard)" allowed antislop:reviewer \
  "git commit -m \"fix(human-review-cleanup-1): DECISION * glob hazard\""

echo
echo "-- P16: an inert trailing comment no longer denies a write elsewhere --"
bash_case "P16-a write elsewhere, both tokens only in a trailing comment" allowed \
  antislop:reviewer \
  "printf ok > /tmp/hdg-note.txt # relates to the human-review packet and its DECISION"
bash_case "P16-b no space after the #" allowed antislop:reviewer \
  "printf ok > /tmp/hdg-note.txt #human-review DECISION"
# P16-c only DESCRIBES a cd-relative write; bash discards the whole comment. Note
# the boundary: had the comment spelled the path in one unbroken run it would be
# denied, which is D25-D28's class and is deliberate.
bash_case "P16-c a comment describing a cd-relative write" allowed antislop:reviewer \
  "printf ok > /tmp/hdg-note.txt # cd .claude/human-review/u1 then write DECISION by hand"
# R-11: the allowance covers TRAILING comments only. P16-d is P16-a's comment
# moved to its own line, and it stays DENIED - command_skeleton() splits segments
# on newlines, so the masked '#' becomes that segment's program and fails the
# allowlist. That is the ratified issue-#183 residual (benign-command.sh header,
# docs/plans/2026-07-31-debug-182-step6-word-boundary.md step 6R-4), deliberately
# NOT fixed here. Pinned as a pair with P16-a so a later implementer reads it as
# a boundary rather than an oversight. P13-k pins the same shape after a read,
# but is denied by the path-shape scan first, so only P16-d binds the residual.
bash_case "P16-d the same comment on its OWN line stays blocked (R-11 residual)" \
  blocked antislop:reviewer "printf ok > /tmp/hdg-note.txt
# relates to the human-review packet and its DECISION"

echo
echo "-- the invariant: DECISION-writing shapes stay denied (D1-D30) --"
bash_case "D1 direct redirect" blocked antislop:reviewer \
  "printf approved > .claude/human-review/u1/DECISION"
bash_case "D2 sh -c single-quoted write" blocked antislop:reviewer \
  "sh -c 'printf x > .claude/human-review/u1/DECISION'"
# D3/D4: no run spells the path, so only the program allowlist (D3) and the
# surviving-trigger test (D4) stand between these and the real file.
bash_case "D3 sh -c cd-relative write" blocked antislop:reviewer \
  "sh -c 'cd .claude/human-review/u1 && printf x > DECISION'"
bash_case "D4 bare cd-relative write" blocked antislop:reviewer \
  "cd .claude/human-review/u1 && printf x > DECISION"
bash_case "D5 node -e" blocked antislop:reviewer \
  "node -e 'require(\"fs\").writeFileSync(\".claude/human-review/u1/DECISION\",\"x\")'"
bash_case "D6 python3 -c" blocked antislop:reviewer \
  "python3 -c 'open(\".claude/human-review/u1/DECISION\",\"w\").write(\"x\")'"
bash_case "D7 tee" blocked antislop:reviewer \
  "tee .claude/human-review/u1/DECISION"
bash_case "D8 cp" blocked antislop:reviewer \
  "cp /tmp/x .claude/human-review/u1/DECISION"
bash_case "D9 sed -i" blocked antislop:reviewer \
  "sed -i 's/x/y/' .claude/human-review/u1/DECISION"
bash_case "D10 git apply" blocked antislop:reviewer \
  "git apply .claude/human-review/u1/DECISION.patch"
bash_case "D11 commit then write via &&" blocked antislop:reviewer \
  "git commit -m \"fix(human-review-x): DECISION note\" && printf x > .claude/human-review/u1/DECISION"
bash_case "D12 commit then write via ;" blocked antislop:reviewer \
  "git commit -m \"fix(human-review-x): DECISION note\" ; printf x > .claude/human-review/u1/DECISION"
bash_case "D13 commit then cd-relative write" blocked antislop:reviewer \
  "git commit -m \"fix(human-review-x): DECISION note\" && cd .claude/human-review/u1 && printf x > DECISION"
bash_case "D14 commit with stdout redirected at the path" blocked antislop:reviewer \
  "git commit -m \"fix(human-review-x): DECISION note\" > .claude/human-review/u1/DECISION"
bash_case "D15 commit with stderr redirected at the path" blocked antislop:reviewer \
  "git commit -m \"fix(human-review-x): DECISION note\" 2> .claude/human-review/u1/DECISION"
bash_case "D16 command substitution in the message" blocked antislop:reviewer \
  "git commit -m \"fix(human-review-x): \$(cat /etc/hostname) DECISION\""
bash_case "D17 backtick in the message" blocked antislop:reviewer \
  "git commit -m \"fix(human-review-x): \`id\` DECISION\""
bash_case "D18 -F at the path, bare" blocked antislop:reviewer \
  "git commit -F .claude/human-review/u1/DECISION"
# D19 is the sole-denier for has_path_shaped_occurrence(): the quoting hides the
# path from the surviving-trigger test, the words are `git commit`, and there is
# no redirection - delete the path-shape condition and this one write flips to
# allowed. Verified by mutation, which is why the quoted form is pinned here.
bash_case "D19 -F at the path, quoted (binds the path-shape scan)" blocked antislop:reviewer \
  "git commit -F '.claude/human-review/u1/DECISION'"
# D20 is the sole-denier for `second word must be commit`: its triggers are inert
# and its first word IS git, so deleting that half lets through a commit running
# hooks from a path of the caller's choosing (measured: blocked -> allowed).
bash_case "D20 git -c core.hooksPath=... commit (binds the subcommand test)" blocked \
  antislop:reviewer \
  "git -c core.hooksPath=/tmp/h commit -m \"fix(human-review-x): DECISION note\""
# D21 does NOT bind the first-word test, though it looks like it should: `env git
# commit` has second word `git`, so the subcommand half rejects it either way
# (measured - it stays blocked with the first-word check deleted). M3 is the case
# that actually binds it.
bash_case "D21 env prefix" blocked antislop:reviewer \
  "env git commit -m \"fix(human-review-x): DECISION note\""
bash_case "D22 pipeline into tee" blocked antislop:reviewer \
  "printf approved | tee .claude/human-review/u1/DECISION"
bash_case "D23 sh -c wrapping the commit" blocked antislop:reviewer \
  "sh -c \"git commit -m 'fix(human-review-x): DECISION note'\""
bash_case "D24 a command precedes git" blocked antislop:reviewer \
  "printf x; git commit -m \"fix(human-review-x): DECISION note\""
bash_case "D25 dot-segment target" blocked antislop:reviewer \
  "printf x > .claude/./human-review/u1/DECISION"
bash_case "D26 traversal target" blocked antislop:reviewer \
  "printf x > .claude/reviewed/../human-review/u1/DECISION"
bash_case "D27 double-slash target" blocked antislop:reviewer \
  "printf x > .claude//human-review/u1//DECISION"
bash_case "D28 quoted target" blocked antislop:reviewer \
  "printf x > '.claude/human-review/u1/DECISION'"
bash_case "D29 \$HOME in the message spells the path" blocked antislop:reviewer \
  "git commit -m \"see \$HOME/.claude/human-review/u1/DECISION\""
bash_case "D30 xargs" blocked antislop:reviewer \
  "printf '.claude/human-review/u1/DECISION' | xargs -I{} cp /tmp/x {}"

echo
echo "-- adjacent-fragment concatenation spells the path too (Q1-Q16) --"
# Bash CONCATENATES adjacent quoted and unquoted fragments into one word, so a
# path split across a quote boundary is the same path. A scan that ends a run at
# a quote sees two harmless halves and lets an allowlisted program write the real
# file - measured fail-open at e7deb42, which is why every direction of the split
# is pinned here rather than one representative. Two conditions carry a
# sole-denier proven by mutation: joining fragments in the path-shape scan (Q1
# and eleven others flip to allowed without it) and reading the quote-joined text
# in the substring early-exit (Q13 alone flips; Q12 flips under either).
bash_case "Q1 dir and file in two single-quoted fragments" blocked antislop:reviewer \
  "printf x > '.claude/human-review/u1/''DECISION'"
bash_case "Q2 single-quoted dir, double-quoted /file" blocked antislop:reviewer \
  "printf x > '.claude/human-review/u1'\"/DECISION\""
bash_case "Q3 both fragments double-quoted" blocked antislop:reviewer \
  "printf x > \".claude/human-review/u1/\"\"DECISION\""
bash_case "Q4 append rather than truncate" blocked antislop:reviewer \
  "echo approve >> '.claude/human-review/u1/'\"DECISION\""
bash_case "Q5 cat as the write primitive" blocked antislop:reviewer \
  "cat /etc/hostname > '.claude/human-review/u1/''DECISION'"
bash_case "Q6 gh as the write primitive" blocked antislop:reviewer \
  "gh issue view 1 > '.claude/human-review/u1/''DECISION'"
bash_case "Q7 head as the write primitive" blocked antislop:reviewer \
  "head -1 /etc/hostname > '.claude/human-review/u1/'\"DECISION\""
bash_case "Q8 [ as the write primitive" blocked antislop:reviewer \
  "[ -f x ] > '.claude/human-review/u1/''DECISION'"
bash_case "Q9 the directory itself split across three fragments" blocked antislop:reviewer \
  "printf x > '.claude/''human-review''/u1/'\"DECISION\""
bash_case "Q10 split target followed by a chained command" blocked antislop:reviewer \
  "printf x > '.claude/human-review/u1/''DECISION' && echo ok"
bash_case "Q11 split target with a trailing comment" blocked antislop:reviewer \
  "printf x > '.claude/human-review/u1/'\"DECISION\" # write it"
# Q12/Q13 split a trigger TOKEN rather than the slash between them, so the raw
# text spells neither `DECISION` nor `human-review` and the substring early-exit
# used to return before any recognizer ran. Measured ALLOW on the pre-change gate
# too, with real bash creating the file - so unlike Q1-Q11 these are not this
# unit's regressions, but they are the same word-assembly mechanism and the
# early-exit now reads the quote-joined text.
bash_case "Q12 the filename itself split three ways, quote types alternating" blocked \
  antislop:reviewer "printf x > '.claude/human-review/u1/'\"DEC\"'IS'\"ION\""
bash_case "Q13 the split falls inside human-review, not at the slash" blocked \
  antislop:reviewer "printf x > .claude/human-rev'iew'/u1/DECISION"
bash_case "Q14 an unquoted slash between two quoted fragments" blocked antislop:reviewer \
  "printf x > '.claude/human-review/u1'/'DECISION'"
bash_case "Q15 an empty leading fragment" blocked antislop:reviewer \
  "printf x > \"\"'.claude/human-review/u1/DECISION'"
# Q16: the same concatenation inside a commit message. The gate cannot resolve a
# target, so a spelled path is denied wherever it sits - C1-C8 stay allowed
# because their tokens are separated by whitespace, which no quoting undoes.
bash_case "Q16 a commit message whose fragments concatenate into the path" blocked \
  antislop:reviewer "git commit -m \"human-review\"\"/u1/DECISION\""

echo
echo "-- the same word-assembly shape via variables and braces (Q17-Q20) --"
# The two other expansions that assemble a word were flagged as untested. Both
# were measured against real bash rather than assumed. Q17 IS a live write (one
# word, no IFS character in it) and the path-shape scan denies it. Q19 and Q20
# are NOT: a brace expansion yielding more than one word makes the redirect
# ambiguous and bash writes nothing, and one yielding a single word is not
# expanded at all, so Q18's `{DECISION}` is a literally different filename.
bash_case "Q17 unquoted variable holding the whole path" blocked antislop:reviewer \
  "d='.claude/human-review/u1/DECISION'; printf x > \$d"
bash_case "Q18 brace expansion around the filename (not expanded by bash)" blocked \
  antislop:reviewer "printf x > .claude/human-review/u1/{DECISION}"
bash_case "Q19 brace expansion with a comma (measured: ambiguous redirect)" blocked \
  antislop:reviewer "printf x > .claude/human-review/u1/{DECISION,zz}"
# Q20 is R-5's class, not a new hole: the raw text spells DECISIO{N,}, never
# DECISION, so the substring early-exit fires before any recognizer runs. Bash
# expands it to two words and refuses the redirect as ambiguous (measured), so
# the ALLOW costs nothing. Pinned as an accepted residual, same as R5.
bash_case "Q20 brace expansion splitting the filename (accepted residual)" allowed \
  antislop:reviewer "printf x > .claude/human-review/u1/DECISIO{N,}"

echo
echo "-- the gh arm of the allowlist, reached through the inert-trigger write path (G1-G3) --"
# G1 is the positive: gh with an allowlisted subcommand, writing somewhere that
# is not this gate's file, mentioning both tokens only in a discarded comment.
bash_case "G1 gh issue view writing elsewhere, tokens in a comment only" allowed \
  antislop:reviewer \
  "gh issue view 1 > /tmp/hdg-note.txt # the human-review packet and its DECISION"
# G2/G3 are the negatives that bind the subcommand allowlist on this path: `api`
# and `run` are excluded (benign-command.sh:41-49) and must stay excluded even
# when the triggers are inert, since neither's writes are bounded by its text.
bash_case "G2 gh api reached through the same path stays blocked" blocked \
  antislop:reviewer \
  "gh api repos/o/r/issues > /tmp/hdg-note.txt # the human-review packet and its DECISION"
bash_case "G3 gh run download reached through the same path stays blocked" blocked \
  antislop:reviewer \
  "gh run download 1 > /tmp/hdg-note.txt # the human-review packet and its DECISION"

echo
echo "-- backslash and comment attacks that must stay denied (X1-X3) --"
# X1: the comment mask ends at the newline, so the second line is still code.
bash_case "X1 a comment ending at the newline before a real write" blocked \
  antislop:reviewer "printf ok > /tmp/hdg-note.txt # human-review DECISION
cd .claude/human-review/u1 && printf x > DECISION"
# X2: a # inside a quoted span is NOT a comment. Were it masked as one, the mask
# would swallow `> DECISION` too, no trigger would survive, and printf/echo being
# allowlisted the gate would allow a command that really writes ./DECISION -
# which IS the protected file whenever the cwd is the packet directory.
bash_case "X2 a quoted # that is not a comment (binds the mask boundary)" blocked \
  antislop:reviewer "echo '#human-review' > DECISION"
bash_case "X3 eval with a quoted payload" blocked antislop:reviewer \
  "eval 'cd .claude/human-review/u1 && printf x > DECISION'"

echo
echo "-- each remaining new condition, bound by a case only it denies (M1-M3) --"
# M1: sole-denier for the surviving-trigger test. The comment is masked, so the
# ONLY trigger left in the skeleton is `DECISION` as a redirection target, with
# printf allowlisted and no path-shaped run anywhere. Delete that condition and
# real bash writes ./DECISION.
bash_case "M1 cd-relative write whose only mention is a comment decoy" blocked \
  antislop:reviewer "printf x > DECISION # human-review packet"
# M2: sole-denier for is_prose_only_commit()'s no-redirection / one-segment test
# (one `case` covers both). Triggers are inert and the words are `git commit`,
# so nothing else denies a commit whose stdout is aimed at a caller-built path.
bash_case "M2 prose commit with its stdout redirected elsewhere" blocked \
  antislop:reviewer \
  "git commit -m \"fix(human-review-x): DECISION note\" > /tmp/hdg-out.txt"
# M3: sole-denier for `first word must be git`. The allowance is anchored to git
# specifically, NOT to "second word is commit" - otherwise any program at all
# could be waved through by naming its subcommand `commit`. Measured: deleting
# the first-word check flips this to allowed.
bash_case "M3 an arbitrary program whose second word is commit" blocked \
  antislop:reviewer \
  "./tools/release commit -m \"fix(human-review-x): DECISION note\""

echo
echo "-- pinned residuals: unchanged ALLOW (R5, B2, B3) --"
# R-5, decision B: bash resolves \\N to N and writes the file, but the raw text
# never spells DECISION, so the substring early-exit fires before any of this
# gate's logic. Measured ALLOW both before and after this change, so it is NOT a
# regression - it is an accepted, tracked limitation of the same family as N21.
# Closing it needs backslash normalization ahead of the early-exit on every Bash
# command in the session, and would still leave N21 open.
bash_case "R5 DECISIO\\N escapes the substring early-exit (accepted residual)" allowed \
  antislop:reviewer "printf x > .claude/human-review/u1/DECISIO\\N"
# B2/B3 pin the early-exit itself: it takes BOTH tokens to engage this gate, which
# is what made the verdict on a commit turn entirely on message prose.
bash_case "B2 commit whose message carries neither token" allowed antislop:reviewer \
  "git commit -m 'fix(cleanup-1): tidy up'"
bash_case "B3 commit whose message carries one token only" allowed antislop:reviewer \
  "git commit -m 'fix(human-review-cleanup-1): tidy up'"

echo
echo "-- widened charclass: dots and hashes in id (N24-N27) --"
bash_case "N24 id with a dot (e.g. gh345.1)" allowed antislop:reviewer \
  "cat > .claude/reviewed/gh345.1.pass <<'EOF'
PASS gh345.1 2026-08-13T00:00:00Z commit: abc123 criteria: bash tests/validate.sh
human: quoting .claude/human-review/u1/DECISION verbatim:
EOF"
bash_case "N25 id with a hash (e.g. gh#348)" allowed antislop:reviewer \
  "cat > .claude/reviewed/gh#348.pass <<'EOF'
PASS gh#348 2026-08-13T00:00:00Z commit: abc123 criteria: bash tests/validate.sh
human: quoting .claude/human-review/u1/DECISION verbatim:
EOF"
bash_case "N26 leading-dot id rejected (.gh345)" blocked antislop:reviewer \
  "cat > .claude/reviewed/.gh345.pass <<'EOF'
PASS .gh345 2026-08-13T00:00:00Z commit: abc123 criteria: bash tests/validate.sh
human: quoting .claude/human-review/u1/DECISION verbatim:
EOF"
bash_case "N27 traversal with leading dots rejected (..345)" blocked antislop:reviewer \
  "cat > .claude/reviewed/..345.pass <<'EOF'
PASS ..345 2026-08-13T00:00:00Z commit: abc123 criteria: bash tests/validate.sh
human: quoting .claude/human-review/u1/DECISION verbatim:
EOF"

echo
echo "-- every block logs decision-gate-denied, reviewer included --"
audit_log="$proj/.claude/review-audit.log"
: > "$audit_log"
write_case "case j audit: reviewer blocked Write logs decision-gate-denied" blocked \
  antislop:reviewer ".claude/human-review/u1/DECISION"
if grep -q "decision-gate-denied identity=antislop:reviewer" "$audit_log"; then
  pass "case j decision-gate-denied line logged for reviewer"
else
  bad "case j no decision-gate-denied line found in audit log"
fi

echo
exit "$fail"
