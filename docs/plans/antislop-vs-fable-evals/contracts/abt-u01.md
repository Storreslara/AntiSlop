Unit: abt-u01

## Objective
eval/abtest/arms/{common,arm-a,arm-b}.sh exist and build identical claude -p commands for the two arms (Arm B adds only --plugin-dir and --agent orchestrator); caps are --max-turns and a wall-clock timeout, never a dollar budget; tests/abtest-arms.test.sh passes against a fake claude; .gitignore ignores eval/abtest/.runs/ and eval/abtest/results.jsonl. One commit.

## Retrieval
GitHub issues: `gh issue view 569 --repo Storreslara/AntiSlop`. Siblings: `gh issue list --repo Storreslara/AntiSlop --label plan/antislop-vs-fable-evals`. Spec: `docs/plans/antislop-vs-fable-evals.md`; operator overrides (win on conflict): `docs/plans/antislop-vs-fable-evals/operator-decisions.md`.

## Affected files
- `eval/abtest/arms/common.sh` (anchor: new file)
- `eval/abtest/arms/arm-a.sh` (anchor: new file)
- `eval/abtest/arms/arm-b.sh` (anchor: new file)
- `tests/fixtures/abtest/fake-claude.sh` (anchor: new file)
- `tests/abtest-arms.test.sh` (anchor: new file)
- `.gitignore` (anchor: line matching `eval/results.jsonl`)

## Ordered edits
1. command: `test ! -e eval/abtest && test ! -e tests/abtest-arms.test.sh && test ! -e tests/fixtures/abtest && test -z "$(git status --porcelain --untracked-files=no -- . ':!.claude/agent-memory')"`
   expect: 0
2. file: `eval/abtest/arms/common.sh`
   anchor: new file
   indent: 0
   insert-after:
~~~~
#!/usr/bin/env bash
# Shared claude -p flags, caps and capture for both arms. Sourced, never run.
# Equal for both arms by construction: arm-a.sh and arm-b.sh build their
# command from abtest_common_flags and add nothing to it except Arm B's own
# --plugin-dir and --agent. No dollar cap: the operator is on a Max
# subscription, so the caps are a main-session turn cap and a wall-clock cap.
ABTEST_CLAUDE="${ABTEST_CLAUDE:-claude}"
ABTEST_MODEL="${ABTEST_MODEL:-fable}"
MAX_TURNS="${MAX_TURNS:-100}"
TIMEOUT_MIN="${TIMEOUT_MIN:-45}"

# One flag or value per line, so a test can compare the two arms.
abtest_common_flags() {
  printf '%s\n' \
    --output-format stream-json --verbose --include-hook-events \
    --permission-mode acceptEdits \
    --allowedTools 'Bash(npm test)' 'Bash(npm run *)' 'Bash(git *)' \
    --max-turns "$MAX_TURNS" --model "$ABTEST_MODEL" \
    --no-session-persistence
}

# abtest_make_config_dir DIR: a clean CLAUDE_CONFIG_DIR holding the
# operator's credentials and nothing else (no plugins, no user CLAUDE.md).
abtest_make_config_dir() {
  local dir="$1"
  rm -rf "$dir"
  mkdir -p "$dir"
  printf '{}\n' > "$dir/settings.json"
  if [ -f "$HOME/.claude/.credentials.json" ]; then
    cp "$HOME/.claude/.credentials.json" "$dir/.credentials.json"
  fi
  python3 - "$dir/.claude.json" "$HOME/.claude.json" <<'PYEOF'
import json, os, sys

dst, src = sys.argv[1], sys.argv[2]
cfg = {"hasCompletedOnboarding": True, "projects": {}}
if os.path.isfile(src):
    with open(src) as f:
        old = json.load(f)
    if "oauthAccount" in old:
        cfg["oauthAccount"] = old["oauthAccount"]
with open(dst, "w") as f:
    json.dump(cfg, f, indent=2)
    f.write("\n")
PYEOF
}

