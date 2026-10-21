Unit: st-u2

## Objective
The reviewer's deterministic checks become one script that the reviewer runs itself (spec Step 2, variation
f, alternative f-B). New `bin/review-precheck.sh <unit> <baseline> [--contract <path>] [--fix-contract <path>]
[--affected <path>]... [--criterion <n>]` is installed to `.claude/bin/` through `BIN_HELPER_FILES`. It prints
the **precheck packet** and copies it to `.claude/bookkeeping/<unit>.precheck`:
- line 1 `precheck: result=<pass|fail> unit=<u> range=<b>..<sha> fails=<n> deferred=<n> judge=<n>`;
- `contract:` lines, the contract being read from the baseline commit (a contract edited since the baseline
  is a failure);
- `changed:` and `scope: ok <class>|out|judge` lines from st-u1's `us_classify`; `scope: no-affected-list`
  when there is no list;
- `size:`, `sensitive:` and `version-stamp:` lines;
- `criterion <n>: pass|fail|deferred long|judge` lines for the contract's criteria. A criterion whose `run:`
  line carries `(Bash tool timeout` is deferred and run on its own with `--criterion <n>`.

`agents/reviewer.md` gains the bullet "Run the mechanical pre-review first": each failure line is a FAIL ground
on its own, returned without reading the code; criteria the script passed are not re-run; code is read only
for judgment. The protocol's reuse rule (as amended by qw-u5) gains one sentence. Independence is kept: the
reviewer runs the script itself, as it runs `blast-radius.sh`. The codex and cursor reviewer ports install no
`.claude/bin/` and are not edited.

## Retrieval
Fast path, no tracker issue. Spec: `docs/plans/antislop-structural/spec.md`, "Step 2 (st-u2)" and "Context, f".
This file is the contract of record. Dispatch it only after st-u1 has reached PASS; qw-u5 must have landed
(edits 4 to 7 anchor on its text).

## Affected files
- `tests/review-precheck.test.sh` (anchor: new file, mode 755)
- `bin/review-precheck.sh` (anchor: new file, mode 755)
- `bin/cli.js` (anchor: line matching `const BIN_HELPER_FILES = [`)
- `tests/bin-helpers-scaffold.test.sh` (anchor: line matching `FILES="ladder-tier.sh`)
- `agents/reviewer.md` (anchor: line matching `- **Scope the review with the blast-radius script**: run`)
- `templates/persona-protocol.md` (anchor: line matching `stays open; it never takes a blast radius from the dispatch, the orchestrator`)
- `tests/validate.sh` (anchor: line matching `echo "== scope-libs: sensitive-path class and unit-scope classes shared by precheck and scope gate (Bash, st-u1) =="`)
- `.claude-plugin/plugin.json`, `package.json`, `CHANGELOG.md`
- generated only, by `node bin/cli.js --update`: `.claude/bin/review-precheck.sh`, `.claude/agents/*.md` (every full-tier mirror inlines "Structural questions"; reviewer also its body), `.claude/persona-protocol.md`, `.claude/protocol-digest.md`, the config's `fileHashes` and `pluginVersion`

## Ordered edits
1. file: `tests/review-precheck.test.sh`
   anchor: new file (mode 755)
   indent: 0
   insert-after:
~~~
#!/usr/bin/env bash
# review-precheck.sh (st-u2): the reviewer's mechanical pre-review. Cases (a) to (i) run in a temp repo
# with a committed contract; (j) reads the reviewer and protocol prose.
set -uo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
PC="$ROOT/bin/review-precheck.sh"
fail=0
ok()  { echo "OK   $*"; }
bad() { echo "FAIL $*"; fail=1; }
T="$(mktemp -d)"; trap 'rm -rf "$T"' EXIT
cd "$T" || exit 1
g() { git -c user.email=t@t -c user.name=t "$@"; }
git init -q . && mkdir -p src test docs/plans/p/contracts hooks
printf 'a\n' > src/a.js && printf 'ok\n' > test/a.test.sh
cat > docs/plans/p/contracts/u1.md << 'MD'
Unit: u1

## Affected files
- `src/a.js`
- `test/a.test.sh`

## Acceptance criteria
1. run: `bash -c 'grep -c b src/a.js'`
   exit: 0
   stdout: `1`
   mutation: none
2. run: `bash -c 'test -f src/a.js'`
   exit: 0
   stdout: empty
   mutation: none
