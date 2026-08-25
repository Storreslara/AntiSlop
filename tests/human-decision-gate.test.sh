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

# Overridable so the U-set mutation control can point the whole suite at a
# mutated scratch copy without editing the gate in place. Defaults to the real one.
gate="${GATE_UNDER_TEST:-hooks/scripts/human-decision-gate.sh}"

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
echo "-- FP-B: a prose-only git commit is allowed (C1-C12) --"
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
# C9-C12 bound has_whitespace_id_packet_path() from the allow side: it may only
# fire on text that really spells the path. C9's tokens are separated by prose
# carrying an apostrophe, C10's by a `;` (inside the quoted span, so the skeleton
# still sees one segment), and neither reaches a `/DECISION` at all.
bash_case "C9 both tokens in ordinary prose, dir named with its trailing slash" allowed \
  antislop:reviewer \
  "git commit -m \"note: .claude/human-review/ holds the human's own DECISION file\""
bash_case "C10 prose whose interstitial text carries a ;" allowed antislop:reviewer \
  "git commit -m 'human-review packet ; then the DECISION file'"
# C11 is the newline exclusion, and it is the ONLY thing keeping it allowed:
# every character between the two tokens here is otherwise path-safe. Add \n to
# the companion scan's charclass and this multi-line message flips to blocked.
bash_case "C11 multi-line message, second line a bare u1/DECISION (binds \\n exclusion)" \
  allowed antislop:reviewer "git commit -m \"human-review
u1/DECISION\""
# C12 is denied by has_path_shaped_occurrence(), NOT by the companion scan: the
# template's `<` and `>` are outside the path-safe charclass, and the whole
# literal is one unbroken run anyway. Pinned so a later reader does not read a
# denied commit message as evidence for the companion condition.
bash_case "C12 a message spelling the literal template path (run scan denies it)" blocked \
  antislop:reviewer "git commit -m \"see .claude/human-review/<task-id>/DECISION\""
# C13-C20 are the prose separators that decided which remedy shipped. Each puts a
# `/DECISION` after a `human-review` on ONE line, so the only thing keeping them
# allowed is that the head does not begin with `/`. Widening the path-safe
# charclass instead - the rejected candidate - re-denies all of them; the two the
# earlier report named verbatim are C13 and C14. They are the false positives the
# parent units exist to remove, so they are pinned rather than left to a sweep.
bash_case "C13 'human-review, /DECISION'" allowed antislop:reviewer \
  "git commit -m 'note human-review, /DECISION file'"
bash_case "C14 'human-review packet -> /DECISION'" allowed antislop:reviewer \
  "git commit -m 'note human-review packet -> /DECISION file'"
bash_case "C15 ': ' separator" allowed antislop:reviewer \
  "git commit -m 'note human-review: /DECISION file'"
bash_case "C16 '; ' separator" allowed antislop:reviewer \
  "git commit -m 'note human-review; /DECISION file'"
bash_case "C17 '(' separator" allowed antislop:reviewer \
  "git commit -m 'note human-review (/DECISION file)'"
bash_case "C18 ') ' separator" allowed antislop:reviewer \
  "git commit -m 'note (human-review) /DECISION file'"
bash_case "C19 ' => ' separator" allowed antislop:reviewer \
  "git commit -m 'note human-review => /DECISION file'"
