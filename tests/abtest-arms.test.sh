#!/usr/bin/env bash
# Tests eval/abtest/arms/{common,arm-a,arm-b}.sh against a fake claude. No
# network, no subscription usage, the real HOME is never read.
set -u
REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
ARMS="$REPO_ROOT/eval/abtest/arms"
FAKE="$REPO_ROOT/tests/fixtures/abtest/fake-claude.sh"
T="$(mktemp -d)" && [ -d "${T:-}" ] || { echo "mktemp -d failed" >&2; exit 2; }
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
check "arm B runs the orchestrator as main agent" "$(grep -A1 -e '--agent' "$T/argvB" | tail -1)" "orchestrator"
check "no dollar budget flag in arm A" "$(grep -c -e '--max-budget-usd' "$T/argvA")" "0"
check "no dollar budget flag in arm B" "$(grep -c -e '--max-budget-usd' "$T/argvB")" "0"
check "turn cap is 100 in arm A" "$(grep -A1 -e '--max-turns' "$T/argvA" | tail -1)" "100"
check "turn cap is 100 in arm B" "$(grep -A1 -e '--max-turns' "$T/argvB" | tail -1)" "100"
check "stream-json with hook events in both arms" "$(grep -c -e '--include-hook-events' "$T/argvA" "$T/argvB" | tr '\n' ' ')" "$T/argvA:1 $T/argvB:1 "
awk '/^--plugin-dir$/ || /^--agent$/ {skip = 2} skip > 0 {skip--; next} 1' "$T/argvB" > "$T/argvB.common"
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
# --- shared read-only allows (abt-u13d, OD-17): identical in both arms, nothing that writes, deny rules still win ---
allow_of() { awk '/^--allowedTools$/ {f = 1; next} /^--/ {f = 0} f' "$1"; }
allow_of "$T/argvA" > "$T/allowA"
allow_of "$T/argvB" > "$T/allowB"
check "both arms pass the same --allowedTools values" "$(cmp -s "$T/allowA" "$T/allowB" && echo same || echo differ)" "same"
check "the shared allowed tools number 18" "$(wc -l < "$T/allowA" | tr -d ' ')" "18"
check "the shared allowed tools keep the original three" "$(grep -cxE 'Bash\(npm test\)|Bash\(npm run \*\)|Bash\(git \*\)' "$T/allowA")" "3"
for c in grep ls find cat head tail wc sort cut echo pwd diff stat basename dirname; do
  check "the shared allowed tools hold Bash($c *) in both arms" "$(grep -cxF "Bash($c *)" "$T/allowA")|$(grep -cxF "Bash($c *)" "$T/allowB")" "1|1"
done
check "no allowed tool names a command that writes, deletes, fetches or runs another" "$(grep -cE '^Bash\((rm|mv|cp|chmod|chown|ln|tee|sed|awk|dd|curl|wget|ssh|scp|nc|xargs|tar|touch|mkdir|sh|bash|env|eval|sudo|node|python3?) ' "$T/allowA")" "0"
check "no deny rule rides the allow list" "$(grep -c "$REPO_PHYS" "$T/allowA")" "0"
check "the shared allowed tools do not hold uniq (uniq IN OUT writes OUT)" "$(grep -c '^Bash(uniq ' "$T/allowA")" "0"
deny_of() { awk '/^--disallowedTools$/ {f = 1; next} /^--/ {f = 0} f' "$1"; }
deny_of "$T/argvA" > "$T/denyA"
deny_of "$T/argvB" > "$T/denyB"
check "both arms pass the same --disallowedTools values" "$(cmp -s "$T/denyA" "$T/denyB" && echo same || echo differ)" "same"
check "the find and sort deny rules number 16" "$(grep -cE '^Bash\((find|sort) ' "$T/denyA")" "16"
check "no find or sort deny rule starts with an unanchored star-dash" "$(grep -cE '^Bash\((find|sort) \*-' "$T/denyA")" "0"
# A rule is modelled as a shell glob: * is any text, spaces and nothing included (OD-17(c); the matcher itself is not run).
hits() {
  local r n=0
  while IFS= read -r r; do
    case "$r" in
      'Bash(find '* | 'Bash(sort '*)
        r="${r#Bash(}"
        r="${r%)}"
        case "$1" in $r) n=$((n + 1)) ;; esac
        ;;
    esac
  done < "$T/denyA"
  echo "$n"
}
for cmd in "sort log-old.txt" "sort -u a.txt" "sort a.txt b.txt" "find . -name x-ok.txt" "find . -name '*-ok*'" "find . -name '*-exec*' -type f" "find src -type f" "find . -name x-delete.txt"; do
  check "no find or sort deny rule matches the read $cmd" "$(hits "$cmd")" "0"
done
for cmd in "find . -exec rm {} ;" "find -exec rm {} ;" "find . -name x -execdir rm {} ;" "find . -ok rm {} ;" "find -okdir rm {} ;" "find . -delete" "find -delete" "find . -fprint out.txt" "find . -fprintf out.txt %p" "find . -fls out.txt" "sort -o out.txt in.txt" "sort in.txt -o out.txt" "sort -oout.txt in.txt" "sort --output=out.txt in.txt" "sort in.txt --output out.txt" "sort --compress-program=sh in.txt"; do
  check "a find or sort deny rule matches the write form $cmd" "$([ "$(hits "$cmd")" -ge 1 ] && echo matched || echo missed)" "matched"
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

check "real home credentials and config untouched" "$(cat "$HOME/.claude/.credentials.json" "$HOME/.claude.json" | sha256sum)" "$HOME_SUM_BEFORE"

echo "abtest-arms: $pass passed, $fail failed"
[ "$fail" -eq 0 ] && echo "All abtest-arms checks passed."
exit "$fail"