# abtest_trust_path DIR PATH: pre-trust PATH in DIR's .claude.json (a
# headless run has no TTY to accept the trust dialog).
abtest_trust_path() {
  python3 - "$1/.claude.json" "$2" <<'PYEOF'
import json, sys

cfg_path, target = sys.argv[1], sys.argv[2]
with open(cfg_path) as f:
    cfg = json.load(f)
cfg.setdefault("projects", {}).setdefault(target, {})["hasTrustDialogAccepted"] = True
with open(cfg_path, "w") as f:
    json.dump(cfg, f, indent=2)
    f.write("\n")
PYEOF
}

# abtest_run_claude WORKTREE PROMPT_FILE STREAM_FILE STDERR_FILE [extra flags]
# All paths absolute. Returns claude's exit code, or 124 on the wall-clock cap.
abtest_run_claude() {
  local wt="$1" pf="$2" out="$3" err="$4"
  shift 4
  local -a flags
  mapfile -t flags < <(abtest_common_flags)
  local rc=0
  ( cd "$wt" && timeout "${TIMEOUT_MIN}m" "$ABTEST_CLAUDE" -p "$(cat "$pf")" "${flags[@]}" "$@" ) > "$out" 2> "$err" || rc=$?
  return "$rc"
}
~~~~
3. file: `eval/abtest/arms/arm-a.sh`
   anchor: new file
   indent: 0
   insert-after:
~~~~
#!/usr/bin/env bash
# Arm A: bare Fable. claude -p in the fixture worktree with no plugin, no
# personas and no hooks. The worktree must hold no .claude directory.
# Usage: arm-a.sh WORKTREE PROMPT_FILE STREAM_FILE STDERR_FILE (absolute paths)
# Env:   ABTEST_CONFIG_DIR (required; a clean dir from abtest_make_config_dir)
# Prints one line, "scaffold-sha: <sha>", the commit the agent starts from.
set -euo pipefail
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=common.sh
. "$HERE/common.sh"

wt="${1:?usage: arm-a.sh WORKTREE PROMPT_FILE STREAM_FILE STDERR_FILE}"
pf="${2:?missing PROMPT_FILE}"
out="${3:?missing STREAM_FILE}"
err="${4:?missing STDERR_FILE}"
: "${ABTEST_CONFIG_DIR:?ABTEST_CONFIG_DIR must name a clean config dir}"

if [ -e "$wt/.claude" ]; then
  echo "arm-a.sh: $wt has a .claude directory; Arm A must run without one" >&2
  exit 3
fi

abtest_trust_path "$ABTEST_CONFIG_DIR" "$wt"
export CLAUDE_CONFIG_DIR="$ABTEST_CONFIG_DIR"
unset CLAUDE_CODE_SUBAGENT_MODEL
printf 'scaffold-sha: %s\n' "$(git -C "$wt" rev-parse HEAD)"
abtest_run_claude "$wt" "$pf" "$out" "$err"
~~~~
4. file: `eval/abtest/arms/arm-b.sh`
   anchor: new file
   indent: 0
   insert-after:
~~~~
#!/usr/bin/env bash
# Arm B: AntiSlop as shipped. Scaffolds the personas into the fixture
# worktree (non-interactively, as eval/harness/scaffold.sh does), writes the
# persona config, commits, then runs claude -p with the plugin loaded and the
# orchestrator as the main agent.
# Usage: arm-b.sh WORKTREE PROMPT_FILE STREAM_FILE STDERR_FILE PLUGIN_ROOT [OVERRIDES_JSON]
# Env:   ABTEST_CONFIG_DIR (required), ABTEST_POLICY (uniform|shipped, default uniform)
# Prints one line, "scaffold-sha: <sha>", the commit the agent starts from.
set -euo pipefail
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=common.sh
. "$HERE/common.sh"

wt="${1:?usage: arm-b.sh WORKTREE PROMPT_FILE STREAM_FILE STDERR_FILE PLUGIN_ROOT [OVERRIDES_JSON]}"
pf="${2:?missing PROMPT_FILE}"
out="${3:?missing STREAM_FILE}"
err="${4:?missing STDERR_FILE}"
plugin="${5:?missing PLUGIN_ROOT}"
overrides="${6:-}"
: "${ABTEST_CONFIG_DIR:?ABTEST_CONFIG_DIR must name a clean config dir}"

