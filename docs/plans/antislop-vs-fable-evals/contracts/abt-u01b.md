Unit: abt-u01b

## Objective
The arms can no longer read the harness: Arm B loads a pruned copy of the plugin (git archive of HEAD limited to .claude-plugin, agents, bin, commands, hooks, skills and templates) instead of the checkout; both arms get --disallowedTools Read, Edit and Bash rules for the harness root and ABTEST_DENY_PATHS, run with a per-run HOME outside the harness holding only a neutral git identity, and refuse a worktree, config dir or HOME inside the harness; the fake claude records HOME, the gitconfig and the plugin file list and can mimic a read; tests/abtest-arms.test.sh goes from 36 to 69 rows. One commit.

## Retrieval
GitHub issues: `gh issue view 608 --repo Storreslara/AntiSlop`. Siblings: `gh issue list --repo Storreslara/AntiSlop --label plan/antislop-vs-fable-evals`. Spec: `docs/plans/antislop-vs-fable-evals.md`; operator overrides (win on conflict): `docs/plans/antislop-vs-fable-evals/operator-decisions.md`.

## Affected files
- `eval/abtest/arms/common.sh` (anchor: line matching `TIMEOUT_MIN="${TIMEOUT_MIN:-45}"`)
- `eval/abtest/arms/arm-a.sh` (anchor: line matching `if [ -e "$wt/.claude" ]; then`)
- `eval/abtest/arms/arm-b.sh` (anchor: line matching `pjson="$plugin/.claude""-plugin/plugin.json"`)
- `tests/fixtures/abtest/fake-claude.sh` (anchor: line matching `printf 'PWD=%s\n' "$PWD"`)
- `tests/abtest-arms.test.sh` (anchor: line matching `check "real home credentials and config untouched"`)

## Ordered edits
1. command: `test -f eval/abtest/arms/common.sh && test -f eval/abtest/arms/arm-b.sh && test -f tests/fixtures/abtest/fake-claude.sh && test -f tests/abtest-arms.test.sh && ! grep -q abtest_plugin_copy eval/abtest/arms/common.sh && grep -q "OD-16" docs/plans/antislop-vs-fable-evals/operator-decisions.md && test -z "$(git status --porcelain --untracked-files=no -- . ':!.claude/agent-memory')"`
   expect: 0
2. file: `eval/abtest/arms/common.sh`
   anchor: line matching `TIMEOUT_MIN="${TIMEOUT_MIN:-45}"`
   indent: 0
   before:
~~~~
TIMEOUT_MIN="${TIMEOUT_MIN:-45}"

~~~~
   after:
~~~~
TIMEOUT_MIN="${TIMEOUT_MIN:-45}"
# The harness root is this checkout. The hidden checks, the reference solutions, the results and the fixtures live
# in it, so no arm may be able to read it (OD-16). ABTEST_DENY_PATHS adds more paths, colon-separated.
ABTEST_HARNESS_ROOT="${ABTEST_HARNESS_ROOT:-$(cd "$(dirname "${BASH_SOURCE[0]}")/../../.." && pwd -P)}"

~~~~
3. file: `eval/abtest/arms/common.sh`
   anchor: line matching `    --no-session-persistence`
   indent: 0
   before:
~~~~
    --no-session-persistence
}
~~~~
   after:
~~~~
    --no-session-persistence
}