bash_case "C20 ' | ' separator" allowed antislop:reviewer \
  "git commit -m 'note human-review | /DECISION file'"

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
# but is denied by the run scan first, so only P16-d binds the residual.
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
# D19 is NO LONGER a sole-denier for has_path_shaped_occurrence(), and it stopped
# being one when the companion scan landed rather than here: this path's head is
# `/u1`, which the companion scan's path-safe arm denies on its own. Re-measured
# on the pre-unit gate as well as this one - deleting the run scan call leaves
# D19 blocked at BOTH revisions, so the claim this comment used to make ("delete
# the path-shape condition and this one write flips to allowed") was already
# false before this unit. It stays as a regression pin for the quoted `-F` form;
# Q22 is the case that binds the run scan today.
bash_case "D19 -F at the path, quoted (regression pin; Q22 binds the run scan)" blocked \
  antislop:reviewer \
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
# is pinned here rather than one representative. Both conditions still carry a
# sole-denier proven by mutation, but one binding case MOVED when
# has_whitespace_id_packet_path() landed: that scan deletes quote characters
# itself, so reverting the fragment joining now flips NONE of Q1-Q20 (measured
# on this tree; it flipped fourteen of them before the companion scan existed,
# not the twelve an earlier version of this comment claimed). Q21 below is what
# binds the fragment joining today. The substring early-exit is untouched by any
# of that - Q12 and Q13 both flip to allowed when it reads the raw text again.
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
# word, no IFS character in it) and the run scan denies it. Q19 and Q20
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
echo "-- fragment joining, re-bound AGAIN now that the anchored arm exists (Q21-Q22) --"
# Q21 used to be the sole denier for fragment joining in
# has_path_shaped_occurrence(). It is NOT any more, and the binding MOVED for the
# second time: its id spells a `:`, so the companion scan's path-safe arm misses
# it, but the anchored arm now denies it on the head `/fix:thing` alone. Measured
# on this tree - reverting the joining leaves Q21 blocked. It stays as a
# regression pin; Q22 is what binds the joining today.
#
# This is the second time a NEW condition silently un-bound an OLD condition's
# proof in this file (the companion scan did it to fourteen cases when it
# landed). Re-run every existing mutant after adding a condition, not just the
# new one's - a mutation proof rots with the suite green the whole time.
bash_case "Q21 split path whose id carries a character outside the path-safe set" \
  blocked antislop:reviewer "printf x > '.claude/human-review/fix:thing/''DECISION'"
# Q22 IS the sole denier for fragment joining today: the two tokens concatenate
# with no `/` between them, so no `/DECISION` ever follows the `human-review` and
# the companion scan cannot fire on either arm - only the JOINED run sees both
# tokens in one word. Measured: blocked here, allowed with the joining reverted.
bash_case "Q22 the two tokens concatenated with no slash (binds fragment joining)" \
  blocked antislop:reviewer "printf x > '.claude/human-review''DECISION'"

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
echo "-- a whitespace-bearing task-id spells the path too (W1-W16) --"
# Nothing constrains the packet directory's NAME at creation time: the reviewer
# derives it from the free-form `Unit: <id>` dispatch line, dispatchHygiene.mode
# is "warn" rather than "block", and reviewer spawns are not gated by that
# grammar at all - so an id holding a space or a tab is off-convention but
# producible, and the Write/Edit branch's `*` glob already denies exactly these
# paths. The run scan structurally cannot see them, because it ends a run at
# whitespace even inside quotes - which is what keeps C1-C12 allowed - so
# has_whitespace_id_packet_path() covers the word shape beside it rather than
# in place of it. All sixteen were measured DENIED at the pre-unit baseline
# f6d2923 and ALLOWED with a real write at be9f027, so each is a regression pin.
#
# Mutation proof: delete the has_whitespace_id_packet_path call from
# triggers_are_inert() and fourteen of these flip to allowed. W1 is a sole
# denier - printf is allowlisted, no run of the text spells the path, and
# nothing else stands between it and the real file. W13/W14 are the two that do
# NOT flip: tee and cp are absent from the program allowlist and were already
# denied at HEAD, so they are a regression net, not evidence for the condition.
bash_case "W1 space in the id, single-quoted (sole denier for the companion scan)" \
  blocked antislop:reviewer "printf x > '.claude/human-review/u 1/DECISION'"
bash_case "W2 space in the id, double-quoted" blocked antislop:reviewer \
  "printf x > \".claude/human-review/u 1/DECISION\""
bash_case "W3 a two-word id" blocked antislop:reviewer \
  "cat /etc/hostname > '.claude/human-review/my unit/DECISION'"
# W4 concatenates a $'\t' fragment rather than embedding a raw tab, which no
# editor or trailing-whitespace check can silently eat.
bash_case "W4 tab in the id" blocked antislop:reviewer \
  "printf x > '.claude/human-review/u"$'\t'"1/DECISION'"
bash_case "W5 two consecutive spaces in the id" blocked antislop:reviewer \
  "printf x > '.claude/human-review/u  1/DECISION'"
bash_case "W6 the space split across a quote boundary" blocked antislop:reviewer \
  "printf x > '.claude/human-review/u '\"1/DECISION\""
bash_case "W7 double slash before the id segment" blocked antislop:reviewer \
  "printf x > '.claude/human-review//u 1/DECISION'"
bash_case "W8 dot-segment before the id segment" blocked antislop:reviewer \
  "printf x > '.claude/human-review/./u 1/DECISION'"
bash_case "W9 traversal before the id segment" blocked antislop:reviewer \
  "printf x > '.claude/human-review/x/../u 1/DECISION'"
