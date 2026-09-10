#!/usr/bin/env bash
# gh416 / C1.2: an ADAPTED project whose .claude/persona-config.json is gone
# must be refused by all six trust gates. Baseline before this unit: every one
# of the six exited 0, i.e. deleting the config disarmed them silently (F1).
# Also pins the two branches this unit must NOT change: an unadapted project is
# still allowed, and a healthy adapted project behaves as before.
set -uo pipefail
cd "$(dirname "$0")/.."
fail=0
GATES="protected-paths reviewed-path-gate task-gate reviewer-route-gate dispatch-hygiene stop-gate"

ok()  { echo "OK   $1"; }
bad() { echo "FAIL $1"; fail=1; }

# An adapted project: agents/*.md plus BOTH directory witnesses, and a config.
mk_adapted() {
  local d; d="$(mktemp -d)"
  mkdir -p "$d/.claude/agents" "$d/.claude/hooks/scripts" "$d/.claude/reviewed"
  printf '# reviewer\n' > "$d/.claude/agents/reviewer.md"
  printf '{"gatedAgents":["lead-programmer"],"dispatchHygiene":{"mode":"off"}}\n' \
    > "$d/.claude/persona-config.json"
  printf '%s' "$d"
}

# Payloads chosen so that, with a healthy config, every gate reaches its own
# allow path: no protected pattern, a benign Bash command, a non-impl task, a
# non-reviewer spawn, hygiene off, and an ungated SubagentStop identity.
payload_for() {
  case "$1" in
    protected-paths)     printf '{"tool_name":"Write","tool_input":{"file_path":"README.md"}}' ;;
    reviewed-path-gate)  printf '{"tool_name":"Bash","tool_input":{"command":"ls"}}' ;;
    task-gate)           printf '{"task":{"subject":"docs: notes","id":"u1"}}' ;;
    reviewer-route-gate) printf '{"agent_type":"orchestrator","tool_input":{"subagent_type":"explorer","prompt":"look"}}' ;;
    dispatch-hygiene)    printf '{"tool_name":"Agent","tool_input":{"subagent_type":"antislop:lead-programmer","prompt":"Unit: u1"}}' ;;
    stop-gate)           printf '{"hook_event_name":"SubagentStop","agent_type":"explorer","agent_id":"a1","session_id":"s1"}' ;;
  esac
}

run_gate() { # <gate> <project_dir> -> writes stderr to $err, echoes rc
  local rc=0
  payload_for "$1" | CLAUDE_PROJECT_DIR="$2" bash "hooks/scripts/$1.sh" \
    >/dev/null 2>"$err" || rc=$?
  printf '%s' "$rc"
}

err="$(mktemp)"

echo "== adapted + config DELETED: all six block with the RD2a message =="
d="$(mk_adapted)"; rm -f "$d/.claude/persona-config.json"
for g in $GATES; do
  rc="$(run_gate "$g" "$d")"
  if [ "$rc" != 2 ]; then
    bad "$g exits 2 on an adapted project with no config (got $rc)"
  elif ! grep -qF 'harness disarmed' "$err"; then
    bad "$g emits the RD2a denial message"
  elif ! grep -qF 'is absent.' "$err"; then
    bad "$g names the config state (absent)"
  else
    ok "$g blocks, config absent"
  fi
done
rm -rf "$d"

echo "== adapted + config EMPTY / UNPARSEABLE: same block, different state =="
for state in empty unparseable; do
  d="$(mk_adapted)"
  case "$state" in
    empty)       : > "$d/.claude/persona-config.json" ;;
    unparseable) printf '{ not json' > "$d/.claude/persona-config.json" ;;
  esac
  rc="$(run_gate stop-gate "$d")"
  if [ "$rc" = 2 ] && grep -qF "is ${state}." "$err"; then
    ok "stop-gate blocks, config $state"
  else
    bad "stop-gate blocks on a $state config (rc=$rc)"
  fi
  rm -rf "$d"
done

echo "== unadapted project: every gate still silently allowed (unchanged) =="
d="$(mktemp -d)"
for g in $GATES; do
  rc="$(run_gate "$g" "$d")"
  if [ "$rc" = 0 ]; then ok "$g allows an unadapted project"
  else bad "$g allows an unadapted project (got $rc)"; fi
done
rm -rf "$d"

