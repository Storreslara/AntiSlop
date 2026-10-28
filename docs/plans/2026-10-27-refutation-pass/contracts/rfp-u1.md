Unit: rfp-u1

## Objective
Ship `bin/refutation-brief.sh`, installed to `.claude/bin/`. It is the one deterministic source of the
prompt that the reviewer's refutation pass gives the `explorer` it spawns (plan D8). The eval replay
(rfp-u2) uses the same script, so the replay measures exactly the brief that ships.

The script reads 1 to 3 `D<n>: <file:line> <claim>` lines on stdin and takes the baseline as its argument.
It prints a fixed brief: the baseline and reviewed shas, the changed files, the three questions, the answer
grammar, the UNCERTAIN and artifact rules and the 10-turn note. It exits 2 with nothing on stdout for 0
lines, for more than 3 lines or a D-number above 3 (`over-cap`), for a malformed or repeated line, and for
a bad baseline. It writes nothing.

This unit changes no persona text. Nothing calls the script until rfp-u3, so shipping it is inert.

## Retrieval
Fast path, no tracker issue. Spec: `docs/plans/2026-10-27-refutation-pass.md` ("Step 1", "Per-defect
protocol", D4, D8). This file is the contract of record. It has no dependency and can be dispatched in
parallel with rfp-u2 only if rfp-u2's run.sh dry-run is not exercised before this unit lands (rfp-u2
criterion 4 needs the script). The safe order is rfp-u1 then rfp-u2.

## Affected files
- `bin/refutation-brief.sh` (anchor: new file, mode 755)
- `tests/refutation-brief.test.sh` (anchor: new file, mode 755)
- `bin/cli.js` (anchor: line matching `const BIN_HELPER_FILES = [`)
- `tests/bin-helpers-scaffold.test.sh` (anchors: line matching `FILES="ladder-tier.sh`; line matching `if check_files; then ok "(a) nine helpers present"`)
- `tests/validate.sh` (anchor: line matching `echo "== review-precheck: the reviewer's mechanical pre-review, failure lines are FAIL grounds (Bash, st-u2) =="`)
- `.claude-plugin/plugin.json`, `package.json`, `CHANGELOG.md`
- generated only, by `node bin/cli.js --update`: `.claude/bin/refutation-brief.sh`, `.claude/agents/*.md` stamp lines, `.claude/persona-protocol*.md`, `.claude/protocol-digest.md`, the config's `fileHashes` and `pluginVersion`

## Ordered edits
1. file: `tests/refutation-brief.test.sh` (new, mode 755), content:
~~~
#!/usr/bin/env bash
# Fixture suite for bin/refutation-brief.sh (rfp-u1). Every case runs in a scratch git repo, never this tree.
set -uo pipefail
cd "$(dirname "$0")/.."
script="$(pwd)/${BRIEF_UNDER_TEST:-bin/refutation-brief.sh}"
fail=0
ok()  { echo "OK   $*"; }
bad() { echo "FAIL $*"; fail=1; }

tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT
repo="$tmp/repo"
mkdir -p "$repo/src"
( cd "$repo" && git init -q . && printf 'a\n' > src/a.sh && git add -A \
  && git -c user.email=t@t -c user.name=t commit -q -m base \
  && printf 'a\nb\n' > src/a.sh && git -c user.email=t@t -c user.name=t commit -q -am change )
base="$(cd "$repo" && git rev-parse HEAD~1)"

run() { # <stdin text> <args...> -> sets out, err, rc
  local input="$1"; shift
  out="$(cd "$repo" && printf '%s' "$input" | bash "$script" "$@" 2>"$tmp/err")"; rc=$?
  err="$(cat "$tmp/err")"
}