bash_case "W10 leading ./ on the whole path" blocked antislop:reviewer \
  "printf x > './.claude/human-review/u 1/DECISION'"
bash_case "W11 dotted id plus a space" blocked antislop:reviewer \
  "printf x > '.claude/human-review/gh345.1 b/DECISION'"
bash_case "W12 append rather than truncate" blocked antislop:reviewer \
  "printf x >> '.claude/human-review/u 1/DECISION'"
bash_case "W13 tee (already denied by the program allowlist, not by this scan)" blocked \
  antislop:reviewer "tee '.claude/human-review/u 1/DECISION'"
bash_case "W14 cp (already denied by the program allowlist, not by this scan)" blocked \
  antislop:reviewer "cp /tmp/x '.claude/human-review/u 1/DECISION'"
bash_case "W15 trailing whitespace in the id segment" blocked antislop:reviewer \
  "printf x > '.claude/human-review/u1 /DECISION'"
bash_case "W16 leading whitespace in the id segment" blocked antislop:reviewer \
  "printf x > '.claude/human-review/ u1/DECISION'"

echo
echo "-- U-set: an id holding whitespace AND a character outside the path-safe set --"
# The third character dimension to cost this function a fail-open. W1-W16 above
# cover an id that is whitespace-bearing but otherwise path-safe; these ids carry
# BOTH, so they escaped the run scan on the whitespace and the path-safe arm of
# has_whitespace_id_packet_path() on the punctuation, and really wrote the file.
# Every one of them was measured ALLOW before the anchored arm landed.
#
# They are denied by the anchored arm, which tests the packet path's STRUCTURE
# rather than the id's characters: the head between `human-review` and the first
# `/DECISION` begins with `/`, because in the real path that character always
# does. Enumerating characters is what missed this class twice; the arm names
# none.
#
# MUTATION CONTROL (sole-denier proof for the anchored arm). Delete ONLY the arm
# in a scratch copy and point the suite at it. Copy lib/ alongside it: the gate
# sources lib/agent-identity.sh relative to its OWN path, so a bare copy into an
# empty directory dies at startup and every case "fails" with rc=1 - which looks
# like a kill but proves nothing. GATE_UNDER_TEST must be an ABSOLUTE path.
#
#   d="$(mktemp -d)"; cp -r hooks/scripts/lib "$d/"
#   n=$(grep -n '^          /\*) case ' hooks/scripts/human-decision-gate.sh | cut -d: -f1)
#   sed "$((n-1)),$((n+1))d" hooks/scripts/human-decision-gate.sh > "$d/mutant.sh"
#   GATE_UNDER_TEST="$d/mutant.sh" bash tests/human-decision-gate.test.sh; echo $?
#
# Expected: exit 1 with 130 FAIL lines - all 126 U cases, BA1, BA2, PD1 and PD2 -
# and each of the 128 case-level FAILs reading rc=0, i.e. the mutant really
# ALLOWED a write it should have blocked. An rc=1 anywhere means the mutant
# crashed and the run is void. U1 is a genuine SOLE denier: it is ALLOW on the
# pre-unit gate too, so with the arm gone nothing else in the pipeline stands
# between it and the real file.
u_puncts=(':' '!' ',' ';' '(' ')' '[' ']' '=' '@' '+' '%' '~' '^' '&' '*' '?' '<' '>' '{' '}')
u_n=0
for u_p in "${u_puncts[@]}"; do
  # mid-id, leading, trailing, and a nested segment - each still inside the
  # protected set, i.e. each matched by the Write/Edit branch's own `*` glob.
  for u_shape in "u${u_p} 1" "${u_p}u 1" "u 1${u_p}" "x${u_p}/u 1"; do
    u_n=$((u_n + 1))
    bash_case "U$u_n id [$u_shape]" blocked antislop:reviewer \
      "printf x > '.claude/human-review/${u_shape}/DECISION'"
  done
done
for u_p in "${u_puncts[@]}"; do
  u_n=$((u_n + 1))
  bash_case "U$u_n id [u${u_p}<tab>1]" blocked antislop:reviewer \
    "printf x > '.claude/human-review/u${u_p}"$'\t'"1/DECISION'"
  u_n=$((u_n + 1))
  bash_case "U$u_n id [u${u_p}<2 spaces>1]" blocked antislop:reviewer \
    "printf x > '.claude/human-review/u${u_p}  1/DECISION'"
done