echo "== one witness only: not enough to call it tampered =="
for only in agents hooks; do
  d="$(mktemp -d)"
  case "$only" in
    agents) mkdir -p "$d/.claude/agents"; printf '# r\n' > "$d/.claude/agents/reviewer.md" ;;
    hooks)  mkdir -p "$d/.claude/hooks/scripts" "$d/.claude/reviewed" ;;
  esac
  rc="$(run_gate stop-gate "$d")"
  if [ "$rc" = 0 ]; then ok "stop-gate allows a project with only the $only witness"
  else bad "stop-gate allows a project with only the $only witness (got $rc)"; fi
  rm -rf "$d"
done

echo "== healthy adapted project: present-config behaviour untouched =="
d="$(mk_adapted)"
for g in $GATES; do
  rc="$(run_gate "$g" "$d")"
  if [ "$rc" = 0 ]; then ok "$g allows a healthy adapted project"
  else bad "$g allows a healthy adapted project (got $rc)"; fi
done
rm -rf "$d"

echo "== the denial is recorded through audit_append =="
d="$(mk_adapted)"; rm -f "$d/.claude/persona-config.json"
run_gate stop-gate "$d" >/dev/null
if grep -q 'harness-disarmed hook=stop-gate state=absent' "$d/.claude/review-audit.log" 2>/dev/null; then
  ok "stop-gate logs harness-disarmed to review-audit.log"
else
  bad "stop-gate logs harness-disarmed to review-audit.log"
fi
run_gate dispatch-hygiene "$d" >/dev/null
if grep -q 'harness-disarmed hook=dispatch-hygiene state=absent' "$d/.claude/dispatch-audit.log" 2>/dev/null; then
  ok "dispatch-hygiene logs harness-disarmed to its own dispatch-audit.log"
else
  bad "dispatch-hygiene logs harness-disarmed to its own dispatch-audit.log"
fi
rm -rf "$d"

echo "== harness_armed() verdicts, called directly =="
verdict() { # <project_dir> [dot_label]
  local rc=0
  ( set +u; source hooks/scripts/lib/harness-arm.sh
    harness_armed "$1" "${2:-.claude}" ) >/dev/null 2>&1 || rc=$?
  printf '%s' "$rc"
}
d="$(mk_adapted)"
[ "$(verdict "$d")" = 0 ] && ok "harness_armed -> 0 armed" || bad "harness_armed -> 0 armed"
rm -f "$d/.claude/persona-config.json"
[ "$(verdict "$d")" = 2 ] && ok "harness_armed -> 2 tampered" || bad "harness_armed -> 2 tampered"
rm -rf "$d"
d="$(mktemp -d)"
[ "$(verdict "$d")" = 1 ] && ok "harness_armed -> 1 unadapted" || bad "harness_armed -> 1 unadapted"
rm -rf "$d"

# Port-invariance: the same library, pointed at a .codex tree, is what both
# adapter copies rely on (R7 - the ports are byte-identical copies).
d="$(mktemp -d)"
mkdir -p "$d/.codex/agents" "$d/.codex/reviewed"
printf '# r\n' > "$d/.codex/agents/reviewer.md"
[ "$(verdict "$d" .codex)" = 2 ] && ok "harness_armed -> 2 on a .codex tree" \
  || bad "harness_armed -> 2 on a .codex tree"
rm -rf "$d"

echo "== C2: git-index witness - deleting .claude/ is tampered, not unadapted =="
git_c() { git -c user.email=t@t.example -c user.name=t "$@"; }

# A git-tracked adapted project: agents + config committed to the index.
mk_git_tracked() {
  local d; d="$(mktemp -d)"
  ( cd "$d" && git_c init -q &&
    mkdir -p .claude/agents .claude/hooks/scripts &&
    printf '# reviewer\n' > .claude/agents/reviewer.md &&
    printf '{"gatedAgents":["lead-programmer"]}\n' > .claude/persona-config.json &&
    git_c add .claude && git_c commit -q -m init ) >/dev/null 2>&1
  printf '%s' "$d"
}

# PATH with every directory that resolves `git` stripped out, so `git` is
# genuinely unreachable (not just made to fail) - dirname etc. still work.
NO_GIT_PATH=""
IFS=: read -ra _pd <<< "$PATH"
for _d in "${_pd[@]}"; do
  [ -x "$_d/git" ] && continue
  NO_GIT_PATH="${NO_GIT_PATH}:${_d}"
done
NO_GIT_PATH="${NO_GIT_PATH#:}"

# 1: bypass reproduction - config + agents/ deleted from the working tree but
# still in the git index -> tampered (2), not unadapted (1).
d="$(mk_git_tracked)"
rm -rf "$d/.claude/agents" "$d/.claude/persona-config.json"
[ "$(verdict "$d")" = 2 ] && ok "harness_armed -> 2, config+agents deleted but git-tracked" \
  || bad "harness_armed -> 2, config+agents deleted but git-tracked"