3. run: `bash -c 'echo slow'` (Bash tool timeout 600000 ms)
   exit: 0
   stdout: `slow`
   mutation: none
4. run: `bash -c 'echo hi'`
   exit: 0
   stdout: prints a greeting
   mutation: none
MD
g add -A && g commit -q -m base && BASE="$(git rev-parse HEAD)"
C=docs/plans/p/contracts/u1.md
export CLAUDE_PROJECT_DIR="$T"
first() { printf '%s\n' "$1" | head -n1; }

printf 'a\nb\n' > src/a.js && g commit -qam 'u1: b'
out="$(bash "$PC" u1 "$BASE" --contract "$C")"; rc=$?
[ "$rc" = 0 ] && ok "(a) exit 0" || bad "(a) exit $rc"
[ "$(first "$out")" = "precheck: result=pass unit=u1 range=$BASE..$(git rev-parse HEAD) fails=0 deferred=1 judge=1" ] && ok "(a) header" || bad "(a) header: $(first "$out")"
for l in 'changed: src/a.js' 'scope: ok src/a.js listed' 'size: files=1 lines=1 binary=0' 'criterion 1: pass exit=0' 'criterion 2: pass exit=0' 'criterion 3: deferred long' 'criterion 4: judge stdout exit=0'; do
  printf '%s\n' "$out" | grep -qxF -- "$l" && ok "(a) $l" || bad "(a) missing: $l"
done
cmp -s <(printf '%s\n' "$out") "$T/.claude/bookkeeping/u1.precheck" && ok "(a) packet file equals stdout" || bad "(a) packet file differs"

[ "$(bash "$PC" u1 "$BASE" --contract "$C" --criterion 3)" = 'criterion 3: pass exit=0' ] && ok "(b) --criterion runs a deferred one" || bad "(b) --criterion 3"

printf 'x\n' > CONTEXT.md && printf 'h\n' > hooks/g.sh && g add -A && g commit -q -m 'leak'
out="$(bash "$PC" u1 "$BASE" --contract "$C")"
printf '%s\n' "$out" | grep -qxF 'scope: out CONTEXT.md' && ok "(c) out-of-scope file" || bad "(c) out-of-scope file"
printf '%s\n' "$out" | grep -qxF 'sensitive: hooks/g.sh' && ok "(c) sensitive path" || bad "(c) sensitive path"
first "$out" | grep -q '^precheck: result=fail .* fails=2 ' && ok "(c) result=fail fails=2" || bad "(c) header: $(first "$out")"
mkdir -p "$T/.claude/reviewed" && printf 'FAIL u1 2026-10-20T00:00:00Z\ntier: sonnet\n- CONTEXT.md:1 needs the term\n' > "$T/.claude/reviewed/u1.fail"
bash "$PC" u1 "$BASE" --contract "$C" | grep -qxF 'scope: ok CONTEXT.md fail-record' && ok "(c) path named by the .fail record" || bad "(c) fail-record class"
rm -rf "$T/.claude/reviewed"

g reset -q --hard HEAD~1
printf 'z\n' > src/a.js && g commit -qam 'u1: no b'
out="$(bash "$PC" u1 "$BASE" --contract "$C")"
printf '%s\n' "$out" | grep -qxF 'criterion 1: fail exit=1 want=0' && ok "(d) exit mismatch is a fail line" || bad "(d) exit mismatch"
printf 'b\nb\n' > src/a.js && g commit -qam 'u1: two b'
bash "$PC" u1 "$BASE" --contract "$C" | grep -q '^criterion 1: fail stdout want=1 got=2$' && ok "(d) stdout mismatch is a fail line" || bad "(d) stdout mismatch"

printf 'a\nb\n' > src/a.js && sed -i 's/grep -c b/grep -c a/' "$C" && g commit -qam 'u1: weaken criterion'
out="$(bash "$PC" u1 "$BASE" --contract "$C")"
printf '%s\n' "$out" | grep -qxF "contract: changed-since-baseline $C" && ok "(e) contract edited after the baseline" || bad "(e) contract edit not flagged"
printf '%s\n' "$out" | grep -qxF 'criterion 1: pass exit=0' && ok "(e) baseline criteria used" || bad "(e) criteria not from baseline"
g reset -q --hard HEAD~1