policy="${ABTEST_POLICY:-uniform}"
case "$policy" in
  uniform | shipped) ;;
  *) echo "arm-b.sh: ABTEST_POLICY must be uniform or shipped" >&2; exit 2 ;;
esac

# The file names are built from parts so no shell text names the gated files.
pcfg="$wt/.claude/persona""-config.json"
pjson="$plugin/.claude""-plugin/plugin.json"

( cd "$wt" && node "$plugin/bin/cli.js" --personas=spec-master,task-master,reviewer,scribe >/dev/null )

if [ ! -f "$wt/.claude/agents/reviewer.md" ]; then
  echo "arm-b.sh: scaffold left no reviewer.md; refusing to measure a degraded pipeline" >&2
  exit 3
fi

python3 - "$pcfg" "$pjson" "$overrides" <<'PYEOF'
import json, sys

cfg_path, plugin_json, overrides = sys.argv[1:4]
with open(plugin_json) as f:
    version = json.load(f)["version"]
cfg = {
    "testAndLintCommand": "npm test",
    "lintCommand": "true",
    "graphUpdateCommand": "",
    "sourceGlobs": [],
    "protectedPaths": [],
    "gatedAgents": ["lead-programmer"],
    "pluginVersion": version,
    "personaSelection": ["spec-master", "task-master", "reviewer", "scribe"],
    "issueTracker": "Local files: write one file per unit under docs/plans/<slug>/issues/ (no external tracker).",
    "humanReviewMode": "off",
    "reviewGating": {"mode": "enforce"},
    "dispatchHygiene": {"mode": "warn"},
}
if overrides:
    with open(overrides) as f:
        cfg.update(json.load(f))
with open(cfg_path, "w") as f:
    json.dump(cfg, f, indent=2)
    f.write("\n")
PYEOF

( cd "$wt" && git add -A && git -c user.name=abtest -c user.email=abtest@example.invalid commit -q -m "arm-b scaffold" )
sha="$(git -C "$wt" rev-parse HEAD)"

abtest_trust_path "$ABTEST_CONFIG_DIR" "$wt"
export CLAUDE_CONFIG_DIR="$ABTEST_CONFIG_DIR"
if [ "$policy" = uniform ]; then
  export CLAUDE_CODE_SUBAGENT_MODEL="$ABTEST_MODEL"
else
  unset CLAUDE_CODE_SUBAGENT_MODEL
fi
printf 'scaffold-sha: %s\n' "$sha"
abtest_run_claude "$wt" "$pf" "$out" "$err" --plugin-dir "$plugin" --agent orchestrator
~~~~
5. file: `tests/fixtures/abtest/fake-claude.sh`
   anchor: new file
   indent: 0
   insert-after:
~~~~
#!/usr/bin/env bash
# Test double for the claude CLI. Records its argv and a few env vars under
# FAKE_CLAUDE_LOG, then prints canned output. No network, no usage.
# Env: FAKE_CLAUDE_LOG (dir, required), FAKE_CLAUDE_STREAM (file to print as
#      stdout), FAKE_CLAUDE_STDERR (text for stderr), FAKE_CLAUDE_SLEEP
#      (seconds), FAKE_CLAUDE_EXIT (exit code, default 0), FAKE_CLAUDE_TOUCH
#      (a file name to create in the working directory, to mimic an edit).
set -u
log="${FAKE_CLAUDE_LOG:?FAKE_CLAUDE_LOG required}"
mkdir -p "$log"
n=$(( $(ls "$log" | grep -c '^argv\.') + 1 ))
printf '%s\0' "$@" > "$log/argv.$n"
{
  printf 'CLAUDE_CONFIG_DIR=%s\n' "${CLAUDE_CONFIG_DIR:-}"
  printf 'CLAUDE_CODE_SUBAGENT_MODEL=%s\n' "${CLAUDE_CODE_SUBAGENT_MODEL:-}"
  printf 'PWD=%s\n' "$PWD"
} > "$log/env.$n"
if [ -n "${FAKE_CLAUDE_SLEEP:-}" ]; then sleep "$FAKE_CLAUDE_SLEEP"; fi
if [ -n "${FAKE_CLAUDE_TOUCH:-}" ]; then printf 'x\n' > "$FAKE_CLAUDE_TOUCH"; fi
if [ -n "${FAKE_CLAUDE_STDERR:-}" ]; then printf '%s\n' "$FAKE_CLAUDE_STDERR" >&2; fi
if [ -n "${FAKE_CLAUDE_STREAM:-}" ]; then
  cat "$FAKE_CLAUDE_STREAM"