rm -rf "$d"

# 2: downstream fail-closed - gates that previously waved this through now
# refuse with the disarmed message.
d="$(mk_git_tracked)"
rm -rf "$d/.claude/agents" "$d/.claude/persona-config.json"
for g in reviewed-path-gate reviewer-route-gate; do
  rc="$(run_gate "$g" "$d")"
  if [ "$rc" = 2 ] && grep -qF 'harness disarmed' "$err"; then
    ok "$g fails closed on a git-tracked-but-deleted config"
  else
    bad "$g fails closed on a git-tracked-but-deleted config (got $rc)"
  fi
done
rm -rf "$d"

# 3: rm -rf .claude end-to-end (config, markers, agents, everything).
d="$(mk_git_tracked)"
rm -rf "$d/.claude"
[ "$(verdict "$d")" = 2 ] && ok "harness_armed -> 2 after rm -rf .claude (git-tracked)" \
  || bad "harness_armed -> 2 after rm -rf .claude (git-tracked)"
rm -rf "$d"

# 4: no false tamper - ls-files failing for any reason means "no witness".
d="$(mktemp -d)"
[ "$(verdict "$d")" = 1 ] && ok "harness_armed -> 1, no .git at all" \
  || bad "harness_armed -> 1, no .git at all"
rm -rf "$d"

d="$(mktemp -d)"
( cd "$d" && git_c init -q && mkdir -p .claude/agents &&
  printf '# r\n' > .claude/agents/reviewer.md ) >/dev/null 2>&1
[ "$(verdict "$d")" = 1 ] && ok "harness_armed -> 1, git repo but config never tracked" \
  || bad "harness_armed -> 1, git repo but config never tracked"
rm -rf "$d"

# The `source` must run BEFORE the PATH swap: the lib resolves its own dir
# with `dirname`, which lives in the same /usr/bin that NO_GIT_PATH strips,
# so sourcing under NO_GIT_PATH aborts the subshell at load time (rc 1) and
# the case would pass without ever calling harness_armed. Swapping after the
# source leaves only `command -v git` inside the witness looking at a
# git-less PATH, which is the thing under test.
d="$(mk_git_tracked)"
rm -rf "$d/.claude/agents" "$d/.claude/persona-config.json"
rc=$( (set +u; source hooks/scripts/lib/harness-arm.sh
       export PATH="$NO_GIT_PATH"
       harness_armed "$d" .claude) >/dev/null 2>&1; echo $? )
[ "$rc" = 1 ] && ok "harness_armed -> 1 when git is not on PATH" \
  || bad "harness_armed -> 1 when git is not on PATH (got $rc)"
rm -rf "$d"

# Residual: the tamper can be *undone* by dropping the config from the index
# as well as the working tree, which takes the last witness away and returns
# the verdict to 1 (unadapted). That is accepted, documented scope, not a
# bug: with no config on disk and no index entry there is nothing left to
# witness that this project was ever adapted, and `git rm --cached` is an
# operator action indistinguishable from never having tracked the file.
d="$(mk_git_tracked)"
rm -rf "$d/.claude/agents" "$d/.claude/persona-config.json"
( cd "$d" && git_c rm -q --cached .claude/persona-config.json ) >/dev/null 2>&1
[ "$(verdict "$d")" = 1 ] && ok "harness_armed -> 1 once the config is git rm --cached" \
  || bad "harness_armed -> 1 once the config is git rm --cached"
rm -rf "$d"

# 5: still armed - a healthy config returns 0 without ever invoking git.
gitshim="$(mktemp -d)"
marker="$gitshim/called"
cat > "$gitshim/git" <<SH
#!/usr/bin/env bash
echo called >> "$marker"
exit 99
SH
chmod +x "$gitshim/git"
d="$(mk_adapted)"
rc=$( (set +u; export PATH="$gitshim:$PATH"; source hooks/scripts/lib/harness-arm.sh
       harness_armed "$d" .claude) >/dev/null 2>&1; echo $? )
if [ "$rc" = 0 ] && [ ! -e "$marker" ]; then
  ok "harness_armed -> 0 for a healthy config, without invoking git"
else
  bad "harness_armed -> 0 for a healthy config, without invoking git (rc=$rc)"
fi
rm -rf "$gitshim" "$d"

rm -f "$err"
exit "$fail"