# (a) two valid defects: exit 0, both D-lines, the baseline sha, the changed file, the rules and the grammar
run $'D1: src/a.sh:2 b is unquoted\n\nD2: src/a.sh:1-2 no guard on empty input\n' "$base"
if [ "$rc" = 0 ] \
   && printf '%s\n' "$out" | grep -qx 'D1: src/a.sh:2 b is unquoted' \
   && printf '%s\n' "$out" | grep -qx 'D2: src/a.sh:1-2 no guard on empty input' \
   && printf '%s\n' "$out" | grep -qx "Baseline: $base" \
   && printf '%s\n' "$out" | grep -qx -- '- src/a.sh' \
   && printf '%s\n' "$out" | grep -qF 'When unsure, answer UNCERTAIN, never CONFIRMED. A verdict with no artifact is UNCERTAIN.' \
   && printf '%s\n' "$out" | grep -qF 'D<n>: REFUTED|CONFIRMED|UNCERTAIN — q1=<yes|no> q2=<change|baseline> q3=<real|mitigated|n/a> — artifact:' \
   && printf '%s\n' "$out" | grep -qF "on why it stops this defect on" ; then
  ok "(a) valid brief"
else
  bad "(a) valid brief rc=$rc err=$err"
fi

# (b) four defects: over-cap, exit 2, nothing on stdout
run $'D1: src/a.sh:1 x\nD2: src/a.sh:1 y\nD3: src/a.sh:1 z\nD4: src/a.sh:1 w\n' "$base"
if [ "$rc" = 2 ] && [ -z "$out" ] && printf '%s' "$err" | grep -q 'over-cap'; then ok "(b) over-cap"; else bad "(b) over-cap rc=$rc"; fi

# (c) no defect lines
run $'\n\n' "$base"
if [ "$rc" = 2 ] && [ -z "$out" ]; then ok "(c) empty stdin"; else bad "(c) empty stdin rc=$rc"; fi

# (d) malformed line (no file:line)
run $'D1: the code is wrong\n' "$base"
if [ "$rc" = 2 ] && printf '%s' "$err" | grep -q 'malformed'; then ok "(d) malformed"; else bad "(d) malformed rc=$rc"; fi

# (e) baseline that is not a commit
run $'D1: src/a.sh:1 x\n' deadbeefdeadbeef
if [ "$rc" = 2 ] && printf '%s' "$err" | grep -q 'not a commit'; then ok "(e) bad baseline"; else bad "(e) bad baseline rc=$rc"; fi

# (f) repeated D-number
run $'D1: src/a.sh:1 x\nD1: src/a.sh:2 y\n' "$base"
if [ "$rc" = 2 ] && printf '%s' "$err" | grep -q 'repeated D1'; then ok "(f) repeated id"; else bad "(f) repeated id rc=$rc"; fi

# (g) D-number above 3, even with fewer than 4 lines
run $'D7: src/a.sh:1 x\n' "$base"
if [ "$rc" = 2 ] && printf '%s' "$err" | grep -q 'over-cap'; then ok "(g) D-number cap"; else bad "(g) D-number cap rc=$rc"; fi

# (h) deterministic and writes nothing
run $'D1: src/a.sh:2 b\n' "$base"; first="$out"
run $'D1: src/a.sh:2 b\n' "$base"
st="$(cd "$repo" && git status --porcelain)"
if [ "$first" = "$out" ] && [ -z "$st" ]; then ok "(h) deterministic, no writes"; else bad "(h) deterministic, no writes"; fi

# (i) no baseline argument
run $'D1: src/a.sh:1 x\n'
if [ "$rc" = 2 ] && printf '%s' "$err" | grep -q 'usage'; then ok "(i) no baseline"; else bad "(i) no baseline rc=$rc"; fi

if [ "$fail" -eq 0 ]; then echo "All refutation-brief checks passed."; else echo "refutation-brief: FAILED"; fi
exit "$fail"
~~~
   Run `bash tests/refutation-brief.test.sh`: it must exit 1 (the script does not exist yet). This is the red step.