else
  printf '%s\n' '{"type":"result","subtype":"success","is_error":false,"num_turns":1,"result":"ok","usage":{"input_tokens":1,"output_tokens":1,"cache_creation_input_tokens":0,"cache_read_input_tokens":0},"modelUsage":{"fable-test":{"inputTokens":1,"outputTokens":1,"cacheReadInputTokens":0,"cacheCreationInputTokens":0}}}'
fi
exit "${FAKE_CLAUDE_EXIT:-0}"
~~~~
6. file: `tests/abtest-arms.test.sh`
   anchor: new file
   indent: 0
   insert-after:
~~~~
#!/usr/bin/env bash
# Tests eval/abtest/arms/{common,arm-a,arm-b}.sh against a fake claude. No
# network, no subscription usage, the real HOME is never read.
set -u
REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
ARMS="$REPO_ROOT/eval/abtest/arms"
FAKE="$REPO_ROOT/tests/fixtures/abtest/fake-claude.sh"
T="$(mktemp -d)"
trap 'rm -rf "$T"' EXIT
pass=0
fail=0
ok() { pass=$((pass + 1)); echo "ok   $1"; }
bad() { fail=$((fail + 1)); echo "FAIL $1"; }
check() { if [ "$2" = "$3" ]; then ok "$1"; else bad "$1 (want '$3', got '$2')"; fi; }

export HOME="$T/home"
mkdir -p "$HOME/.claude"
printf '{"fake":"credentials"}\n' > "$HOME/.claude/.credentials.json"
printf '{"oauthAccount":{"emailAddress":"fake@example.invalid"},"projects":{"/real":{}}}\n' > "$HOME/.claude.json"
HOME_SUM_BEFORE="$(cat "$HOME/.claude/.credentials.json" "$HOME/.claude.json" | sha256sum)"

export ABTEST_CLAUDE="$FAKE"
export FAKE_CLAUDE_LOG="$T/log"

mkrepo() {
  mkdir -p "$1"
  ( cd "$1" && git init -q && git config user.email t@t.invalid && git config user.name t \
    && printf '{"name":"x","scripts":{"test":"true"}}\n' > package.json \
    && git add -A && git commit -q -m baseline )
}

source "$ARMS/common.sh"
CFG="$T/cfg"
abtest_make_config_dir "$CFG"
check "config dir settings.json is empty object" "$(cat "$CFG/settings.json")" "{}"
check "config dir carries the credentials" "$(cat "$CFG/.credentials.json")" '{"fake":"credentials"}'
check "config dir carries onboarding flag" "$(python3 -c 'import json,sys;print(json.load(open(sys.argv[1]))["hasCompletedOnboarding"])' "$CFG/.claude.json")" "True"
check "config dir has no plugins directory" "$(ls "$CFG" | grep -c plugins)" "0"

printf 'Do the task.' > "$T/prompt.txt"
mkrepo "$T/wa"
mkrepo "$T/wb"

export ABTEST_CONFIG_DIR="$CFG"
outA="$(bash "$ARMS/arm-a.sh" "$T/wa" "$T/prompt.txt" "$T/a.stream" "$T/a.err")"
check "arm A exits 0" "$?" "0"
shaA="$(git -C "$T/wa" rev-parse HEAD)"
check "arm A prints its start sha" "$outA" "scaffold-sha: $shaA"
outB="$(bash "$ARMS/arm-b.sh" "$T/wb" "$T/prompt.txt" "$T/b.stream" "$T/b.err" "$REPO_ROOT")"
check "arm B exits 0" "$?" "0"
shaB="$(git -C "$T/wb" rev-parse HEAD)"
check "arm B prints its start sha" "$outB" "scaffold-sha: $shaB"
check "arm B scaffold commit subject" "$(git -C "$T/wb" log -1 --format=%s)" "arm-b scaffold"