out="$(bash "$PC" u1 "$BASE" --affected src/a.js)"
printf '%s\n' "$out" | grep -qxF 'scope: ok src/a.js listed' && ok "(f) --affected" || bad "(f) --affected"
printf '%s\n' "$out" | grep -qF 'criteria: none' && ok "(f) no contract, no criteria" || bad "(f) criteria line"
out="$(bash "$PC" u1 "$BASE")"
printf '%s\n' "$out" | grep -qxF 'scope: no-affected-list' && first "$out" | grep -q 'result=fail' && ok "(f) no list is a fail" || bad "(f) no list"
mkdir -p "$T/.claude/bookkeeping" && printf 'src/a.js\n' > "$T/.claude/bookkeeping/u1.scope"
bash "$PC" u1 "$BASE" | grep -qxF 'scope: ok src/a.js listed' && ok "(f) lane scope record used" || bad "(f) lane scope record"

printf '{"name":"x"}\n' > package.json && g add -A && g commit -q -m 'u1: pkg'
bash "$PC" u1 "$BASE" --contract "$C" | grep -qxF 'scope: judge package.json version-stamp-name' && ok "(g) version-stamp name left to the reviewer" || bad "(g) judge class"
mkdir -p .claude-plugin && printf '{}\n' > .claude-plugin/plugin.json && git add -A && g commit -q -m plugin-layout && B2="$(git rev-parse HEAD)"
printf '{"name":"y"}\n' > package.json && g commit -qam 'u1: bump'
bash "$PC" u1 "$B2" --contract "$C" | grep -qxF 'scope: ok package.json plugin-version' && ok "(g) plugin layout version file" || bad "(g) plugin-version class"

bash "$PC" '../x' "$BASE" >/dev/null 2>&1; [ "$?" = 2 ] && ok "(h) bad unit id exit 2" || bad "(h) bad unit id"
bash "$PC" u1 not-a-ref >/dev/null 2>&1; [ "$?" = 2 ] && ok "(h) bad baseline exit 2" || bad "(h) bad baseline"
bash "$PC" u1 "$BASE" --criterion 1 >/dev/null 2>&1; [ "$?" = 2 ] && ok "(h) --criterion without a contract exit 2" || bad "(h) --criterion without contract"
bash "$PC" u1 "$BASE" --bogus >/dev/null 2>&1; [ "$?" = 2 ] && ok "(h) unknown option exit 2" || bad "(h) unknown option"
[ "$(cd src && bash "$PC" u1 "$BASE" --contract "$C" | sed -n 2,99p)" = "$(bash "$PC" u1 "$BASE" --contract "$C" | sed -n 2,99p)" ] && ok "(i) same output from a subdirectory" || bad "(i) subdirectory differs"

# (j) prose: the reviewer and the protocol name the pre-review script and its FAIL rule.
flat() { tr -s ' \n' ' ' < "$1"; }
for f in agents/reviewer.md .claude/agents/reviewer.md; do
  for n in 'run `bash .claude/bin/review-precheck.sh <task-id> <baseline> --contract <contract path>` yourself' \
           'is a FAIL ground on its own: return FAIL quoting those lines, without reading the code' \
           'Do not re-run a criterion it reports `pass`; run each `deferred` one yourself with `--criterion <n>`' \
           'Read code only for judgment'; do
    flat "$ROOT/$f" | grep -qF -- "$n" && ok "(j) $f: $n" || bad "(j) $f missing: $n"
  done
done
for f in templates/persona-protocol.md .claude/persona-protocol.md .claude/agents/reviewer.md .claude/agents/orchestrator.md; do
  n='It re-runs the checks with a script too: it runs `.claude/bin/review-precheck.sh` itself, treats each failure line as a FAIL ground, and re-runs by hand only what the script defers or cannot decide.'
  flat "$ROOT/$f" | grep -qF -- "$n" && ok "(j) $f: protocol rule" || bad "(j) $f missing the protocol rule"
done
exit "$fail"
~~~
2. command: `bash tests/review-precheck.test.sh`
   expect: 1
   The red step: the script does not exist and the prose rows (j) fail.
3. file: `bin/review-precheck.sh`
   anchor: new file (mode 755)
   indent: 0
   insert-after:
~~~
#!/usr/bin/env bash
# review-precheck.sh (st-u2): the reviewer's mechanical pre-review of <baseline>..HEAD.
# The reviewer runs it itself; its failure lines are FAIL grounds on their own.
# Writes only .claude/bookkeeping/<unit>.precheck (a copy of stdout).
set -uo pipefail
usage() { echo "usage: review-precheck.sh <unit> <baseline> [--contract <path>] [--fix-contract <path>] [--affected <path>]... [--criterion <n>]" >&2; exit 2; }
[ "$#" -ge 2 ] || usage
unit="$1"; base="$2"; shift 2
[[ "$unit" =~ ^[A-Za-z0-9][A-Za-z0-9._#-]{0,63}$ ]] || { echo "review-precheck: bad unit id: $unit" >&2; exit 2; }
contract=""; fixc=""; only=""; affected=()
while [ "$#" -gt 0 ]; do
  case "$1" in
    --contract) [ "$#" -ge 2 ] || usage; contract="$2"; shift 2 ;;
    --fix-contract) [ "$#" -ge 2 ] || usage; fixc="$2"; shift 2 ;;
    --affected) [ "$#" -ge 2 ] || usage; affected+=("$2"); shift 2 ;;
    --criterion) [ "$#" -ge 2 ] || usage; only="$2"; shift 2 ;;
    *) usage ;;
  esac
done
[ -z "$only" ] || [[ "$only" =~ ^[0-9]+$ ]] || usage
[ -z "$only" ] || [ -n "$contract" ] || usage
dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
lib="$dir/../hooks/scripts/lib"
. "$lib/sensitive-paths.sh" || exit 2
. "$lib/unit-scope.sh" || exit 2
top="$(git rev-parse --show-toplevel 2>/dev/null)" || { echo "review-precheck: not a git repository" >&2; exit 2; }
cd "$top" || exit 2
git rev-parse --verify -q "$base^{commit}" >/dev/null || { echo "review-precheck: baseline does not resolve: $base" >&2; exit 2; }
head="$(git rev-parse HEAD)"
W="$(mktemp -d)"; trap 'rm -rf "$W"' EXIT
out="$W/out"; : > "$out"; fails=0; deferred=0; judge=0
say() { printf '%s\n' "$*" >> "$out"; }
failon() { say "$*"; fails=$((fails + 1)); }

# The contract is read as it was at the baseline, so the unit cannot rewrite its own criteria.
cfile=""
if [ -n "$contract" ]; then
  if git cat-file -e "$base:$contract" 2>/dev/null; then
    git show "$base:$contract" > "$W/contract"; cfile="$W/contract"
    if [ -e "$contract" ] && ! cmp -s "$W/contract" "$contract"; then failon "contract: changed-since-baseline $contract"; fi
  elif [ -f "$contract" ]; then
    cp "$contract" "$W/contract"; cfile="$W/contract"; say "contract: not-at-baseline $contract"
  else
    echo "review-precheck: contract not found: $contract" >&2; exit 2
  fi
fi

# --criterion <n>: run that one criterion only, print its line, write nothing.
crit_items() { # prints "n<TAB>cmd<TAB>exit<TAB>stdout-spec<TAB>long" per criterion
  us_section "$1" "Acceptance criteria" | awk '
    function flush() { if (n != "") printf "%s\t%s\t%s\t%s\t%s\n", n, cmd, ex, so, lg; n=""; cmd=""; ex=""; so=""; lg=0 }
    /^[0-9]+\. run: `/ { flush(); n=$1; sub(/\.$/, "", n); s=$0; sub(/^[0-9]+\. run: `/, "", s)
      lg = (s ~ /\(Bash tool timeout/); i=length(s); while (i > 0 && substr(s, i, 1) != "`") i--; cmd=substr(s, 1, i-1); next }
    /^[[:space:]]+exit: / { ex=$0; sub(/^[[:space:]]+exit: /, "", ex); next }
    /^[[:space:]]+stdout: / { so=$0; sub(/^[[:space:]]+stdout: /, "", so); next }
    END { flush() }'
}
run_one() { # n cmd exit spec -> one criterion line, sets rc 1 on fail, 3 on judge
  local n="$1" cmd="$2" want="$3" spec="$4" got rc
  got="$(cd "$top" && timeout 590 bash -c "$cmd" < /dev/null 2>/dev/null)"; rc=$?
  if [ "$rc" = 124 ]; then echo "criterion $n: fail exit=124 timeout"; return 1; fi
  if ! [[ "$want" =~ ^[0-9]+$ ]] || [ "$rc" != "$want" ]; then echo "criterion $n: fail exit=$rc want=${want:-none}"; return 1; fi
  case "$spec" in
    empty) [ -z "$got" ] && { echo "criterion $n: pass exit=$rc"; return 0; }; echo "criterion $n: fail stdout not empty"; return 1 ;;
    \`*\`) local lit="${spec#\`}"; lit="${lit%\`}"
      [ "$got" = "$lit" ] && { echo "criterion $n: pass exit=$rc"; return 0; }; echo "criterion $n: fail stdout want=$lit got=$(printf '%s' "$got" | head -n1)"; return 1 ;;
    *) echo "criterion $n: judge stdout exit=$rc"; return 3 ;;
  esac
}
if [ -n "$only" ]; then
  [ -n "$cfile" ] || usage
  line="$(crit_items "$cfile" | awk -F'\t' -v n="$only" '$1 == n')"
  [ -n "$line" ] || { echo "review-precheck: no criterion $only" >&2; exit 2; }
  IFS=$'\t' read -r n cmd want spec lg <<< "$line"
  run_one "$n" "$cmd" "$want" "$spec"; exit 0
fi

# Unit scope: the contract's `## Affected files`, plus --affected, else the lane record.
: > "$W/listed"; : > "$W/fix"; : > "$W/crit"; : > "$W/failrec"
[ -z "$cfile" ] || us_entries "$cfile" >> "$W/listed"
for a in "${affected[@]+"${affected[@]}"}"; do printf '%s\n' "$a" >> "$W/listed"; done
dot="${CLAUDE_PROJECT_DIR:-$top}/.claude"
if [ ! -s "$W/listed" ] && [ -f "$dot/bookkeeping/$unit.scope" ]; then cp "$dot/bookkeeping/$unit.scope" "$W/listed"; fi
[ -z "$fixc" ] || { [ -f "$fixc" ] && us_entries "$fixc" > "$W/fix"; }
[ -z "$cfile" ] || us_section "$cfile" "Acceptance criteria" | grep -E '^[0-9]+\. run: ' > "$W/crit" || true
[ ! -f "$dot/reviewed/$unit.fail" ] || cp "$dot/reviewed/$unit.fail" "$W/failrec"