2. file: `bin/refutation-brief.sh` (new, mode 755), content:
~~~
#!/usr/bin/env bash
# Refutation brief (rfp-u1): prints the prompt the reviewer gives the `explorer` it spawns for the
# refutation pass (agents/reviewer.md, "Refutation pass"). The eval replay
# (eval/refutation-replay/run.sh) uses the same script, so the replay tests exactly the brief that ships.
# Usage: printf 'D1: <file:line> <claim>\n' | bin/refutation-brief.sh <baseline>
# Reads 1 to 3 defect lines on stdin (blank lines ignored), each `D<1-3>: <path>:<line>[-<line>] <claim>`.
# Prints the brief on stdout and exits 0. Writes nothing. Run from the repo root of the reviewed tree.
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
Batch independent reads in parallel: you have at most 10 turns.
Reply with exactly one line per defect, in this form, then your STATUS line:
D<n>: REFUTED|CONFIRMED|UNCERTAIN — q1=<yes|no> q2=<change|baseline> q3=<real|mitigated|n/a> — artifact: <command and output line, or file:line quote>

Defects:
EOF
printf '%s\n' "${defects[@]}"
exit 0
~~~
3. file: `bin/cli.js`
   before: `'review-precheck.sh', 'unit-size.sh'];`
   after: `'review-precheck.sh', 'unit-size.sh', 'refutation-brief.sh'];`
4. file: `tests/bin-helpers-scaffold.test.sh`
   before: `review-precheck.sh unit-size.sh"`
   after: `review-precheck.sh unit-size.sh refutation-brief.sh"`
5. file: `tests/bin-helpers-scaffold.test.sh`
   before: `if check_files; then ok "(a) nine helpers present"; else bad "(a) nine helpers present"; fi`
   after: `if check_files; then ok "(a) ten helpers present"; else bad "(a) ten helpers present"; fi`
6. file: `tests/validate.sh`
   anchor: line matching `echo "== review-precheck: the reviewer's mechanical pre-review, failure lines are FAIL grounds (Bash, st-u2) =="`
   indent: 0
   insert-before:
~~~
echo "== refutation-brief: the explorer prompt for the reviewer's refutation pass, caps and grammar (Bash, rfp-u1) =="
if bash tests/refutation-brief.test.sh > /dev/null; then
  echo "OK   tests/refutation-brief.test.sh"
else
  echo "FAIL tests/refutation-brief.test.sh"
  fail=1
fi

echo
~~~
7. command: `perl -0pi -e 's/("version": "\d+\.\d+\.)(\d+)"/$1.($2+1)."\""/e' .claude-plugin/plugin.json package.json`
   expect: 0
   Adds one to the patch version in both files (+1 on whatever is current at dispatch). This is not P3-required
   (no stamped path is touched), but `--update` must see a new version to install the new helper.
8. file: `CHANGELOG.md`
   anchor: line matching `## [Unreleased]`
   indent: 0
   insert-after:
~~~

**Refutation brief helper (rfp-u1, VERSION).** New `bin/refutation-brief.sh`, installed to `.claude/bin/`: it reads 1 to 3 `D<n>: <file:line> <claim>` lines on stdin and prints the fixed prompt for the reviewer's refutation pass (baseline, changed files, the three questions, the answer grammar, "when unsure, answer UNCERTAIN, never CONFIRMED"); it exits 2 on 0 lines, more than 3 (`over-cap`), malformed or repeated lines, or a bad baseline, and writes nothing. Nothing calls it yet (rfp-u3 does). `tests/refutation-brief.test.sh` covers it; spec `docs/plans/2026-10-27-refutation-pass.md`.
~~~
   Replace `VERSION` with the version edit 7 wrote.
9. command: `node bin/cli.js --update`
   expect: 0