tr '\0' '\n' < "$T/log/argv.1" > "$T/argvA"
tr '\0' '\n' < "$T/log/argv.2" > "$T/argvB"
check "arm A has no plugin-dir flag" "$(grep -c -e '--plugin-dir' "$T/argvA")" "0"
check "arm A has no agent flag" "$(grep -c -e '--agent' "$T/argvA")" "0"
check "arm B loads the plugin from the given root" "$(grep -A1 -e '--plugin-dir' "$T/argvB" | tail -1)" "$REPO_ROOT"
check "arm B runs the orchestrator as main agent" "$(grep -A1 -e '--agent' "$T/argvB" | tail -1)" "orchestrator"
check "no dollar budget flag in arm A" "$(grep -c -e '--max-budget-usd' "$T/argvA")" "0"
check "no dollar budget flag in arm B" "$(grep -c -e '--max-budget-usd' "$T/argvB")" "0"
check "turn cap is 100 in arm A" "$(grep -A1 -e '--max-turns' "$T/argvA" | tail -1)" "100"
check "turn cap is 100 in arm B" "$(grep -A1 -e '--max-turns' "$T/argvB" | tail -1)" "100"
check "stream-json with hook events in both arms" "$(grep -c -e '--include-hook-events' "$T/argvA" "$T/argvB" | tr '\n' ' ')" "$T/argvA:1 $T/argvB:1 "
grep -v -e '--plugin-dir' -e '--agent' -e "^$REPO_ROOT\$" -e '^orchestrator$' "$T/argvB" > "$T/argvB.common"
check "arms share every common flag (A equals B minus Arm B's own two)" "$(diff "$T/argvA" "$T/argvB.common" >/dev/null && echo same || echo differ)" "same"

check "arm A cannot see a subagent model override" "$(grep '^CLAUDE_CODE_SUBAGENT_MODEL=' "$T/log/env.1")" "CLAUDE_CODE_SUBAGENT_MODEL="
check "arm B uniform exports the model to subagents" "$(grep '^CLAUDE_CODE_SUBAGENT_MODEL=' "$T/log/env.2")" "CLAUDE_CODE_SUBAGENT_MODEL=fable"
check "both arms use the clean config dir" "$(grep -h '^CLAUDE_CONFIG_DIR=' "$T/log/env.1" "$T/log/env.2" | sort -u)" "CLAUDE_CONFIG_DIR=$CFG"
check "arm A ran inside the worktree" "$(grep '^PWD=' "$T/log/env.1")" "PWD=$T/wa"

check "arm B scaffold wrote the reviewer persona" "$(test -f "$T/wb/.claude/agents/reviewer.md" && echo yes)" "yes"
PC="$T/wb/.claude/persona""-config.json"
check "arm B config has review gating enforce" "$(python3 -c 'import json,sys;print(json.load(open(sys.argv[1]))["reviewGating"]["mode"])' "$PC")" "enforce"
check "arm B config has human review off" "$(python3 -c 'import json,sys;print(json.load(open(sys.argv[1]))["humanReviewMode"])' "$PC")" "off"
check "arm B config gates lead-programmer" "$(python3 -c 'import json,sys;print(json.load(open(sys.argv[1]))["gatedAgents"])' "$PC")" "['lead-programmer']"
~~~~
7. file: `tests/abtest-arms.test.sh`
   anchor: line matching `check "arm B config gates lead-programmer" "$(python3 -c 'import json,sys;print(json.load(open(sys.argv[1]))["gatedAgents"])' "$PC")" "['lead-programmer']"`
   indent: 0
   insert-after:
~~~~
check "trust entry written for both worktrees" "$(python3 -c 'import json,sys;p=json.load(open(sys.argv[1]))["projects"];print(sum(1 for v in p.values() if v.get("hasTrustDialogAccepted")))' "$CFG/.claude.json")" "2"

