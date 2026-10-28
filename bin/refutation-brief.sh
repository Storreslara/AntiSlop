#!/usr/bin/env bash
# Refutation brief (rfp-u1; tool-call budget rfp-u1b): prints the prompt the reviewer gives the `explorer`
# it spawns for the refutation pass (agents/reviewer.md, "Refutation pass"). The eval replay
# (eval/refutation-replay/run.sh) uses the same script, so the replay tests exactly the brief that ships.
# Usage: printf 'D1: <file:line> <claim>\n' | bin/refutation-brief.sh <baseline>
# Reads 1 to 3 defect lines on stdin (blank lines ignored, a trailing CR dropped), each
# `D<1-3>: <path>:<line>[-<line>] <claim>`.
# Prints the brief on stdout and exits 0. Writes nothing. Run from the repo root of the reviewed tree.
# The brief states a budget of 9 tool calls in all, split evenly per defect (9, 4 or 3), because a
# headless run's num_turns is 1 plus its tool calls and Gate G fails any run above 10.
# Exits 2, with one `refutation-brief: <reason>` line on stderr and nothing on stdout, on: no baseline,
# a baseline that is not a commit, no defect line, more than 3 (`over-cap`), a malformed line, or a
# repeated D-number.
set -uo pipefail

die() { echo "refutation-brief: $*" >&2; exit 2; }

base="${1:-}"
[ -n "$base" ] || die "usage: refutation-brief.sh <baseline> (defect lines on stdin)"
git rev-parse --verify --quiet "${base}^{commit}" >/dev/null || die "baseline is not a commit: $base"

defects=()
seen=" "
while IFS= read -r line || [ -n "$line" ]; do
  line="${line%$'\r'}"
  [ -n "${line//[[:space:]]/}" ] || continue
  [[ $line =~ ^D([1-9]):\ [^[:space:]:]+:[0-9]+(-[0-9]+)?\ .+$ ]] || die "malformed defect line: $line"
  n="${BASH_REMATCH[1]}"
  case "$seen" in *" $n "*) die "repeated D$n" ;; esac
  seen="$seen$n "
  defects+=( "$line" )
done

[ "${#defects[@]}" -gt 0 ] || die "no defect lines on stdin"
[ "${#defects[@]}" -le 3 ] || die "over-cap: ${#defects[@]} defects, at most 3"
for d in "${defects[@]}"; do
  [[ $d =~ ^D([1-3]): ]] || die "over-cap: D-numbers run 1 to 3"
done
share=$(( 9 / ${#defects[@]} ))

changed="$(git diff --name-only "$base..HEAD" 2>/dev/null)" || die "cannot diff $base..HEAD"

cat <<EOF
Refutation brief. You are read-only: you own no verdict and write no file.
Baseline: $(git rev-parse "${base}^{commit}")
Reviewed: $(git rev-parse HEAD)
Changed files:
EOF
if [ -n "$changed" ]; then
  printf '%s\n' "$changed" | sed 's/^/- /'
else
  echo "- (none)"
fi
cat <<'EOF'

Try to DISPROVE each defect below. For each one, read the whole cited file and the callers of the cited
code (grep, or the graph), not only the cited line, and compare with the baseline
(git show <baseline>:<file>). Answer three questions:
(1) does the issue exist at the cited line?
(2) is it in the change, or already at the baseline?
(3) is the impact real, or already mitigated by a guard, an earlier validation or config elsewhere?
When unsure, answer UNCERTAIN, never CONFIRMED. A verdict with no artifact is UNCERTAIN. An artifact is a
command you ran plus its decisive output line, or a quoted file:line. For REFUTED by mitigation, the
artifact is the guard itself, quoted with its file:line, plus one clause on why it stops this defect on
this defect's own path.
EOF
printf 'Budget: at most 9 tool calls in all, and at most %d for each defect.\n' "$share"
cat <<'EOF'
Every tool call counts, including a refused call and each call in a parallel batch. You also have at most
10 turns, so batch independent calls into one turn.
When a defect's share is spent and a question is still open, stop work on it and answer UNCERTAIN, naming
the open question in the artifact. Do not spend another defect's share.
If reading the whole file would go over the share, read the part around the cited line and the places
grep finds for the cited code, and say in the artifact which part you read.
Reply with exactly one line per defect, in this form, with no line break inside it, then your STATUS line:
D<n>: REFUTED|CONFIRMED|UNCERTAIN — q1=<yes|no> q2=<change|baseline> q3=<real|mitigated|n/a> — artifact: <command and output line, or file:line quote>

Defects:
EOF
printf '%s\n' "${defects[@]}"
exit 0