echo
echo "-- after-hr family: OUTSIDE the protected set, correctly ALLOWED --"
# `.claude/human-review:/u 1/DECISION` names `human-review:`, a DIFFERENT
# directory, so it is not this gate's file - and the Write/Edit branch below
# ALLOWS it too, because it does not match `.claude/human-review/*/DECISION`.
# These are pinned as correct allowances, NOT as residuals: a later reader who
# "closes" them would be adding a false positive and breaking branch agreement,
# which is exactly what the rejected wider-charclass candidate did. They are
# also what keeps the branch-agreement assertion below non-vacuous, by putting
# both verdicts in its corpus rather than only `blocked`.
for u_p in "${u_puncts[@]}"; do
  u_n=$((u_n + 1))
  bash_case "U$u_n after-hr [human-review${u_p}] is a different dir (correct ALLOW)" \
    allowed antislop:reviewer \
    "printf x > '.claude/human-review${u_p}/u 1/DECISION'"
done

echo
echo "-- BRANCH AGREEMENT: the Bash verdict must EQUAL the Write/Edit verdict --"
# The binding, dimension-free criterion. Both prior fail-opens in
# has_whitespace_id_packet_path() came from a deny condition defined by
# ENUMERATING a character dimension (quote boundaries, then quoted whitespace,
# then interstitial punctuation); each time an unmodelled value of that
# dimension walked through. This criterion names no characters at all.
#
# The Write/Edit branch is the ORACLE: `.claude/human-review/*/DECISION` applied
# to a normalize_path()-resolved path is what this gate MEANS by the protected
# file. So the assertion is that the two verdicts are EQUAL - not that either is
# `blocked` - which is also why it cannot rot if the protected set is changed
# later. Measured 630 disagreements over this corpus before the anchored arm and
# 0 after; the corpus deliberately contains paths of both polarities (the
# after-hr family above is genuinely outside the set), so equality is a real
# constraint here rather than a tautology.
verdict_of() { # $1 = bash|write, $2 = payload; echoes allowed|blocked
  local vrc=0 vjson
  if [ "$1" = bash ]; then
    vjson="$(jq -n --arg a antislop:reviewer --arg c "$2" \
      '{tool_name:"Bash",agent_type:$a,tool_input:{command:$c}}')"
  else
    vjson="$(jq -n --arg a antislop:reviewer --arg p "$2" \
      '{tool_name:"Write",agent_type:$a,tool_input:{file_path:$p}}')"
  fi
  printf '%s' "$vjson" | CLAUDE_PROJECT_DIR="$proj" bash "$gate" >/dev/null 2>&1 || vrc=$?
  [ "$vrc" = 0 ] && echo allowed || echo blocked
}

ba_total=0
ba_bad=0
ba_allowed=0
for u_p in "${u_puncts[@]}"; do
  for ba_id in "u${u_p} 1" "${u_p}u 1" "u 1${u_p}" "x${u_p}/u 1" "u${u_p}1" \
               "u${u_p}"$'\t'"1"; do
    for ba_pfx in ".claude/human-review" "./.claude/human-review" \
                  ".claude//human-review" ".claude/./human-review" \
                  ".claude/x/../human-review"; do
      ba_path="$ba_pfx/$ba_id/DECISION"
      ba_b="$(verdict_of bash "printf x > '$ba_path'")"
      ba_w="$(verdict_of write "$ba_path")"
      ba_total=$((ba_total + 1))
      [ "$ba_b" = allowed ] && ba_allowed=$((ba_allowed + 1))
      if [ "$ba_b" != "$ba_w" ]; then
        ba_bad=$((ba_bad + 1))
        [ "$ba_bad" -le 5 ] && echo "     disagreement: bash=$ba_b write=$ba_w [$ba_path]"
      fi
    done
  done
  # the after-hr sibling of the same punctuation: both branches must ALLOW it
  ba_path=".claude/human-review${u_p}/u 1/DECISION"
  ba_b="$(verdict_of bash "printf x > '$ba_path'")"
  ba_w="$(verdict_of write "$ba_path")"
  ba_total=$((ba_total + 1))
  [ "$ba_b" = allowed ] && ba_allowed=$((ba_allowed + 1))
  if [ "$ba_b" != "$ba_w" ]; then
    ba_bad=$((ba_bad + 1))
    [ "$ba_bad" -le 5 ] && echo "     disagreement: bash=$ba_b write=$ba_w [$ba_path]"
  fi
done
if [ "$ba_bad" = 0 ]; then
  pass "BA1 Bash and Write/Edit agree on all $ba_total paths"
else
  bad "BA1 $ba_bad of $ba_total paths disagree between the Bash and Write/Edit branches"