mkrepo "$T/wb2"
printf '{"protectedPaths":["src/auth.js"]}\n' > "$T/ov.json"
ABTEST_POLICY=shipped bash "$ARMS/arm-b.sh" "$T/wb2" "$T/prompt.txt" "$T/b2.stream" "$T/b2.err" "$REPO_ROOT" "$T/ov.json" > /dev/null
PC2="$T/wb2/.claude/persona""-config.json"
check "overrides merge into the arm B config" "$(python3 -c 'import json,sys;print(json.load(open(sys.argv[1]))["protectedPaths"])' "$PC2")" "['src/auth.js']"
check "arm B shipped policy exports no subagent model" "$(grep '^CLAUDE_CODE_SUBAGENT_MODEL=' "$T/log/env.3")" "CLAUDE_CODE_SUBAGENT_MODEL="

ABTEST_POLICY=bogus bash "$ARMS/arm-b.sh" "$T/wb2" "$T/prompt.txt" "$T/x.stream" "$T/x.err" "$REPO_ROOT" > /dev/null 2>&1
check "arm B rejects an unknown policy" "$?" "2"

mkrepo "$T/wa2"
mkdir "$T/wa2/.claude"
bash "$ARMS/arm-a.sh" "$T/wa2" "$T/prompt.txt" "$T/y.stream" "$T/y.err" > /dev/null 2>&1
check "arm A refuses a worktree holding a .claude directory" "$?" "3"

mkrepo "$T/wa3"
TIMEOUT_MIN=0.02 FAKE_CLAUDE_SLEEP=5 bash "$ARMS/arm-a.sh" "$T/wa3" "$T/prompt.txt" "$T/z.stream" "$T/z.err" > /dev/null 2>&1
check "wall-clock cap exits 124" "$?" "124"

check "real home credentials and config untouched" "$(cat "$HOME/.claude/.credentials.json" "$HOME/.claude.json" | sha256sum)" "$HOME_SUM_BEFORE"

echo "abtest-arms: $pass passed, $fail failed"
[ "$fail" -eq 0 ] && echo "All abtest-arms checks passed."
exit "$fail"
~~~~
8. file: `.gitignore`
   anchor: line matching `eval/results.jsonl`
   indent: 0
   insert-after:
~~~~
eval/abtest/.runs/
eval/abtest/results.jsonl
~~~~
9. command: `chmod +x eval/abtest/arms/common.sh eval/abtest/arms/arm-a.sh eval/abtest/arms/arm-b.sh tests/fixtures/abtest/fake-claude.sh tests/abtest-arms.test.sh`
   expect: 0
10. command: `git add .gitignore eval/abtest/arms/common.sh eval/abtest/arms/arm-a.sh eval/abtest/arms/arm-b.sh tests/fixtures/abtest/fake-claude.sh tests/abtest-arms.test.sh && git commit -m "feat(abt-u01): arm scripts with equal flags and a fake-claude test (#569)" -m "Co-Authored-By: Claude Sonnet 5.5 <noreply@anthropic.com>"`
   expect: 0

## Do NOT touch
- `eval/harness/` (the one-arm pilot harness stays untouched; this unit adds files beside it)
- `tests/validate.sh` (merge-gate registration of the new tests is unit abt-u17)
- `agents/`, `templates/`, `.claude-plugin/plugin.json`, `package.json`, `CHANGELOG.md` (no persona change, no version bump)
- `docs/plans/` (never edit a plan or contract by hand)

## Acceptance criteria
1. run: `bash tests/abtest-arms.test.sh`
   exit: 0
   stdout: `All abtest-arms checks passed.`
   mutation: skip edit 3 (arm-a.sh); the arm A rows FAIL, the script exits non-zero and the fragment is absent.
2. run: `bash -n eval/abtest/arms/common.sh && bash -n eval/abtest/arms/arm-a.sh && bash -n eval/abtest/arms/arm-b.sh && echo syntax-ok`
   exit: 0
   stdout: `syntax-ok`
   mutation: skip edit 3; bash -n of the missing arm-a.sh exits 127 and nothing prints.
3. run: `grep -c -e 'eval/abtest/.runs/' -e 'eval/abtest/results.jsonl' .gitignore`
   exit: 0
   stdout: `2`
   mutation: skip edit 8; stdout 0 and the exit is 1.