G=(git -c core.quotepath=false -c diff.relative=false)
PS=(-- . ':(exclude).claude' ':(exclude)docs/plans')
"${G[@]}" diff --no-renames --name-only "$base..HEAD" "${PS[@]}" > "$W/changed"
[ -s "$W/listed" ] || failon "scope: no-affected-list"
while IFS= read -r p; do
  [ -n "$p" ] || continue
  say "changed: $p"
  case "$p" in '"'*) failon "scope: out $p unquotable"; continue ;; esac
  [ -s "$W/listed" ] || continue
  c="$(us_classify "$p" "$base" "$W/listed" "$W/fix" "$W/crit" "$W/failrec")"
  case "$c" in
    out) failon "scope: out $p" ;;
    judge) say "scope: judge $p version-stamp-name"; judge=$((judge + 1)) ;;
    *) say "scope: ok $p $c" ;;
  esac
done < "$W/changed"
files=0; lines=0; binary=0
while IFS=$'\t' read -r a d p; do
  [ -n "$p" ] || continue; files=$((files + 1))
  case "$a$d" in *[!0-9]*) binary=$((binary + 1)) ;; *) lines=$((lines + a + d)) ;; esac
done < <("${G[@]}" diff --no-renames --numstat "$base..HEAD" "${PS[@]}")
say "size: files=$files lines=$lines binary=$binary"
while IFS= read -r p; do
  [ -n "$p" ] && touches_sensitive_path "$p" && say "sensitive: $p"
done < <("${G[@]}" diff --no-renames --name-only "$base..HEAD" --)
vs="$dir/../hooks/scripts/version-stamp-check.sh"
if [ -f "$vs" ]; then
  v="$(bash "$vs" "$base..HEAD" 2>/dev/null | head -n1)"
  case "$v" in "version-stamp-check: violation"*) failon "version-stamp: $v" ;; *) say "version-stamp: $v" ;; esac
fi
if [ -n "$cfile" ]; then
  while IFS=$'\t' read -r n cmd want spec lg; do
    [ -n "$n" ] || continue
    if [ "$lg" = 1 ]; then say "criterion $n: deferred long"; deferred=$((deferred + 1)); continue; fi
    l="$(run_one "$n" "$cmd" "$want" "$spec")"; rc=$?
    say "$l"
    [ "$rc" = 1 ] && fails=$((fails + 1))
    [ "$rc" = 3 ] && judge=$((judge + 1))
  done < <(crit_items "$cfile")
else
  say "criteria: none (no contract; run the project's test and lint command yourself)"
