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
check "arm B scaffold commit subject is neutral" "$(git -C "$T/wb" log -1 --format=%s)" "add project tooling"
check "arm B scaffold commit identity is neutral" "$(git -C "$T/wb" log -1 --format='%an|%ae|%cn|%ce')" "dev|dev@example.invalid|dev|dev@example.invalid"
check "no commit the candidate can see names the test" "$(git -C "$T/wb" log --format='%an %ae %cn %ce %B' | grep -ciE 'abtest|eval|scaffold')" "0"

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