# abtest_outside PATH...: fail when a path is, or is inside, the harness root (the path need not exist yet).
abtest_outside() {
  local p real
  for p in "$@"; do
    real="$(realpath -m -- "$p")" || return 1
    case "$real/" in
      "$ABTEST_HARNESS_ROOT"/*)
        echo "abtest: $p is inside the harness root $ABTEST_HARNESS_ROOT; an arm could read the hidden checks from it" >&2
        return 1
        ;;
    esac
  done
}

# abtest_deny_flags: --disallowedTools and one rule per line that keeps Read, Edit and Bash commands that name the
# harness root, or a path of ABTEST_DENY_PATHS, away from the arm. Read rules also govern Glob and Grep. A deny rule
# cannot stop a shell that never names the path, so the arms also run outside the harness (see abtest_outside).
abtest_deny_flags() {
  local p
  printf '%s\n' --disallowedTools
  while IFS= read -r p; do
    case "$p" in
      *[[:space:],\(\)]*)
        echo "abtest: a denied path may not hold a space, comma or parenthesis: $p" >&2
        return 1
        ;;
    esac
    printf '%s\n' "Read(/$p)" "Read(/$p/**)" "Edit(/$p/**)" "Bash(*$p*)"
  done < <(
    printf '%s\n' "$ABTEST_HARNESS_ROOT"
    local IFS=:
    for q in ${ABTEST_DENY_PATHS:-}; do [ -z "$q" ] || realpath -m -- "$q"; done
  )
}

# abtest_make_home DIR: a per-run HOME outside the harness with a neutral git identity and nothing else.
abtest_make_home() {
  local dir="$1"
  abtest_outside "$dir" || return 1
  rm -rf "${dir:?}"
  mkdir -p "$dir"
  printf '[user]\n\tname = dev\n\temail = dev@example.invalid\n' > "$dir/.gitconfig"
}

# abtest_plugin_copy ROOT DEST: only what the plugin needs, taken from ROOT's HEAD: the manifest, agents, bin,
# commands, hooks, skills and templates. The scaffold script needs no adapters or package.json (checked: the
# scaffold is byte-identical without them). eval/, tests/, docs/, .claude/ and every fixture, check and result stay out.
abtest_plugin_copy() {
  local root="$1" dest="$2"
  rm -rf "${dest:?}"
  mkdir -p "$dest"
  git -C "$root" archive HEAD .claude-plugin agents bin commands hooks skills templates | tar -x -C "$dest" || return 1
  [ -f "$dest/.claude-plugin/plugin.json" ] && [ -f "$dest/hooks/hooks.json" ] && [ -f "$dest/bin/cli.js" ] || return 1
}

# abtest_arm_setup WORKTREE: refuse a worktree or config dir inside the harness and make a per-run HOME.
abtest_arm_setup() {
  abtest_outside "$1" "${ABTEST_CONFIG_DIR:?}" || return 1
  if [ -z "${ABTEST_HOME:-}" ]; then
    ABTEST_HOME="$(mktemp -d "${TMPDIR:-/tmp}/abtest-home.XXXXXX")" || return 1
    ABTEST_HOME_OWNED=1
  fi
  abtest_make_home "$ABTEST_HOME" || return 1
  export ABTEST_HOME
}
~~~~
4. file: `eval/abtest/arms/common.sh`
   anchor: line matching `  local -a flags`
   indent: 0
   before:
~~~~
  local -a flags
  mapfile -t flags < <(abtest_common_flags)
  local rc=0
  ( cd "$wt" && timeout "${TIMEOUT_MIN}m" "$ABTEST_CLAUDE" -p "$(cat "$pf")" "${flags[@]}" "$@" ) > "$out" 2> "$err" || rc=$?
~~~~
   after:
~~~~
  local -a flags deny
  local denyout home="${ABTEST_HOME:?ABTEST_HOME must name the per-run HOME}"
  mapfile -t flags < <(abtest_common_flags)
  denyout="$(abtest_deny_flags)" || return 2
  mapfile -t deny <<< "$denyout"
  local rc=0
  ( cd "$wt" && env HOME="$home" GIT_CONFIG_GLOBAL="$home/.gitconfig" timeout "${TIMEOUT_MIN}m" "$ABTEST_CLAUDE" -p "$(cat "$pf")" "${flags[@]}" "${deny[@]}" "$@" ) > "$out" 2> "$err" || rc=$?
~~~~
5. file: `eval/abtest/arms/arm-a.sh`
   anchor: line matching `: "${ABTEST_CONFIG_DIR:?ABTEST_CONFIG_DIR must name a clean config dir}"`
   indent: 0
   before:
~~~~
: "${ABTEST_CONFIG_DIR:?ABTEST_CONFIG_DIR must name a clean config dir}"

if [ -e "$wt/.claude" ]; then
  echo "arm-a.sh: $wt has a .claude directory; Arm A must run without one" >&2
~~~~
   after:
~~~~
: "${ABTEST_CONFIG_DIR:?ABTEST_CONFIG_DIR must name a clean config dir}"

abtest_arm_setup "$wt" || exit 2
if [ "${ABTEST_HOME_OWNED:-0}" = 1 ]; then trap 'rm -rf "${ABTEST_HOME:?}"' EXIT; fi
if [ -e "$wt/.claude" ]; then
  echo "arm-a.sh: $wt has a .claude directory; Arm A must run without one" >&2
~~~~
6. file: `eval/abtest/arms/arm-b.sh`
   anchor: line matching `esac`
   indent: 0
   before:
~~~~
esac

~~~~
   after:
~~~~
esac

abtest_arm_setup "$wt" || exit 2
# Arm B loads a pruned copy of the plugin, never the checkout: the checkout holds the hidden checks and the
# reference solutions (OD-16). The copy is exactly the checkout's HEAD, so the plugin commit in the row still names it.
copydir="$(mktemp -d "${TMPDIR:-/tmp}/abtest-plugin.XXXXXX")"
trap 'rm -rf "${copydir:?}"; if [ "${ABTEST_HOME_OWNED:-0}" = 1 ]; then rm -rf "${ABTEST_HOME:?}"; fi' EXIT
abtest_outside "$copydir" || exit 2
abtest_plugin_copy "$plugin" "$copydir/plugin" || { echo "arm-b.sh: could not build the plugin copy from $plugin" >&2; exit 3; }
plugin="$copydir/plugin"

~~~~
7. file: `tests/fixtures/abtest/fake-claude.sh`
   anchor: line matching `#      (a file name to create in the working directory, to mimic an edit).`
   indent: 0
   before:
~~~~
#      (a file name to create in the working directory, to mimic an edit).
~~~~
   after:
~~~~
#      (a file name to create in the working directory, to mimic an edit),
#      FAKE_CLAUDE_READ (a file whose text is printed as the result, to mimic an arm that read it).
~~~~
8. file: `tests/fixtures/abtest/fake-claude.sh`
   anchor: line matching `} > "$log/env.$n"`
   indent: 0
   before:
~~~~
} > "$log/env.$n"
~~~~
   after:
~~~~
  printf 'HOME=%s\n' "${HOME:-}"
  printf 'GIT_CONFIG_GLOBAL=%s\n' "${GIT_CONFIG_GLOBAL:-}"
} > "$log/env.$n"
# The files of the plugin directory the arm passed, as seen at run time (the arm removes its copy afterwards).
[ -n "${GIT_CONFIG_GLOBAL:-}" ] && [ -f "$GIT_CONFIG_GLOBAL" ] && cp "$GIT_CONFIG_GLOBAL" "$log/gitconfig.$n"
prev=""
for a in "$@"; do
  if [ "$prev" = "--plugin-dir" ] && [ -d "$a" ]; then ( cd "$a" && find . -type f | sed 's|^\./||' | sort ) > "$log/plugin-files.$n"; fi
  prev="$a"
done
~~~~
9. file: `tests/fixtures/abtest/fake-claude.sh`
   anchor: line matching `if [ -n "${FAKE_CLAUDE_STDERR:-}" ]; then printf '%s\n' "$FAKE_CLAUDE_STDERR" >&2; fi`
   indent: 0
   before:
~~~~
if [ -n "${FAKE_CLAUDE_STDERR:-}" ]; then printf '%s\n' "$FAKE_CLAUDE_STDERR" >&2; fi
if [ -n "${FAKE_CLAUDE_STREAM:-}" ]; then
~~~~
   after:
~~~~
if [ -n "${FAKE_CLAUDE_STDERR:-}" ]; then printf '%s\n' "$FAKE_CLAUDE_STDERR" >&2; fi
if [ -n "${FAKE_CLAUDE_READ:-}" ]; then
  # Mimic an arm that reads a file: print its text as the result, or "unreadable".
  python3 -I -c 'import json,sys
try:
    t = open(sys.argv[1]).read()
except OSError:
    t = "unreadable"
print(json.dumps({"type": "result", "subtype": "success", "is_error": False, "num_turns": 1, "result": t}))' "$FAKE_CLAUDE_READ"
  exit "${FAKE_CLAUDE_EXIT:-0}"
fi
if [ -n "${FAKE_CLAUDE_STREAM:-}" ]; then
~~~~
10. file: `tests/abtest-arms.test.sh`
   anchor: line matching `check "arm B loads the plugin from the given root"`
   indent: 0
   before:
~~~~
check "arm B loads the plugin from the given root" "$(grep -A1 -e '--plugin-dir' "$T/argvB" | tail -1)" "$REPO_ROOT"
check "arm B runs the orchestrator as main agent" "$(grep -A1 -e '--agent' "$T/argvB" | tail -1)" "orchestrator"
~~~~
   after:
~~~~
check "arm B runs the orchestrator as main agent" "$(grep -A1 -e '--agent' "$T/argvB" | tail -1)" "orchestrator"
~~~~
11. file: `tests/abtest-arms.test.sh`
   anchor: line matching `grep -v -e`
   before: `grep -v -e '--plugin-dir' -e '--agent' -e "^$REPO_ROOT\$" -e '^orchestrator$' "$T/argvB" > "$T/argvB.common"`
   after: `awk '/^--plugin-dir$/ || /^--agent$/ {skip = 2} skip > 0 {skip--; next} 1' "$T/argvB" > "$T/argvB.common"`
12. file: `tests/abtest-arms.test.sh`
   anchor: line matching `check "wall-clock cap exits 124" "$?" "124"`
   indent: 0
   insert-after:
~~~~
# --- harness isolation (abt-u01b, OD-16): a pruned plugin copy, deny rules, a per-run HOME, nothing inside the harness ---
REPO_PHYS="$(cd "$REPO_ROOT" && pwd -P)"
TP="$(cd "$T" && pwd -P)"
PLUG_ARG="$(grep -A1 -e '--plugin-dir' "$T/argvB" | tail -1)"
PF="$T/log/plugin-files.2"
check "arm B loads a pruned copy of the plugin, not the checkout" "$([ "$PLUG_ARG" != "$REPO_ROOT" ] && [ -s "$PF" ] && echo copy)" "copy"
check "the plugin copy lies outside the harness" "$(case "$PLUG_ARG/" in "$REPO_PHYS"/* | "$REPO_ROOT"/*) echo inside ;; *) echo outside ;; esac)" "outside"
check "the plugin copy holds the manifest, the hooks and the scaffold script" "$(grep -cxE '\.claude-plugin/plugin\.json|hooks/hooks\.json|bin/cli\.js' "$PF")" "3"
check "the plugin copy holds nothing from eval, tests, docs or .claude" "$(grep -cE '^(eval|tests|docs|\.claude|specs|prototype|scratch|tmp|microworlds|scripts)/' "$PF")" "0"
check "every hook script hooks.json names is in the plugin copy" "$(for f in $(python3 -I -c 'import re,sys;print(" ".join(sorted(set(re.findall(r"CLAUDE_PLUGIN_ROOT\}/([^\" ]+)", open(sys.argv[1]).read())))))' "$REPO_ROOT/hooks/hooks.json"); do grep -qxF "$f" "$PF" || echo "missing $f"; done | wc -l | tr -d ' ')" "0"
abtest_plugin_copy "$REPO_ROOT" "$T/pcopy"; check "abtest_plugin_copy succeeds on the checkout" "$?" "0"
check "no file of the plugin copy names a hidden check or a reference solution" "$(find "$T/pcopy" -type f -exec grep -IiEl 'holdout|reference\.patch|abtest' {} + | wc -l | tr -d ' ')" "0"
rm -rf "$T/refscaf"; mkdir "$T/refscaf"; ( cd "$T/refscaf" && git init -q && node "$REPO_ROOT/bin/cli.js" --personas=spec-master,task-master,reviewer,scribe > /dev/null )
check "the scaffold from the pruned copy equals the scaffold from the full checkout" "$(diff -rq -x 'persona-config.json' "$T/refscaf/.claude" "$T/wb/.claude" > /dev/null && echo same || echo differ)" "same"
abtest_plugin_copy "$T" "$T/pcopy2" 2> /dev/null; check "abtest_plugin_copy fails on a directory that is not a git checkout" "$?" "1"
for a in A B; do
  check "arm $a passes --disallowedTools once" "$(grep -cx -e '--disallowedTools' "$T/argv$a")" "1"
  check "arm $a denies Read of the harness root" "$(grep -cxF "Read(/$REPO_PHYS/**)" "$T/argv$a")" "1"
  check "arm $a denies Read of a single path (a results file)" "$(grep -cxF "Read(/$REPO_PHYS)" "$T/argv$a")" "1"
  check "arm $a denies Edit of the harness root" "$(grep -cxF "Edit(/$REPO_PHYS/**)" "$T/argv$a")" "1"
  check "arm $a denies Bash commands that name the harness root" "$(grep -cxF "Bash(*$REPO_PHYS*)" "$T/argv$a")" "1"
done
mkrepo "$T/wa4"
ABTEST_DENY_PATHS="$T/results:$T/runs" bash "$ARMS/arm-a.sh" "$T/wa4" "$T/prompt.txt" "$T/w4.stream" "$T/w4.err" > /dev/null
N4="$(ls "$T/log" | grep -c '^argv\.')"
tr '\0' '\n' < "$T/log/argv.$N4" > "$T/argv4"
check "ABTEST_DENY_PATHS adds a Read rule for each path" "$(grep -cxF "Read(/$TP/results/**)" "$T/argv4")|$(grep -cxF "Read(/$TP/runs/**)" "$T/argv4")" "1|1"
check "the per-run HOME is not the operator's and not inside the harness" "$(h="$(sed -n 's/^HOME=//p' "$T/log/env.1")"; case "$h" in "$HOME" | "" | "$REPO_PHYS"/* | "$REPO_ROOT"/*) echo bad ;; *) echo ok ;; esac)" "ok"
check "git runs with the neutral identity" "$(grep -c 'email = dev@example.invalid' "$T/log/gitconfig.1")" "1"
mkdir -p "$T/tmpa" "$T/tmpb"
mkrepo "$T/wa5"; mkrepo "$T/wb5"
TMPDIR="$T/tmpa" bash "$ARMS/arm-a.sh" "$T/wa5" "$T/prompt.txt" "$T/w5.stream" "$T/w5.err" > /dev/null
TMPDIR="$T/tmpb" bash "$ARMS/arm-b.sh" "$T/wb5" "$T/prompt.txt" "$T/w6.stream" "$T/w6.err" "$REPO_ROOT" > /dev/null
check "arm A removes its per-run HOME" "$(ls "$T/tmpa" | wc -l | tr -d ' ')" "0"
check "arm B removes its per-run HOME and its plugin copy" "$(ls "$T/tmpb" | wc -l | tr -d ' ')" "0"
mkrepo "$T/wa6"
out="$(ABTEST_CONFIG_DIR="$REPO_PHYS/eval/abtest/.runs/cfg-probe" bash "$ARMS/arm-a.sh" "$T/wa6" "$T/prompt.txt" "$T/w7.stream" "$T/w7.err" 2>&1)"; rc=$?
check "arm A refuses a config dir inside the harness" "$rc" "2"
check "the refusal names the harness root" "$(printf '%s' "$out" | grep -c 'is inside the harness root')" "1"
check "the refused config dir was not created" "$(test -e "$REPO_PHYS/eval/abtest/.runs/cfg-probe" && echo made || echo none)" "none"
out="$(bash "$ARMS/arm-a.sh" "$REPO_PHYS/eval/abtest/.runs/wt-probe" "$T/prompt.txt" "$T/w8.stream" "$T/w8.err" 2>&1)"; rc=$?
check "arm A refuses a worktree inside the harness" "$rc" "2"
out="$(ABTEST_HOME="$REPO_PHYS/eval/abtest/.runs/home-probe" bash "$ARMS/arm-a.sh" "$T/wa6" "$T/prompt.txt" "$T/w9.stream" "$T/w9.err" 2>&1)"; rc=$?
check "arm A refuses a HOME inside the harness" "$rc" "2"
check "the refused HOME was not created" "$(test -e "$REPO_PHYS/eval/abtest/.runs/home-probe" && echo made || echo none)" "none"
out="$(bash "$ARMS/arm-b.sh" "$REPO_PHYS/eval/abtest/.runs/wt-probe" "$T/prompt.txt" "$T/wa.stream" "$T/wa.err" "$REPO_ROOT" 2>&1)"; rc=$?
check "arm B refuses a worktree inside the harness" "$rc" "2"
mkrepo "$T/wa7"
ABTEST_DENY_PATHS="$T/a b" bash "$ARMS/arm-a.sh" "$T/wa7" "$T/prompt.txt" "$T/w10.stream" "$T/w10.err" > /dev/null 2>&1
check "a denied path with a space is refused" "$?" "2"
mkdir -p "$T/notgit"; mkrepo "$T/wb8"
out="$(bash "$ARMS/arm-b.sh" "$T/wb8" "$T/prompt.txt" "$T/w11.stream" "$T/w11.err" "$T/notgit" 2>&1)"; rc=$?
check "arm B stops with exit 3 when the plugin copy cannot be built" "$rc|$(printf '%s' "$out" | grep -c 'could not build the plugin copy')" "3|1"
rm -rf "$T/half"; mkdir -p "$T/half/.claude-plugin" "$T/half/agents" "$T/half/bin" "$T/half/commands" "$T/half/hooks" "$T/half/skills" "$T/half/templates"
for f in .claude-plugin/plugin.json agents/x bin/cli.js commands/x hooks/dummy skills/x templates/x; do printf 'x\n' > "$T/half/$f"; done
( cd "$T/half" && git init -q && git add -A && git -c user.name=t -c user.email=t@t.invalid commit -q -m x ) || bad "setup: half plugin"
mkrepo "$T/wb9"
out="$(bash "$ARMS/arm-b.sh" "$T/wb9" "$T/prompt.txt" "$T/w12.stream" "$T/w12.err" "$T/half" 2>&1)"; rc=$?
check "a plugin copy without hooks.json is refused" "$rc|$(printf '%s' "$out" | grep -c 'could not build the plugin copy')" "3|1"
~~~~
13. command: `git add eval/abtest/arms/common.sh eval/abtest/arms/arm-a.sh eval/abtest/arms/arm-b.sh tests/fixtures/abtest/fake-claude.sh tests/abtest-arms.test.sh && git commit -m "fix(abt-u01b): the arms run outside the harness with a pruned plugin copy, deny rules and a per-run HOME (#608)" -m "Co-Authored-By: Claude Sonnet 5.5 <noreply@anthropic.com>"`
   expect: 0

## Do NOT touch
- `eval/abtest/run-matrix.sh` and `eval/abtest/lib/` (the runner side is abt-u12c; the probe is abt-u13b)
- `eval/abtest/fixtures/`, `eval/abtest/checks/`, `eval/abtest/templates/` (nothing about fixtures changes here)
- `tests/abtest-checks.test.sh`, `tests/abtest-stream.test.sh` (other units own them)
- `agents/`, `templates/`, `.claude-plugin/plugin.json`, `package.json`, `CHANGELOG.md` (no persona change, no version bump)
- `docs/plans/antislop-vs-fable-evals/operator-decisions.md` and the rest of `docs/plans/` (OD-16 is already written; never edit a plan by hand)

## Acceptance criteria
1. run: `bash tests/abtest-arms.test.sh`
   exit: 0
   stdout: `All abtest-arms checks passed.`
   mutation: skip edit 2 (the first change of common.sh); the new rows FAIL, the script exits non-zero and the fragment is absent.
   proof: mutation matrix of 33 single edits, run in a scratch copy of the finished change, each making bash tests/abtest-arms.test.sh exit non-zero: C1 and C2 point the harness root at the wrong directory or disable the inside-harness check; C3 let realpath fail on a path that does not exist yet; C4 to C6 drop the Read (directory or single path), Edit or Bash deny rule; C7 drop the --disallowedTools flag; C8 ignore ABTEST_DENY_PATHS; C9 allow a space in a denied path; C10 drop the git identity; C11 to C16 leave templates, agents, hooks, skills or bin out of the plugin copy, or copy the whole checkout; C17 skips the check of the copy; C19 and C20 keep the operator HOME or drop GIT_CONFIG_GLOBAL; C21 and C22 do not pass the deny rules or ignore their failure; C23 and C24 stop checking the config dir or the worktree; C25 stop checking the HOME; C26 stop marking a HOME as owned; A1 and A2 drop arm A's setup or its HOME cleanup; B1 to B5 drop arm B's setup, load the checkout instead of the copy, leave the copy or the HOME behind, or ignore a failed copy. One edit is not claimed because it is equivalent: ignoring a failed archive in abtest_plugin_copy (the copy check right after it still refuses)
2. run: `bash tests/abtest-arms.test.sh | grep -c '^ok '`
   exit: 0
   stdout: `69`
   mutation: skip edit 2; the new rows FAIL and the count drops below 69.
3. run: `bash tests/abtest-arms.test.sh | grep -c '^ok   arm [AB] denies'`
   exit: 0
   stdout: `6`
   mutation: skip edit 2; the deny rules are absent, the rows print FAIL and the count is 0 (exit 1).
4. run: `bash tests/abtest-arms.test.sh | grep -c '^ok   arm B loads a pruned copy of the plugin, not the checkout'`
   exit: 0
   stdout: `1`
   mutation: skip edit 6; arm B still passes the checkout, the row prints FAIL and the count is 0 (exit 1).
5. run: `bash tests/abtest-arms.test.sh | grep -c '^ok   the scaffold from the pruned copy equals the scaffold from the full checkout'`
   exit: 0
   stdout: `1`
   mutation: remove templates from the archive list in abtest_plugin_copy in the finished common.sh; the scaffold fails or differs, the row prints FAIL and the count is 0 (exit 1).
   proof: mutation C11 of the matrix in criterion 1, run in a scratch copy: with templates dropped from the list the row printed FAIL.
6. run: `bash tests/abtest-arms.test.sh | grep -c '^ok   arm A refuses a config dir inside the harness'`
   exit: 0
   stdout: `1`
   mutation: skip edit 5; arm A no longer refuses, the row prints FAIL and the count is 0 (exit 1).
7. run: `bash tests/abtest-arms.test.sh | grep -c '^ok   the per-run HOME is not the operator'`
   exit: 0
   stdout: `1`
   mutation: skip edit 2; arm A runs with the operator HOME, the row prints FAIL and the count is 0 (exit 1).
8. run: `bash tests/abtest-arms.test.sh > /dev/null; git status --porcelain -- eval/abtest/.runs | wc -l | tr -d ' '`
   exit: 0
   stdout: `0`
   mutation: disable the inside-harness check in the finished common.sh (replace "$ABTEST_HARNESS_ROOT"/*) by "$ABTEST_HARNESS_ROOT"/__none__) in abtest_outside); the refusal rows then create their probe paths under eval/abtest/.runs and the count is 1 or more.
   proof: mutation C2 of the matrix in criterion 1, run in a scratch copy: with the harness check disabled the refused config dir was created.
9. run: `L=$(git log --format='%H %s' | grep -E '^[0-9a-f]+ [a-z]+\(abt-u01b\): ' | cut -d' ' -f1); test -n "$L" || { echo no-unit-commit; exit 3; }; c=$(echo "$L" | sed -n 1p); git diff --name-only "$c~1..$c" | LC_ALL=C sort | paste -sd" "`
   exit: 0
   stdout: `eval/abtest/arms/arm-a.sh eval/abtest/arms/arm-b.sh eval/abtest/arms/common.sh tests/abtest-arms.test.sh tests/fixtures/abtest/fake-claude.sh`
   mutation: skip edit 13 (the commit); no unit commit exists and the run prints no-unit-commit with exit 3.
10. run: `L=$(git log --format='%H %s' | grep -E '^[0-9a-f]+ [a-z]+\(abt-u01b\): ' | cut -d' ' -f1); test -n "$L" || { echo no-unit-commit; exit 3; }; git log -1 --format=%B "$(echo "$L" | sed -n 1p)" | grep -c "^Co-Authored-By: Claude .* <noreply@anthropic.com>$"`
   exit: 0
   stdout: `1`
   mutation: skip edit 13; no unit commit exists and the exit is 3.
11. run: `L=$(git log --format='%H %s' | grep -E '^[0-9a-f]+ [a-z]+\(abt-u01b\): ' | cut -d' ' -f1); test -n "$L" || { echo no-unit-commit; exit 3; }; E=$(echo "$L" | head -1); git log --format=%s "$E..HEAD" -- eval/abtest/arms/common.sh eval/abtest/arms/arm-a.sh eval/abtest/arms/arm-b.sh tests/fixtures/abtest/fake-claude.sh tests/abtest-arms.test.sh | grep -vcE "^[a-z]+\(abt-u01b\): "`
   exit: 1
   stdout: `0`
   mutation: add a commit with subject `fix: x` touching one content file after the unit commit; stdout 1.
   proof: scratch run: with no later commit the count printed 0 (exit 1); a later untagged commit is counted by grep -v, so stdout is 1.
12. run: `git status --porcelain -- eval/abtest/arms/common.sh eval/abtest/arms/arm-a.sh eval/abtest/arms/arm-b.sh tests/fixtures/abtest/fake-claude.sh tests/abtest-arms.test.sh`
   exit: 0
   stdout: empty
   mutation: skip edit 13; the new files stay untracked and are listed.

## Pre-resolved context
tdd: yes tests/abtest-arms.test.sh (criteria 2 to 8 are the red-then-green checks: the isolation rows do not exist at HEAD)
blast-radius: eval/abtest/arms/common.sh:36, eval/abtest/arms/arm-a.sh:22, eval/abtest/arms/arm-b.sh:30, tests/fixtures/abtest/fake-claude.sh:15, tests/abtest-arms.test.sh:53
gate-refusal: if any hook refuses a Bash command, STOP and report the refusal text; never route around it (no scratch-file, renamed-path or reworded-command workaround). Write every file with the Write or Edit tool, not a Bash heredoc.
payload-indent: every fenced payload in this contract starts at column 0 and states indent: 0; strip nothing; empty payload lines stay empty. A multi-part file is one new file plus consecutive insert-after edits, each anchored on the last line of the previous part.
already-green: criterion 1 passes at HEAD only before the new rows exist, criterion 8 (nothing is created under eval/abtest/.runs) and criterion 12 (the scoped clean-tree check) pass at HEAD by design; criteria 2 to 7 fail at HEAD.
extends-landed-code: abt-u01 is on master and abt-u05d changed the arm B scaffold commit; every anchor and replaced block is a line of master at the time of writing. Two existing test rows change: the row "arm B loads the plugin from the given root" is removed (Arm B now loads a copy) and the common-flag comparison drops --plugin-dir and --agent with their values by position.
od-16: harness isolation (operator decision, binding). The hidden checks (eval/abtest/checks), the reference solutions (eval/abtest/fixtures/*/reference.patch), the fixtures and the results live in the checkout, which Arm B used to load as its plugin and which both arms could reach with the operator HOME. Now: (a) Arm B loads a copy made by git archive of the checkout HEAD limited to .claude-plugin agents bin commands hooks skills templates (adapters and package.json are not needed: the scaffold is byte-identical without them); the plugin commit in the row still names the checkout HEAD, which is exactly what the copy holds. (b) Both arms get --disallowedTools with Read, Edit and Bash(*path*) rules for the harness root and every path of ABTEST_DENY_PATHS (colon-separated; no space, comma or parenthesis in a path); the CLI applies Read deny rules to its Glob and Grep search too. (c) Both arms run with a per-run HOME made outside the harness (TMPDIR, default /tmp) holding only a .gitconfig with the dev identity, and GIT_CONFIG_GLOBAL pointing at it; an arm removes the HOME and the plugin copy it created. (d) An arm refuses (exit 2) a worktree, config dir or HOME inside the harness root.
residual-risk: a deny rule cannot stop a shell command that never names the path (find / -name ... then cat), and a determined agent with Bash could still find the checkout. The measures are defence in depth. abt-u13b plants a canary and tests it end to end; no command here runs the real claude CLI, so the rule strings are checked in argv only. Flags used exist in claude 2.1.302: --disallowedTools, --plugin-dir, --agent.
fake-claude: the test double also records HOME, GIT_CONFIG_GLOBAL, a copy of the gitconfig and the file list of the --plugin-dir it was given (the arm removes its copy afterwards), and with FAKE_CLAUDE_READ=<file> prints that file as the result text (or unreadable); abt-u13b uses it.
fail-closed: every row compares an explicit value; a crash or empty output reads as FAILURE. A failed plugin copy exits 3 before any run; a refused path exits 2.
no-real-claude: no command in this contract runs the real claude CLI.
commit-message: fix(abt-u01b): the arms run outside the harness with a pruned plugin copy, deny rules and a per-run HOME (#608)
Co-Authored-By: Claude Sonnet 5.5 <noreply@anthropic.com>
diagnosis: none
review-packet:
~~~
unit: abt-u01b (#608)
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
criterion 10: <FILL: exit and stdout>
criterion 11: <FILL: exit and stdout>
criterion 12: <FILL: exit and stdout>
~~~

## Escalation
If any instruction cannot be followed exactly as written, STOP and report a spec gap; do not improvise.