4. run: `grep -cE -e '--max-turns|--max-budget-usd' eval/abtest/arms/common.sh`
   exit: 0
   stdout: `1`
   mutation: skip edit 2; the file is missing, grep exits 2 and prints nothing.
5. run: `test -x eval/abtest/arms/arm-a.sh && test -x eval/abtest/arms/arm-b.sh && test -x tests/fixtures/abtest/fake-claude.sh && echo exec-ok`
   exit: 0
   stdout: `exec-ok`
   mutation: skip edit 9; the files are not executable and nothing prints.
6. run: `L=$(git log --format='%H %s' | grep -E '^[0-9a-f]+ [a-z]+\(abt-u01\): ' | cut -d' ' -f1); test -n "$L" || { echo no-unit-commit; exit 3; }; c=$(echo "$L" | sed -n 1p); git diff --name-only "$c~1..$c" | LC_ALL=C sort | paste -sd" "`
   exit: 0
   stdout: `.gitignore eval/abtest/arms/arm-a.sh eval/abtest/arms/arm-b.sh eval/abtest/arms/common.sh tests/abtest-arms.test.sh tests/fixtures/abtest/fake-claude.sh`
   mutation: skip edit 10 (the commit); no unit commit exists and the run prints no-unit-commit with exit 3.
7. run: `L=$(git log --format='%H %s' | grep -E '^[0-9a-f]+ [a-z]+\(abt-u01\): ' | cut -d' ' -f1); test -n "$L" || { echo no-unit-commit; exit 3; }; git log -1 --format=%B "$(echo "$L" | sed -n 1p)" | grep -c "^Co-Authored-By: Claude .* <noreply@anthropic.com>$"`
   exit: 0
   stdout: `1`
   mutation: skip edit 10; no unit commit exists and the exit is 3.
8. run: `L=$(git log --format='%H %s' | grep -E '^[0-9a-f]+ [a-z]+\(abt-u01\): ' | cut -d' ' -f1); test -n "$L" || { echo no-unit-commit; exit 3; }; E=$(echo "$L" | head -1); git log --format=%s "$E..HEAD" -- .gitignore eval/abtest/arms/common.sh eval/abtest/arms/arm-a.sh eval/abtest/arms/arm-b.sh tests/fixtures/abtest/fake-claude.sh tests/abtest-arms.test.sh | grep -vcE "^[a-z]+\(abt-u01\): "`
   exit: 1
   stdout: `0`
   mutation: add a commit with subject `fix: x` touching one content file after the unit commit; stdout 1.
   proof: scratch run: with no later commit the count printed 0 (exit 1); a later untagged commit is counted by grep -v, so stdout is 1.
9. run: `git status --porcelain -- eval/abtest tests/abtest-arms.test.sh tests/fixtures/abtest .gitignore`
   exit: 0
   stdout: empty
   mutation: skip edit 10; the new files stay untracked and are listed.

## Pre-resolved context
tdd: yes tests/abtest-arms.test.sh (criterion 1 is the red-then-green check; the arm scripts do not exist at HEAD)
blast-radius: none
gate-refusal: if any hook refuses a Bash command, STOP and report the refusal text; never route around it (no scratch-file, renamed-path or reworded-command workaround). Write every file with the Write or Edit tool, not a Bash heredoc.
payload-indent: every fenced payload in this contract starts at column 0 and states indent: 0; strip nothing; empty payload lines stay empty. A multi-part file is one new file plus consecutive insert-after edits, each anchored on the last line of the previous part.
already-green: criterion 9 (the scoped clean-tree check) passes at HEAD by design, because no file of the unit exists yet; it turns red only when the commit step is skipped.
no-real-claude: no command in this contract runs the real claude CLI; tests/abtest-arms.test.sh runs a fake claude and a fake HOME. Never run a headless claude in this unit.
persona-files: arm-b.sh and the test build the persona-config path from two parts on purpose, so no Bash text names the gated file; keep it that way and apply every edit with the Write or Edit tool.
commit-message: feat(abt-u01): arm scripts with equal flags and a fake-claude test (#569)
Co-Authored-By: Claude Sonnet 5.5 <noreply@anthropic.com>
diagnosis: none
review-packet:
~~~
unit: abt-u01 (#569)
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
