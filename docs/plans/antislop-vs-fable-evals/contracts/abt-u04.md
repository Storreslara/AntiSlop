Unit: abt-u04

## Objective
eval/abtest/checks/lib.sh and scope.sh define how a fixture's check.sh runs and reports (throwaway copy, package.json restored from the baseline, JSON checks array, out-of-scope lines excluding .claude/ and docs/plans/); eval/abtest/fixtures/lib.sh makes a baseline commit deterministic; eval/abtest/verify-checks.sh proves each fixture non-vacuous (two builds agree, baseline has a required FAIL, baseline plus reference.patch all PASS, no check names a fixture path); tests/abtest-checks.test.sh passes over three synthetic fixtures. One commit.

## Retrieval
GitHub issues: `gh issue view 572 --repo Storreslara/AntiSlop`. Siblings: `gh issue list --repo Storreslara/AntiSlop --label plan/antislop-vs-fable-evals`. Spec: `docs/plans/antislop-vs-fable-evals.md`; operator overrides (win on conflict): `docs/plans/antislop-vs-fable-evals/operator-decisions.md`.

## Affected files
- `eval/abtest/fixtures/lib.sh` (anchor: new file)
- `eval/abtest/checks/lib.sh` (anchor: new file)
- `eval/abtest/checks/scope.sh` (anchor: new file)
- `eval/abtest/verify-checks.sh` (anchor: new file)
- `tests/abtest-checks.test.sh` (anchor: new file)
- `tests/fixtures/abtest/verify/checks/syn-badref/check.sh` (anchor: new file)
- `tests/fixtures/abtest/verify/checks/syn-ok/check.sh` (anchor: new file)
- `tests/fixtures/abtest/verify/checks/syn-vacuous/check.sh` (anchor: new file)
- `tests/fixtures/abtest/verify/fixtures/syn-badref/allowed-paths.txt` (anchor: new file)
- `tests/fixtures/abtest/verify/fixtures/syn-badref/build.sh` (anchor: new file)
- `tests/fixtures/abtest/verify/fixtures/syn-badref/reference.patch` (anchor: new file)
- `tests/fixtures/abtest/verify/fixtures/syn-ok/allowed-paths.txt` (anchor: new file)
- `tests/fixtures/abtest/verify/fixtures/syn-ok/build.sh` (anchor: new file)
- `tests/fixtures/abtest/verify/fixtures/syn-ok/reference.patch` (anchor: new file)
- `tests/fixtures/abtest/verify/fixtures/syn-vacuous/allowed-paths.txt` (anchor: new file)
- `tests/fixtures/abtest/verify/fixtures/syn-vacuous/build.sh` (anchor: new file)
- `tests/fixtures/abtest/verify/fixtures/syn-vacuous/reference.patch` (anchor: new file)

## Ordered edits
1. command: `test ! -e eval/abtest/checks && test ! -e eval/abtest/fixtures && test ! -e eval/abtest/verify-checks.sh && test ! -e tests/abtest-checks.test.sh && test ! -e tests/fixtures/abtest/verify && test -z "$(git status --porcelain --untracked-files=no -- . ':!.claude/agent-memory')"`
   expect: 0
2. file: `eval/abtest/fixtures/lib.sh`
   anchor: new file
   indent: 0
   insert-after:
~~~~
#!/usr/bin/env bash
# Sourced by eval/abtest/fixtures/<eval-id>/build.sh. Makes a fixture build
# deterministic: fixed identity and dates, so two builds of one fixture
# commit the same baseline sha.

abt_fixture_env() {
  export GIT_AUTHOR_NAME=abtest GIT_AUTHOR_EMAIL=abtest@example.invalid
  export GIT_COMMITTER_NAME=abtest GIT_COMMITTER_EMAIL=abtest@example.invalid
  export GIT_AUTHOR_DATE=2026-01-01T00:00:00Z GIT_COMMITTER_DATE=2026-01-01T00:00:00Z
}

# abt_fixture_baseline DEST: turn DEST into a git repo with one commit named
# baseline and print the commit sha (the last stdout line of build.sh).
abt_fixture_baseline() {
  abt_fixture_env
  ( cd "$1" && git init -q -b main && git add -A && git commit -q -m baseline && git rev-parse HEAD )
}
~~~~
3. file: `eval/abtest/checks/lib.sh`
   anchor: new file
   indent: 0
   insert-after:
~~~~
#!/usr/bin/env bash
# Sourced by eval/abtest/checks/<eval-id>/check.sh. Conventions:
#   check.sh WORKTREE BASE_SHA START_SHA ALLOWED_PATHS_FILE
#   . "${ABT_CHECKS_LIB:-$(dirname "$0")/../lib.sh}"
#   abt_init "$1" "$2" "$3" "$4"
#   abt_check ID KIND REQUIRED 'COMMAND' [PATH_TO_RESTORE_FROM_BASE ...]
#   abt_check_scope ID REQUIRED
#   abt_emit            # prints the checks array as one JSON line
# KIND is defect|scope|security|docs|process|premise; REQUIRED is true|false.
# Every COMMAND runs in a throwaway copy of the final tree, with package.json
# (and any listed path) restored from BASE_SHA, so a check cannot change the
# agent's tree and an agent cannot pass by editing the test runner. The
# command sees ABT_WT (the copy), ABT_BASE, ABT_START and ABT_CHECKS_DIR (the
# directory holding the holdout files). Exit 0 means the check passed.

abt_init() {
  ABT_WT="$(cd "$1" && pwd)"
  ABT_BASE="$2"
  ABT_START="$3"
  ABT_ALLOWED="${4:-}"
  ABT_CHECKS_DIR="$(cd "$(dirname "${BASH_SOURCE[1]}")" && pwd)"
  ABT_LIB_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
  ABT_OUT="$(mktemp)"
  export ABT_WT ABT_BASE ABT_START ABT_CHECKS_DIR
}

abt_record() {
  python3 -I - "$ABT_OUT" "$1" "$2" "$3" "$4" "$5" "${6:-}" <<'PYEOF'
import json, sys

out, cid, kind, req, cmd, rc, value = sys.argv[1:8]
rec = {"id": cid, "kind": kind, "required": req == "true", "cmd": cmd,
       "exit": int(rc), "pass": int(rc) == 0}
if value != "":
    rec["value"] = int(value)
with open(out, "a") as f:
    f.write(json.dumps(rec) + "\n")
PYEOF
}

abt_validate() {
  case "$1" in
    defect | scope | security | docs | process | premise) ;;
    *) echo "abt_check: bad kind $1" >&2; exit 2 ;;
  esac
  case "$2" in
    true | false) ;;
    *) echo "abt_check: required must be true or false" >&2; exit 2 ;;
  esac
}

abt_check() {
  local id="$1" kind="$2" req="$3" cmd="$4"
  shift 4
  abt_validate "$kind" "$req"
  local copy rc=0 p
  copy="$(mktemp -d)"
  cp -a "$ABT_WT/." "$copy/"
  for p in package.json "$@"; do
    git -C "$copy" checkout -q "$ABT_BASE" -- "$p" 2>/dev/null || true
  done
  ( cd "$copy" && ABT_WT="$copy" bash -c "$cmd" ) > /dev/null 2>&1 || rc=$?
  rm -rf "$copy"
  abt_record "$id" "$kind" "$req" "$cmd" "$rc"
}

abt_check_scope() {
  local id="$1" req="$2" v rc=0
  abt_validate scope "$req"
  v="$(bash "$ABT_LIB_DIR/scope.sh" "$ABT_WT" "$ABT_START" "$ABT_ALLOWED" lines)"
  [ "$v" = 0 ] || rc=1
  abt_record "$id" scope "$req" "scope.sh lines outside the allowed paths" "$rc" "$v"
}

abt_emit() {
  python3 -I - "$ABT_OUT" <<'PYEOF'
~~~~
4. file: `eval/abtest/checks/lib.sh`
   anchor: line matching `  python3 -I - "$ABT_OUT" <<'PYEOF'`
   indent: 0
   insert-after:
~~~~
import json, sys

with open(sys.argv[1]) as f:
    recs = [json.loads(l) for l in f if l.strip()]
print(json.dumps(recs))
PYEOF
  rm -f "$ABT_OUT"
}
~~~~
5. file: `eval/abtest/checks/scope.sh`
   anchor: new file
   indent: 0
   insert-after:
~~~~
#!/usr/bin/env bash
# Out-of-scope measure for one run.
# Usage: scope.sh WORKTREE START_SHA ALLOWED_PATHS_FILE lines|files
# Counts added plus deleted lines (lines) or changed files (files) between
# START_SHA and HEAD outside the allowed paths. The persona scaffold (.claude/)
# and the pipeline's own plans (docs/plans/) never count, for either arm.
set -euo pipefail
wt="${1:?usage: scope.sh WORKTREE START_SHA ALLOWED_PATHS_FILE lines|files}"
start="${2:?missing START_SHA}"
allowed="${3:?missing ALLOWED_PATHS_FILE}"
mode="${4:?missing mode}"
specs=('.' ':(exclude).claude' ':(exclude)docs/plans')
while IFS= read -r p; do
  [ -n "$p" ] && specs+=(":(exclude)$p")
done < "$allowed"
case "$mode" in
  lines) git -C "$wt" diff --numstat "$start..HEAD" -- "${specs[@]}" | awk '{s+=$1+$2} END{print s+0}' ;;
  files) git -C "$wt" diff --name-only "$start..HEAD" -- "${specs[@]}" | grep -c . || true ;;
  *) echo "scope.sh: mode must be lines or files" >&2; exit 2 ;;
esac
~~~~
6. file: `eval/abtest/verify-checks.sh`
   anchor: new file
   indent: 0
   insert-after:
~~~~
#!/usr/bin/env bash
# Non-vacuity proof for the holdout checks (spec C2.1, C2.2).
# Usage: verify-checks.sh --all | EVAL_ID
# For each fixture: two builds agree on the baseline sha; on the baseline at
# least one required check fails; after applying reference.patch every
# required check passes; no check.sh names a fixture or run path. The patch is
# applied with --recount because a contract payload turns a context line that
# holds one space into an empty line.
# Env: ABT_FIXTURES_DIR, ABT_CHECKS_ROOT override the default directories.
set -uo pipefail
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
export ABT_REPO_ROOT="$(cd "$HERE/../.." && pwd)"
FIX="${ABT_FIXTURES_DIR:-$HERE/fixtures}"
CHK="${ABT_CHECKS_ROOT:-$HERE/checks}"
FIX="$(cd "$FIX" 2>/dev/null && pwd || echo "$FIX")"
CHK="$(cd "$CHK" 2>/dev/null && pwd || echo "$CHK")"
export ABT_CHECKS_LIB="$HERE/checks/lib.sh"
arg="${1:?usage: verify-checks.sh --all | EVAL_ID}"
if [ "$arg" = "--all" ]; then
  ids=()
  for d in "$FIX"/*/; do ids+=("$(basename "$d")"); done
else
  ids=("$arg")
fi
[ "${#ids[@]}" -gt 0 ] || { echo "verify-checks: no fixtures found" >&2; exit 2; }

T="$(mktemp -d)"
trap 'rm -rf "$T"' EXIT
bad=0

# rows CHECKS_JSON: print "<required failed> <required total>".
rows() {
  python3 -I -c 'import json,sys;c=[x for x in json.loads(sys.argv[1]) if x["required"]];print(sum(1 for x in c if not x["pass"]),len(c))' "$1"
}

for id in "${ids[@]}"; do
  fx="$FIX/$id"
  ck="$CHK/$id"
  if [ ! -f "$fx/build.sh" ] || [ ! -f "$ck/check.sh" ] || [ ! -f "$fx/reference.patch" ] || [ ! -f "$fx/allowed-paths.txt" ]; then
    echo "verify: $id missing build.sh, check.sh, reference.patch or allowed-paths.txt"; bad=1; continue
  fi
  if grep -qE 'fixtures/|\.runs/' "$ck/check.sh"; then
    echo "verify: $id check.sh names a fixture or run path"; bad=1; continue
  fi
  a="$(bash "$fx/build.sh" "$T/$id-a" | tail -n1)"
  b="$(bash "$fx/build.sh" "$T/$id-b" | tail -n1)"
  if [ -z "$a" ] || [ "$a" != "$b" ]; then
    echo "verify: $id nondeterministic build ($a vs $b)"; bad=1; continue
  fi
  base_json="$(bash "$ck/check.sh" "$T/$id-a" "$a" "$a" "$fx/allowed-paths.txt")"
  read -r base_fail base_total < <(rows "$base_json")
  git -C "$T/$id-b" apply --recount "$fx/reference.patch" && git -C "$T/$id-b" add -A \
    && git -C "$T/$id-b" -c user.name=abtest -c user.email=abtest@example.invalid commit -q -m reference
  ref_json="$(bash "$ck/check.sh" "$T/$id-b" "$a" "$a" "$fx/allowed-paths.txt")"
  read -r ref_fail ref_total < <(rows "$ref_json")
  echo "verify: $id baseline-required-failures=$base_fail/$base_total reference-required-failures=$ref_fail/$ref_total"
  if [ "$base_total" -eq 0 ] || [ "$base_fail" -lt 1 ] || [ "$ref_fail" -ne 0 ]; then
    bad=1
  fi
done

if [ "$bad" -eq 0 ]; then echo "verify-checks: ok"; else echo "verify-checks: FAILED"; fi
exit "$bad"
~~~~
7. file: `tests/abtest-checks.test.sh`
   anchor: new file
   indent: 0
   insert-after:
~~~~
#!/usr/bin/env bash
# Tests the check conventions (checks/lib.sh, checks/scope.sh) and the
# non-vacuity verifier (verify-checks.sh) over synthetic fixtures.
set -u
REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
VERIFY="$REPO_ROOT/eval/abtest/verify-checks.sh"
SCOPE="$REPO_ROOT/eval/abtest/checks/scope.sh"
SYN="$REPO_ROOT/tests/fixtures/abtest/verify"
T="$(mktemp -d)"
trap 'rm -rf "$T"' EXIT
pass=0
fail=0
ok() { pass=$((pass + 1)); echo "ok   $1"; }
bad() { fail=$((fail + 1)); echo "FAIL $1"; }
check() { if [ "$2" = "$3" ]; then ok "$1"; else bad "$1 (want '$3', got '$2')"; fi; }
has() { case "$2" in *"$3"*) ok "$1" ;; *) bad "$1 (missing '$3' in '$2')" ;; esac; }

export ABT_FIXTURES_DIR="$SYN/fixtures" ABT_CHECKS_ROOT="$SYN/checks"

out="$(bash "$VERIFY" syn-ok)"; rc=$?
check "a non-vacuous fixture verifies" "$rc" "0"
has "verify reports the baseline failure and a clean reference" "$out" "verify: syn-ok baseline-required-failures=1/2 reference-required-failures=0/2"
has "verify ends ok" "$out" "verify-checks: ok"
out="$(bash "$VERIFY" syn-vacuous)"; rc=$?
check "a check that passes on the baseline is rejected" "$rc" "1"
has "the vacuous fixture reports no baseline failure" "$out" "baseline-required-failures=0/2"
out="$(bash "$VERIFY" syn-badref)"; rc=$?
check "a reference that does not satisfy a check is rejected" "$rc" "1"
has "the bad reference reports a reference failure" "$out" "reference-required-failures=1/2"
out="$(bash "$VERIFY" --all)"; rc=$?
check "--all fails when any fixture fails" "$rc" "1"

mkdir -p "$T/fx" "$T/ck"
cp -r "$SYN/fixtures/syn-ok" "$T/fx/syn-path"
cp -r "$SYN/checks/syn-ok" "$T/ck/syn-path"
printf '# see fixtures/x\n' >> "$T/ck/syn-path/check.sh"
out="$(ABT_FIXTURES_DIR="$T/fx" ABT_CHECKS_ROOT="$T/ck" bash "$VERIFY" syn-path)"; rc=$?
check "a check naming a fixture path is rejected" "$rc" "1"
has "the path rule is named" "$out" "names a fixture or run path"

cp -r "$SYN/fixtures/syn-ok" "$T/fx/syn-nondet"
cp -r "$SYN/checks/syn-ok" "$T/ck/syn-nondet"
printf 'date +%%s%%N > "$1/stamp.txt"\ncd "$1" && git add -A && git commit -q --amend -m baseline\ngit rev-parse HEAD\n' >> "$T/fx/syn-nondet/build.sh"
sed -i 's/^abt_fixture_baseline "\$1"$/abt_fixture_baseline "$1" >\/dev\/null/' "$T/fx/syn-nondet/build.sh"
out="$(ABT_FIXTURES_DIR="$T/fx" ABT_CHECKS_ROOT="$T/ck" bash "$VERIFY" syn-nondet)"; rc=$?
check "a nondeterministic build is rejected" "$rc" "1"
has "the build rule is named" "$out" "nondeterministic build"

out="$(ABT_FIXTURES_DIR="$T/none" ABT_CHECKS_ROOT="$T/none" bash "$VERIFY" absent)"; rc=$?
check "a missing fixture is rejected" "$rc" "1"

# lib.sh: run checks against a hand-built tree.
R="$T/repo"
ABT_REPO_ROOT="$REPO_ROOT" bash "$SYN/fixtures/syn-ok/build.sh" "$R" > "$T/sha"
BASE="$(tail -n1 "$T/sha")"
printf 'answer.txt\n' > "$T/allowed"
printf 'x' > "$R/package.json"
cat > "$T/lib-check.sh" << 'EOS'
. "$ABT_CHECKS_LIB"
abt_init "$1" "$2" "$3" "$4"
abt_check restored-runner defect true 'grep -q syn package.json'
abt_check cannot-touch-tree defect false 'rm -f answer.txt'
abt_check sees-env process false 'test -n "$ABT_BASE" && test -d "$ABT_CHECKS_DIR"'
abt_emit
EOS
json="$(ABT_CHECKS_LIB="$REPO_ROOT/eval/abtest/checks/lib.sh" bash "$T/lib-check.sh" "$R" "$BASE" "$BASE" "$T/allowed")"
check "package.json is restored from the baseline inside the check" "$(printf '%s' "$json" | python3 -I -c 'import json,sys;print(json.load(sys.stdin)[0]["pass"])')" "True"
check "the agent tree survives a destructive check" "$(test -f "$R/answer.txt" && cat "$R/package.json")" "x"
check "the check environment is exported" "$(printf '%s' "$json" | python3 -I -c 'import json,sys;print(json.load(sys.stdin)[2]["pass"])')" "True"
cat > "$T/bad-kind.sh" << 'EOS'
. "$ABT_CHECKS_LIB"
abt_init "$1" "$2" "$3" "$4"
abt_check x bogus true true
EOS
ABT_CHECKS_LIB="$REPO_ROOT/eval/abtest/checks/lib.sh" bash "$T/bad-kind.sh" "$R" "$BASE" "$BASE" "$T/allowed" > /dev/null 2>&1
check "an unknown kind exits 2" "$?" "2"

# scope.sh: only edits outside the allowed paths count; .claude and docs/plans never do.
~~~~
8. file: `tests/abtest-checks.test.sh`
   anchor: line matching `# scope.sh: only edits outside the allowed paths count; .claude and docs/plans never do.`
   indent: 0
   insert-after:
~~~~
S="$T/scope"
mkdir -p "$S" && git -C "$S" init -q -b main
printf 'a\n' > "$S/answer.txt"
git -C "$S" add -A && git -C "$S" -c user.name=t -c user.email=t@t.invalid commit -q -m start
START="$(git -C "$S" rev-parse HEAD)"
printf 'b\nc\n' >> "$S/answer.txt"
printf '1\n2\n3\n' > "$S/other.js"
mkdir -p "$S/.claude" "$S/docs/plans"
printf 'z\n' > "$S/.claude/x"
printf 'z\n' > "$S/docs/plans/p.md"
git -C "$S" add -A && git -C "$S" -c user.name=t -c user.email=t@t.invalid commit -q -m work
check "scope lines count only the outside edit" "$(bash "$SCOPE" "$S" "$START" "$T/allowed" lines)" "3"
check "scope files count only the outside file" "$(bash "$SCOPE" "$S" "$START" "$T/allowed" files)" "1"
check "scope.sh rejects an unknown mode" "$(bash "$SCOPE" "$S" "$START" "$T/allowed" bogus >/dev/null 2>&1; echo $?)" "2"

echo "abtest-checks: $pass passed, $fail failed"
[ "$fail" -eq 0 ] && echo "All abtest-checks checks passed."
exit "$fail"
~~~~
9. file: `tests/fixtures/abtest/verify/checks/syn-badref/check.sh`
   anchor: new file
   indent: 0
   insert-after:
~~~~
#!/usr/bin/env bash
. "${ABT_CHECKS_LIB:-$(dirname "$0")/../lib.sh}"
abt_init "$1" "$2" "$3" "$4"
abt_check answer-is-three defect true 'grep -qx 3 answer.txt'
abt_check_scope scope-outside-allowed true
abt_emit
~~~~
10. file: `tests/fixtures/abtest/verify/checks/syn-ok/check.sh`
   anchor: new file
   indent: 0
   insert-after:
~~~~
#!/usr/bin/env bash
. "${ABT_CHECKS_LIB:-$(dirname "$0")/../lib.sh}"
abt_init "$1" "$2" "$3" "$4"
abt_check answer-is-two defect true 'grep -qx 2 answer.txt'
abt_check_scope scope-outside-allowed true
abt_emit
~~~~
11. file: `tests/fixtures/abtest/verify/checks/syn-vacuous/check.sh`
   anchor: new file
   indent: 0
   insert-after:
~~~~
#!/usr/bin/env bash
. "${ABT_CHECKS_LIB:-$(dirname "$0")/../lib.sh}"
abt_init "$1" "$2" "$3" "$4"
abt_check always-true defect true 'true'
abt_check_scope scope-outside-allowed true
abt_emit
~~~~
12. file: `tests/fixtures/abtest/verify/fixtures/syn-badref/allowed-paths.txt`
   anchor: new file
   indent: 0
   insert-after:
~~~~
answer.txt
~~~~
13. file: `tests/fixtures/abtest/verify/fixtures/syn-badref/build.sh`
   anchor: new file
   indent: 0
   insert-after:
~~~~
#!/usr/bin/env bash
set -euo pipefail
. "$ABT_REPO_ROOT/eval/abtest/fixtures/lib.sh"
mkdir -p "$1"
printf '1\n' > "$1/answer.txt"
printf '{"name":"syn","scripts":{"test":"true"}}\n' > "$1/package.json"
abt_fixture_baseline "$1"
~~~~
14. file: `tests/fixtures/abtest/verify/fixtures/syn-badref/reference.patch`
   anchor: new file
   indent: 0
   insert-after:
~~~~
--- a/answer.txt
+++ b/answer.txt
@@ -1 +1 @@
-1
+2
~~~~
15. file: `tests/fixtures/abtest/verify/fixtures/syn-ok/allowed-paths.txt`
   anchor: new file
   indent: 0
   insert-after:
~~~~
answer.txt
~~~~
16. file: `tests/fixtures/abtest/verify/fixtures/syn-ok/build.sh`
   anchor: new file
   indent: 0
   insert-after:
~~~~
#!/usr/bin/env bash
set -euo pipefail
. "$ABT_REPO_ROOT/eval/abtest/fixtures/lib.sh"
mkdir -p "$1"
printf '1\n' > "$1/answer.txt"
printf '{"name":"syn","scripts":{"test":"true"}}\n' > "$1/package.json"
abt_fixture_baseline "$1"
~~~~
17. file: `tests/fixtures/abtest/verify/fixtures/syn-ok/reference.patch`
   anchor: new file
   indent: 0
   insert-after:
~~~~
--- a/answer.txt
+++ b/answer.txt
@@ -1 +1 @@
-1
+2
~~~~
18. file: `tests/fixtures/abtest/verify/fixtures/syn-vacuous/allowed-paths.txt`
   anchor: new file
   indent: 0
   insert-after:
~~~~
answer.txt
~~~~
19. file: `tests/fixtures/abtest/verify/fixtures/syn-vacuous/build.sh`
   anchor: new file
   indent: 0
   insert-after:
~~~~
#!/usr/bin/env bash
set -euo pipefail
. "$ABT_REPO_ROOT/eval/abtest/fixtures/lib.sh"
mkdir -p "$1"
printf '1\n' > "$1/answer.txt"
printf '{"name":"syn","scripts":{"test":"true"}}\n' > "$1/package.json"
abt_fixture_baseline "$1"
~~~~
20. file: `tests/fixtures/abtest/verify/fixtures/syn-vacuous/reference.patch`
   anchor: new file
   indent: 0
   insert-after:
~~~~
--- a/answer.txt
+++ b/answer.txt
@@ -1 +1 @@
-1
+2
~~~~
21. command: `chmod +x eval/abtest/fixtures/lib.sh eval/abtest/checks/lib.sh eval/abtest/checks/scope.sh eval/abtest/verify-checks.sh tests/abtest-checks.test.sh`
   expect: 0
22. command: `git add eval/abtest/fixtures/lib.sh eval/abtest/checks/lib.sh eval/abtest/checks/scope.sh eval/abtest/verify-checks.sh tests/abtest-checks.test.sh tests/fixtures/abtest/verify/checks/syn-badref/check.sh tests/fixtures/abtest/verify/checks/syn-ok/check.sh tests/fixtures/abtest/verify/checks/syn-vacuous/check.sh tests/fixtures/abtest/verify/fixtures/syn-badref/allowed-paths.txt tests/fixtures/abtest/verify/fixtures/syn-badref/build.sh tests/fixtures/abtest/verify/fixtures/syn-badref/reference.patch tests/fixtures/abtest/verify/fixtures/syn-ok/allowed-paths.txt tests/fixtures/abtest/verify/fixtures/syn-ok/build.sh tests/fixtures/abtest/verify/fixtures/syn-ok/reference.patch tests/fixtures/abtest/verify/fixtures/syn-vacuous/allowed-paths.txt tests/fixtures/abtest/verify/fixtures/syn-vacuous/build.sh tests/fixtures/abtest/verify/fixtures/syn-vacuous/reference.patch && git commit -m "feat(abt-u04): check conventions and the non-vacuity verifier (#572)" -m "Co-Authored-By: Claude Sonnet 5.5 <noreply@anthropic.com>"`
   expect: 0

## Do NOT touch
- `eval/abtest/arms/` and `eval/abtest/lib/` (units abt-u01..u03 own them)
- `eval/harness/` (the one-arm pilot harness stays untouched)
- `tests/validate.sh` (merge-gate registration is unit abt-u17)
- `agents/`, `templates/`, `.claude-plugin/plugin.json`, `package.json`, `CHANGELOG.md` (no persona change, no version bump)
- `docs/plans/` (never edit a plan or contract by hand)

## Acceptance criteria
1. run: `bash tests/abtest-checks.test.sh`
   exit: 0
   stdout: `All abtest-checks checks passed.`
   mutation: skip edit 6 (verify-checks.sh); the verify rows FAIL, the script exits non-zero and the fragment is absent.
2. run: `ABT_FIXTURES_DIR=tests/fixtures/abtest/verify/fixtures ABT_CHECKS_ROOT=tests/fixtures/abtest/verify/checks bash eval/abtest/verify-checks.sh syn-ok`
   exit: 0
   stdout: `verify-checks: ok`
   mutation: skip edit 17 (syn-ok reference.patch); verify prints the missing-file line, exits 1 and the fragment is absent.
3. run: `ABT_FIXTURES_DIR=tests/fixtures/abtest/verify/fixtures ABT_CHECKS_ROOT=tests/fixtures/abtest/verify/checks bash eval/abtest/verify-checks.sh syn-vacuous`
   exit: 1
   stdout: `baseline-required-failures=0/2`
   mutation: skip edit 11 (syn-vacuous check.sh); verify prints the missing-file line instead and the fragment is absent.
4. run: `bash -n eval/abtest/fixtures/lib.sh && bash -n eval/abtest/checks/lib.sh && bash -n eval/abtest/checks/scope.sh && bash -n eval/abtest/verify-checks.sh && echo syntax-ok`
   exit: 0
   stdout: `syntax-ok`
   mutation: skip edit 5 (scope.sh); bash -n of the missing file exits 127 and nothing prints.
5. run: `test -x eval/abtest/verify-checks.sh && test -x eval/abtest/checks/scope.sh && test -x tests/abtest-checks.test.sh && echo exec-ok`
   exit: 0
   stdout: `exec-ok`
   mutation: skip edit 21; the files are not executable and nothing prints.
6. run: `L=$(git log --format='%H %s' | grep -E '^[0-9a-f]+ [a-z]+\(abt-u04\): ' | cut -d' ' -f1); test -n "$L" || { echo no-unit-commit; exit 3; }; c=$(echo "$L" | sed -n 1p); git diff --name-only "$c~1..$c" | LC_ALL=C sort | paste -sd" "`
   exit: 0
   stdout: `eval/abtest/checks/lib.sh eval/abtest/checks/scope.sh eval/abtest/fixtures/lib.sh eval/abtest/verify-checks.sh tests/abtest-checks.test.sh tests/fixtures/abtest/verify/checks/syn-badref/check.sh tests/fixtures/abtest/verify/checks/syn-ok/check.sh tests/fixtures/abtest/verify/checks/syn-vacuous/check.sh tests/fixtures/abtest/verify/fixtures/syn-badref/allowed-paths.txt tests/fixtures/abtest/verify/fixtures/syn-badref/build.sh tests/fixtures/abtest/verify/fixtures/syn-badref/reference.patch tests/fixtures/abtest/verify/fixtures/syn-ok/allowed-paths.txt tests/fixtures/abtest/verify/fixtures/syn-ok/build.sh tests/fixtures/abtest/verify/fixtures/syn-ok/reference.patch tests/fixtures/abtest/verify/fixtures/syn-vacuous/allowed-paths.txt tests/fixtures/abtest/verify/fixtures/syn-vacuous/build.sh tests/fixtures/abtest/verify/fixtures/syn-vacuous/reference.patch`
   mutation: skip edit 22 (the commit); no unit commit exists and the run prints no-unit-commit with exit 3.
7. run: `L=$(git log --format='%H %s' | grep -E '^[0-9a-f]+ [a-z]+\(abt-u04\): ' | cut -d' ' -f1); test -n "$L" || { echo no-unit-commit; exit 3; }; git log -1 --format=%B "$(echo "$L" | sed -n 1p)" | grep -c "^Co-Authored-By: Claude .* <noreply@anthropic.com>$"`
   exit: 0
   stdout: `1`
   mutation: skip edit 22; no unit commit exists and the exit is 3.
8. run: `L=$(git log --format='%H %s' | grep -E '^[0-9a-f]+ [a-z]+\(abt-u04\): ' | cut -d' ' -f1); test -n "$L" || { echo no-unit-commit; exit 3; }; E=$(echo "$L" | head -1); git log --format=%s "$E..HEAD" -- eval/abtest/fixtures/lib.sh eval/abtest/checks/lib.sh eval/abtest/checks/scope.sh eval/abtest/verify-checks.sh tests/abtest-checks.test.sh tests/fixtures/abtest/verify/checks/syn-badref/check.sh tests/fixtures/abtest/verify/checks/syn-ok/check.sh tests/fixtures/abtest/verify/checks/syn-vacuous/check.sh tests/fixtures/abtest/verify/fixtures/syn-badref/allowed-paths.txt tests/fixtures/abtest/verify/fixtures/syn-badref/build.sh tests/fixtures/abtest/verify/fixtures/syn-badref/reference.patch tests/fixtures/abtest/verify/fixtures/syn-ok/allowed-paths.txt tests/fixtures/abtest/verify/fixtures/syn-ok/build.sh tests/fixtures/abtest/verify/fixtures/syn-ok/reference.patch tests/fixtures/abtest/verify/fixtures/syn-vacuous/allowed-paths.txt tests/fixtures/abtest/verify/fixtures/syn-vacuous/build.sh tests/fixtures/abtest/verify/fixtures/syn-vacuous/reference.patch | grep -vcE "^[a-z]+\(abt-u04\): "`
   exit: 1
   stdout: `0`
   mutation: add a commit with subject `fix: x` touching one content file after the unit commit; stdout 1.
   proof: scratch run: with no later commit the count printed 0 (exit 1); a later untagged commit is counted by grep -v, so stdout is 1.
9. run: `git status --porcelain -- eval/abtest tests/abtest-checks.test.sh tests/fixtures/abtest/verify`
   exit: 0
   stdout: empty
   mutation: skip edit 22; the new files stay untracked and are listed.

## Pre-resolved context
tdd: yes tests/abtest-checks.test.sh (criteria 1-3 are the red-then-green checks; none of the files exist at HEAD)
blast-radius: none
gate-refusal: if any hook refuses a Bash command, STOP and report the refusal text; never route around it (no scratch-file, renamed-path or reworded-command workaround). Write every file with the Write or Edit tool, not a Bash heredoc.
payload-indent: every fenced payload in this contract starts at column 0 and states indent: 0; strip nothing; empty payload lines stay empty. A multi-part file is one new file plus consecutive insert-after edits, each anchored on the last line of the previous part.
already-green: criterion 9 (the scoped clean-tree check) passes at HEAD by design, because no file of the unit exists yet; it turns red only when the commit step is skipped.
no-real-claude: no command in this contract runs the real claude CLI. The synthetic fixtures use only grep and git.
conventions-for-later-units: every fixture unit (abt-u07..u11) writes eval/abtest/fixtures/<eval-id>/{build.sh,reference.patch,allowed-paths.txt} and eval/abtest/checks/<eval-id>/check.sh in exactly the shapes of the syn-ok files in this unit; check.sh is called as: check.sh WORKTREE BASE_SHA START_SHA ALLOWED_PATHS_FILE.
commit-message: feat(abt-u04): check conventions and the non-vacuity verifier (#572)
Co-Authored-By: Claude Sonnet 5.5 <noreply@anthropic.com>
diagnosis: none
review-packet:
~~~
unit: abt-u04 (#572)
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
criterion 9: <FILL: exit and stdout>
~~~

## Escalation
If any instruction cannot be followed exactly as written, STOP and report a spec gap; do not improvise.