10. command: `git add bin/refutation-brief.sh tests/refutation-brief.test.sh .claude/bin/refutation-brief.sh bin/cli.js tests/bin-helpers-scaffold.test.sh tests/validate.sh .claude-plugin/plugin.json package.json CHANGELOG.md && git add -u -- .claude ':(exclude).claude/agent-memory' && git commit -m "feat(rfp-u1): refutation brief helper, the explorer prompt for the reviewer's refutation pass"`
   expect: 0
   Run `git status --short` first. If a tracked file outside "Affected files" is modified, stop and report it.
   Keep `(rfp-u1)` in every fix-round commit subject.

## Do NOT touch
- `agents/` and `templates/` (no persona text changes in this unit; criterion 4)
- `hooks/` and `adapters/` (criterion 4)
- `eval/` (rfp-u2's; criterion 4)
- `.claude/bin/` and `.claude/agents/` by hand (only `node bin/cli.js --update` writes them)

## Acceptance criteria
1. run: `bash -c 'bash tests/refutation-brief.test.sh >/dev/null; echo $?'`
   exit: 0
   stdout: `0`
   mutation: delete the `for d in "${defects[@]}"` D-number loop in `bin/refutation-brief.sh`; case (g) prints `FAIL (g) D-number cap` and stdout is `1`. Replacing `When unsure, answer UNCERTAIN, never CONFIRMED.` with `When unsure, answer UNCERTAIN.` fails case (a). spec-master ran both mutations on a scratch copy.
2. run: `cmp bin/refutation-brief.sh .claude/bin/refutation-brief.sh`
   exit: 0
   stdout: empty
   mutation: skip edit 3; `--update` installs nothing, so cmp reports the missing file and exits 2.
3. run: `bash -c 'bash tests/bin-helpers-scaffold.test.sh >/dev/null; echo $?'`
   exit: 0
   stdout: `0`
   mutation: skip edit 3; the fresh scaffold has no `.claude/bin/refutation-brief.sh`, case (a) fails and stdout is `1`.
4. run: `bash -c 'b=$(git log --format=%H --grep="(rfp-u1)" | tail -1); l=$(git log --format=%H --grep="(rfp-u1)" | head -1); [ -n "$b" ] || { echo no-commits; exit 1; }; git diff --name-only "$b^..$l" -- agents templates hooks adapters eval | wc -l'`
   exit: 0
   stdout: `0`
   mutation: edit `agents/reviewer.md` in an rfp-u1 commit; stdout is at least `1`.
5. run: `bash -c 'bash tests/validate.sh >/dev/null 2>&1; echo $?'` (Bash tool timeout 600000 ms)
   exit: 0
   stdout: `0`
   mutation: put `exit 1` as line 2 of `tests/refutation-brief.test.sh`; validate.sh reports it (edit 6) and stdout is `1`.

## Pre-resolved context
- Precedent for a new `.claude/bin/` helper: st-u2 (`docs/plans/antislop-structural/contracts/st-u2.md`,
  edits 4 and 11): `BIN_HELPER_FILES` in `bin/cli.js:656` plus `tests/bin-helpers-scaffold.test.sh:15,22`.
- spec-master ran both payloads in a scratch git repo: all 9 cases pass (`bash -n` is clean), and the two
  mutations in criterion 1 each turn one case red.
- The em dashes in the answer grammar are U+2014, as in the reviewer prose. Keep the file UTF-8.
- `tests/validate.sh` runs as lanes split on its `== ` headers (vsp-1). The new block is a self-contained
  section with its own header.
- The `D<n>` grammar is `^D([1-9]): <path>:<line>[-<line>] <claim>$`, then a separate 1-to-3 check. A
  D-number above 3 is reported as `over-cap`, not as malformed.

## Escalation
If a `before:` or anchor text is not found exactly once, stop and report the current text. If
`node bin/cli.js --update` refuses, quote its message and stop. If a gate blocks a command, report it and
wait. Anything outside "Affected files" goes in your report as a proposal.