fi
result=pass; [ "$fails" -gt 0 ] && result=fail
{ echo "precheck: result=$result unit=$unit range=$base..$head fails=$fails deferred=$deferred judge=$judge"; cat "$out"; } > "$W/packet"
mkdir -p "$dot/bookkeeping" && cp "$W/packet" "$dot/bookkeeping/$unit.precheck"
cat "$W/packet"
exit 0
~~~
4. file: `bin/cli.js`
   anchor: line matching `const BIN_HELPER_FILES = [`
   indent: 0
   before: `const BIN_HELPER_FILES = ['ladder-tier.sh', 'contract-guard.js', 'contract-score.js', 'fail-count.sh', 'escalation-card.sh', 'unit-bookkeeping.sh', 'blast-radius.sh'];`
   after: `const BIN_HELPER_FILES = ['ladder-tier.sh', 'contract-guard.js', 'contract-score.js', 'fail-count.sh', 'escalation-card.sh', 'unit-bookkeeping.sh', 'blast-radius.sh', 'review-precheck.sh'];`
5. file: `tests/bin-helpers-scaffold.test.sh`
   anchor: line matching `FILES="ladder-tier.sh`
   indent: 0
   before: `FILES="ladder-tier.sh contract-guard.js contract-score.js fail-count.sh escalation-card.sh unit-bookkeeping.sh blast-radius.sh"`
   after: `FILES="ladder-tier.sh contract-guard.js contract-score.js fail-count.sh escalation-card.sh unit-bookkeeping.sh blast-radius.sh review-precheck.sh"`
   In the same file, change both occurrences of `(a) seven helpers present` to `(a) eight helpers present`.