fi
# Guards the assertion above against going vacuous: if the corpus ever collapses
# to one verdict, equality stops constraining anything. The after-hr family is
# what supplies the ALLOW side, so this count must be exactly that family.
if [ "$ba_allowed" = "${#u_puncts[@]}" ]; then
  pass "BA2 corpus spans both verdicts ($ba_allowed allowed of $ba_total)"
else
  bad "BA2 expected ${#u_puncts[@]} allowed paths in the corpus, got $ba_allowed of $ba_total"
fi

echo
echo "-- newline in the packet id: ALLOW, TRACKED-OPEN (not accepted) --"
# The one member of the U-set's class the anchored arm deliberately cannot close,
# and the one path in this suite where the two branches still disagree: Write
# DENIES it, Bash ALLOWS it, and real bash creates the file (verified with a
# sentinel, not just a verdict). Arm 1 misses it because newline is not
# path-safe, arm 2 because it excludes newline, and the run scan because newline
# is whitespace and resets the run.
#
# It is NOT closable here: arm 2's newline exclusion is exactly what keeps C11 -
# a multi-line commit message naming the two tokens on different lines - allowed,
# which is the false positive the parent units exist to remove. The two criteria
# are in genuine tension, so this is reported rather than patched around. Like
# F-1 below it is tracked-open, NOT accepted; a later unit that closes it is
# EXPECTED to flip this pin and delete this comment.
bash_case "NL1 newline in the packet id (branch disagreement, tracked-open)" allowed \
  antislop:reviewer "printf x > '.claude/human-review/a
b/DECISION'"

echo
echo "-- prose the anchored arm newly denies, by design (PD1-PD3) --"
# The arm's cost, pinned so it is visible rather than discovered. A message that
# writes `/` straight after `human-review` and reaches a `/DECISION` on the SAME
# line is now denied whatever punctuation sits between - previously the verdict
# depended on which punctuation the prose happened to use, since the path-safe
# arm already denied the `-` and space spellings of exactly these. So this is the
# same doctrine the gate already applied ("a spelled path is denied wherever it
# sits", C12), applied consistently rather than a new policy.
#
# Measured cost: 36 deltas over a 174-command prose/read/comment corpus, ALL of
# this one shape, and ZERO over all 813 commit messages in this repository's
# history. Reads are untouched, because command_is_provably_benign() answers them
# before this scan ever runs. A human hitting this puts the tokens on separate
# lines (C11) or drops the slash (C9/C10), both already allowed.
bash_case "PD1 prose naming the packet dir as a path, then /DECISION" blocked \
  antislop:reviewer "git commit -m 'note human-review/u1: /DECISION file'"
bash_case "PD2 the same shape in a trailing comment" blocked antislop:reviewer \
  "printf ok > /tmp/hdg-note.txt # note human-review/u1 => /DECISION"
# PD3 is the control that keeps PD1/PD2 honest: identical prose, tokens NOT
# spelled as a path (no slash after the token), stays allowed.
bash_case "PD3 the same prose without the slash stays allowed" allowed antislop:reviewer \
  "git commit -m 'note human-review, u1: /DECISION file'"

echo
echo "-- F-1 glob metacharacters: ALLOW, TRACKED-OPEN (not accepted) --"
# Unlike R5/N21/Q20 above, these are NOT ratified as acceptable. They are
# deferred with their own scope (docs/plans/2026-08-24-debug-hdg-prose-2-
# whitespace-id.md Part 4). Bash expands the glob against the filesystem and
# OVERWRITES a decision the human has already made, but the raw text never
# spells a trigger token, so the substring early-exit returns before any
# recognizer runs. Measured byte-identical at f6d2923, e7deb42 and HEAD, so the
# class is no unit's regression and is not this unit's to close. A later unit
# that closes F-1 is EXPECTED to break these four pins: flip them to `blocked`
# and delete this comment rather than working around them.
bash_case "F1a bracket around the first letter of the filename" allowed antislop:reviewer \
  "printf x > .claude/human-review/u1/[D]ECISION"
bash_case "F1b ? in place of the first letter" allowed antislop:reviewer \
  "printf x > .claude/human-review/u1/?ECISION"
bash_case "F1c a trailing * on the filename" allowed antislop:reviewer \
  "printf x > .claude/human-review/u1/DEC*"
bash_case "F1d the bracket in the directory component instead" allowed antislop:reviewer \
  "printf x > .claude/human-rev[i]ew/u1/DECISION"

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