6. file: `agents/reviewer.md`
   anchor: line matching `- **Scope the review with the blast-radius script**: run` (qw-u5's bullet; the only such line)
   indent: 0
   before: `- **Scope the review with the blast-radius script**: run`
   after:
~~~
- **Run the mechanical pre-review first**: run
  `bash .claude/bin/review-precheck.sh <task-id> <baseline> --contract <contract path>`
  yourself, from the repo root, with a Bash timeout of 600000 ms (with no
  contract, pass each `## Affected files` path of the dispatch as
  `--affected <path>`; in a fix round add `--fix-contract <path>`). Line 1 reads
  `precheck: result=<pass|fail> ... fails=<n> deferred=<n> judge=<n>`. Each
  `scope: out`, `scope: no-affected-list`, `criterion <n>: fail`,
  `version-stamp: ... violation` or `contract: changed-since-baseline` line
  is a FAIL ground on its own: return FAIL quoting those lines, without reading
  the code. Do not re-run a criterion it reports `pass`; run each `deferred`
  one yourself with `--criterion <n>`, and decide each `judge` line yourself.
  Read code only for judgment: the changed files, the callers and tests the
  blast-radius script lists, and every `sensitive:` path in full. If the
  script is missing or exits non-zero, run the checks yourself as before.
- **Scope the review with the blast-radius script**: run
~~~
7. file: `templates/persona-protocol.md`
   anchor: line matching `stays open; it never takes a blast radius from the dispatch, the orchestrator` (qw-u5's sentence in "Reuse over re-derivation"; the only such line)
   indent: 0
   before:
~~~
stays open; it never takes a blast radius from the dispatch, the orchestrator
or the writer.
~~~
   after:
~~~
stays open; it never takes a blast radius from the dispatch, the orchestrator
or the writer. It re-runs the checks with a script too: it runs
`.claude/bin/review-precheck.sh` itself, treats each failure line as a FAIL
ground, and re-runs by hand only what the script defers or cannot decide.
~~~
8. file: `tests/validate.sh`
   anchor: line matching `echo "== scope-libs: sensitive-path class and unit-scope classes shared by precheck and scope gate (Bash, st-u1) =="`
   indent: 0
   before:
~~~
echo "== scope-libs: sensitive-path class and unit-scope classes shared by precheck and scope gate (Bash, st-u1) =="
if bash tests/scope-libs.test.sh > /dev/null; then
  echo "OK   tests/scope-libs.test.sh"
else
  echo "FAIL tests/scope-libs.test.sh"
  fail=1
fi
~~~
   after:
~~~
echo "== scope-libs: sensitive-path class and unit-scope classes shared by precheck and scope gate (Bash, st-u1) =="
if bash tests/scope-libs.test.sh > /dev/null; then
  echo "OK   tests/scope-libs.test.sh"
else
  echo "FAIL tests/scope-libs.test.sh"
  fail=1
fi

echo
echo "== review-precheck: the reviewer's mechanical pre-review, failure lines are FAIL grounds (Bash, st-u2) =="
if bash tests/review-precheck.test.sh > /dev/null; then
  echo "OK   tests/review-precheck.test.sh"
else
  echo "FAIL tests/review-precheck.test.sh"
  fail=1
fi
~~~
9. command: `perl -0pi -e 's/("version": "\d+\.\d+\.)(\d+)"/$1.($2+1)."\""/e' .claude-plugin/plugin.json package.json`
   expect: 0
   This adds one to the patch version in both files (expected 0.31.195 to 0.31.196).
10. file: `CHANGELOG.md`
   anchor: line matching `## [Unreleased]`
   indent: 0
   insert-after:
~~~

**Reviewer mechanical pre-review (st-u2, VERSION).** New `bin/review-precheck.sh`, installed to `.claude/bin/`: the reviewer runs it itself and gets the precheck packet (unit scope with the standing exceptions, diff size, sensitive paths, version stamp, and the contract's criteria read from the baseline commit; long criteria deferred to `--criterion <n>`), copied to `.claude/bookkeeping/<unit>.precheck`. agents/reviewer.md: each failure line is a FAIL ground on its own, criteria the script passed are not re-run, code is read only for judgment. The protocol's reuse rule says the same. Codex and cursor reviewers unchanged. New test tests/review-precheck.test.sh.
~~~
   Replace `VERSION` with the version that edit 9 wrote.
11. command: `node bin/cli.js --update`
   expect: 0
12. command: `bash tests/review-precheck.test.sh`
   expect: 0
13. command: `git add tests/review-precheck.test.sh bin/review-precheck.sh .claude/bin/review-precheck.sh && git add -u && git commit -m "feat(st-u2): the reviewer runs a mechanical pre-review script itself; its failure lines are FAIL grounds"`
   expect: 0
   Run `git status --short` first: if a tracked file outside "Affected files" is modified, stop and report it.

## Do NOT touch
- `adapters/codex/agents/reviewer.toml`, `adapters/cursor/agents/reviewer.md` and the adapter protocol ports (no `.claude/bin/` there; criterion 5)
- `hooks/` and `.claude/hooks/` (the script is the reviewer's own tool, not a gate; criterion 5)
- `agents/orchestrator.md` (the orchestrator neither runs nor forwards the packet; criterion 5)
- `hooks/scripts/lib/unit-scope.sh` and `hooks/scripts/lib/sensitive-paths.sh` (st-u1's; this unit only sources them)
- `.claude/agents/` and `.claude/bin/` by hand (only `node bin/cli.js --update` writes them)

## Acceptance criteria
1. run: `bash -c 'bash tests/review-precheck.test.sh >/dev/null; echo $?'`
   exit: 0
   stdout: `0`
   mutation: in the script, read the contract from the working tree instead of `git show "$base:$contract"`; case (e) prints `FAIL (e) criteria not from baseline` and stdout is `1`.
2. run: `cmp bin/review-precheck.sh .claude/bin/review-precheck.sh`
   exit: 0
   stdout: empty
   mutation: revert edit 4; `--update` installs nothing, cmp reports the missing file and exits 2.
3. run: `bash -c 'bash tests/bin-helpers-scaffold.test.sh >/dev/null; echo $?'`
   exit: 0
   stdout: `0`
   mutation: revert edit 4; the scaffold has no `.claude/bin/review-precheck.sh`, case (a) fails and stdout is `1`.
4. run: `bash -c 'bash .claude/bin/review-precheck.sh st-u2 HEAD~1 --affected bin/review-precheck.sh | head -n1 | grep -cE "^precheck: result=(pass|fail) unit=st-u2 range=HEAD~1\.\.[0-9a-f]{40} fails=[0-9]+ deferred=0 judge=[0-9]+$"'`
   exit: 0
   stdout: `1`
   mutation: change the library path in the script to `$dir/../hooks/lib`; the installed copy exits 2 before line 1, stdout is `0` and the exit is 1.
5. run: `bash -c 'b=$(git log --format=%H --grep="(st-u2)" | tail -1); git diff --name-only "$b^..HEAD" -- adapters hooks .claude/hooks agents/orchestrator.md | wc -l'`
   exit: 0
   stdout: `0`
   mutation: edit `adapters/cursor/agents/reviewer.md` in an st-u2 commit; stdout is at least `1`.
6. run: `bash -c 'node tests/adapter-protocol-parity.test.js >/dev/null && node tests/protocol-doc-drift.test.js >/dev/null && node tests/protocol-cross-references.test.js >/dev/null && bash tests/persona-prose-pins.test.sh >/dev/null && node tests/cli-backfill.test.js >/dev/null; echo $?'`
   exit: 0
   stdout: `0`
   mutation: add a line starting `## ` inside edit 7's payload; protocol-doc-drift's section count no longer matches and stdout is `1`.
7. run: `bash -c 'b=$(git log --format=%H --grep="(st-u2)" | tail -1); bash hooks/scripts/version-stamp-check.sh "$b^..HEAD" | cut -d" " -f1-4'`
   exit: 0
   stdout: `version-stamp-check: ok touched: yes`
   mutation: skip edit 9; stdout reads `version-stamp-check: violation touched: yes`.
8. run: `bash -c 'bash tests/validate.sh >/dev/null 2>&1; echo $?'` (Bash tool timeout 600000 ms)
   exit: 0
   stdout: `0`
   mutation: put `exit 1` as line 2 of tests/review-precheck.test.sh; validate.sh exits 1 and stdout is `1`.

## Pre-resolved context
tdd: yes the test (edit 1) fails first (edit 2). spec-master ran it on a clone at eb59e217 with st-u1 applied, plus qw-u5's script and its prose edits 6 to 9 (the anchors this unit needs): 30 script checks pass, the (j) prose rows fail before edits 6 and 7 and pass after `--update`; `cmp` is clean; parity, doc-drift, cross-reference, prose-pin and cli-backfill suites stay green; the installed script ran on this repo's HEAD~1 in under 2 s. validate.sh was not run by spec-master.
blast-radius: agents/reviewer.md:18 (the scope bullet qw-u5 rewrites; this bullet goes directly above it), templates/persona-protocol.md:38 (Reuse over re-derivation, the sentence qw-u5 extends; the section is in UNIVERSAL_PROTOCOL_CORE, so every full-tier mirror re-renders), bin/cli.js:656 (BIN_HELPER_FILES), tests/bin-helpers-scaffold.test.sh:15 and :22. Line numbers are at eb59e217, before qw-u5; work from the anchors.
fail-rule: the FAIL-without-reading lines are exactly `scope: out`, `scope: no-affected-list`, `criterion <n>: fail`, `version-stamp: ... violation` and `contract: changed-since-baseline`. `scope: judge` (a version-file name outside this plugin's layout) and `criterion <n>: judge` (a prose `stdout:`) are the reviewer's own decision. `sensitive:` lines are not failures; they name files the reviewer reads in full.
independence: the reviewer runs the script itself (the operator's c1 ruling pattern for blast-radius.sh). The orchestrator does not run it and the writer's advisory packet does not replace it.
baseline-contract: criteria come from `git show <baseline>:<contract>` when the contract is tracked at the baseline (contracts are committed before dispatch); a contract that differs at HEAD is a failure line, so a unit cannot weaken its own criteria inside `docs/plans/` (which unit scope exempts).
long-criteria: a `run:` line carrying `(Bash tool timeout` is deferred, so one precheck call stays under the 600 s Bash ceiling; the reviewer runs each with `--criterion <n>` (one line, nothing written). Each criterion runs under `timeout 590`.
no-test-lint: the precheck does not run `testAndLintCommand`; stop-gate.sh already runs it at the gated SubagentStop. With no contract it prints `criteria: none (...)`, and the reviewer runs the test command itself.
version: .claude-plugin/plugin.json and package.json read 0.31.195 after st-u1 if no fix round bumped; edit 9 adds one (expected 0.31.196).
mirrors: `.claude/` copies change only through `node bin/cli.js --update` (constitution P2).
terminology: the output is the **precheck packet**; never call it the review packet (docs/harness-glossary.md uses **review-packet** for the contract key and **advisory review packet** for lead-programmer's report).
commit-message: feat(st-u2): the reviewer runs a mechanical pre-review script itself; its failure lines are FAIL grounds
diagnosis: none
review-packet:
~~~
unit: st-u2
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
If a `before:` payload is not found verbatim (edits 4 to 7 depend on qw-u5's text and edit 8 on st-u1's block), stop
and report the current text. If `node bin/cli.js --update` refuses (for example the cross-reference assertion), quote
its message and stop. If a gate blocks a command, report it and wait. Anything outside "Affected files" goes to your
report as a proposal.
