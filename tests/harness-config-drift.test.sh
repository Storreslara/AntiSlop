#!/usr/bin/env bash
# Fixture suite for bin/harness-integrity.sh's disarm-surface config-drift
# comparison (Step 4) and its --session-start wiring (C4.4). Each case is a
# real throwaway git repo: a "baseline" commit holding one shape of
# .claude/persona-config.json, then a working-tree (and sometimes committed)
# edit, compared against the baseline sha via `git show`.
set -euo pipefail
cd "$(dirname "$0")/.."
fail=0

tmproot="$(mktemp -d)"
trap 'rm -rf "$tmproot"' EXIT

ok()  { echo "OK   $1"; }
bad() { echo "FAIL $1"; fail=1; }

# make_repo <name> <json> -> commits <json> as .claude/persona-config.json in
# a fresh repo under $tmproot/<name>; echoes "<dir> <sha>".
make_repo() {
  local dir="$tmproot/$1"
  mkdir -p "$dir/.claude"
  printf '%s' "$2" > "$dir/.claude/persona-config.json"
  git -C "$dir" init -q
  git -C "$dir" -c user.email=t@example.com -c user.name=t add -A
  git -C "$dir" -c user.email=t@example.com -c user.name=t commit -q -m baseline
  echo "$dir $(git -C "$dir" rev-parse HEAD)"
}

if [ "${1:-}" = "--session-start" ]; then
  # C4.4: session-start.sh reports drift, naming the drifted field, and
  # never blocks (exit 0 either way).
  read -r dir sha < <(make_repo t-session '{"gatedAgents":["lead-programmer"]}')
  printf '{"gatedAgents":[]}' > "$dir/.claude/persona-config.json"
  printf '%s\n' "$sha" > "$dir/.claude/.session-baseline.sess1"
  rc=0
  output=$(printf '%s' '{"hook_event_name":"SessionStart","session_id":"sess1","source":"startup"}' \
    | CLAUDE_PROJECT_DIR="$dir" bash hooks/scripts/session-start.sh || rc=$?)
  ctx="$(echo "$output" | jq -r '.hookSpecificOutput.additionalContext // empty' 2>/dev/null || true)"
  if [ "$rc" = 0 ] && echo "$ctx" | grep -qi 'drift' && echo "$ctx" | grep -q 'gatedAgents'; then
    ok "C4.4 session-start.sh reports config drift naming gatedAgents, exit 0 (never blocks)"
  else
    bad "C4.4 expected a drift report naming gatedAgents (rc=$rc output=$output)"
  fi

  # C4.4 negative: no drift -> no drift line
  read -r dir sha < <(make_repo t-session-clean '{"gatedAgents":["lead-programmer"]}')
  printf '%s\n' "$sha" > "$dir/.claude/.session-baseline.sess2"
  rc=0
  output=$(printf '%s' '{"hook_event_name":"SessionStart","session_id":"sess2","source":"startup"}' \
    | CLAUDE_PROJECT_DIR="$dir" bash hooks/scripts/session-start.sh || rc=$?)
  ctx="$(echo "$output" | jq -r '.hookSpecificOutput.additionalContext // empty' 2>/dev/null || true)"
  if [ "$rc" = 0 ] && ! echo "$ctx" | grep -qi 'drift'; then
    ok "C4.4 negative: unchanged config never mentions drift in additionalContext"
  else
    bad "C4.4 negative expected no drift mention (rc=$rc output=$output)"
  fi

  exit "$fail"
fi

# ---- C4.1/C4.2: bin/harness-integrity.sh's config-drift comparison --------

# T1 GUARD: working tree == baseline -> config=ok
read -r dir sha < <(make_repo t1 '{"gatedAgents":["lead-programmer"]}')
out="$(bash bin/harness-integrity.sh "$dir" "$sha")"
if echo "$out" | grep -q ' config=ok '; then
  ok "T1 GUARD: working tree identical to baseline -> config=ok"
else
  bad "T1 expected config=ok, got: $out"
fi

# T2: gatedAgents [] vs baseline ["lead-programmer"] -> drift fields=gatedAgents
read -r dir sha < <(make_repo t2 '{"gatedAgents":["lead-programmer"]}')
printf '{"gatedAgents":[]}' > "$dir/.claude/persona-config.json"
out="$(bash bin/harness-integrity.sh "$dir" "$sha")"
if echo "$out" | grep -q ' config=drift ' && echo "$out" | grep -q 'fields=gatedAgents'; then
  ok "T2 gatedAgents weakened to [] registers as drift"
else
  bad "T2 expected config=drift fields=gatedAgents, got: $out"
fi

# T3: dispatchHygiene.mode "off" vs "warn" -> drift fields=dispatchHygiene.mode
read -r dir sha < <(make_repo t3 '{"dispatchHygiene":{"mode":"warn"}}')
printf '{"dispatchHygiene":{"mode":"off"}}' > "$dir/.claude/persona-config.json"
out="$(bash bin/harness-integrity.sh "$dir" "$sha")"
if echo "$out" | grep -q ' config=drift ' && echo "$out" | grep -q 'fields=dispatchHygiene.mode'; then
  ok "T3 dispatchHygiene.mode weakened warn -> off registers as drift"
else
  bad "T3 expected config=drift fields=dispatchHygiene.mode, got: $out"
fi

# T4: protectedPaths [] vs a non-empty baseline -> drift fields=protectedPaths
read -r dir sha < <(make_repo t4 '{"protectedPaths":[{"pattern":"a"}]}')
printf '{"protectedPaths":[]}' > "$dir/.claude/persona-config.json"
out="$(bash bin/harness-integrity.sh "$dir" "$sha")"
if echo "$out" | grep -q ' config=drift ' && echo "$out" | grep -q 'fields=protectedPaths'; then
  ok "T4 protectedPaths emptied registers as drift"
else
  bad "T4 expected config=drift fields=protectedPaths, got: $out"
fi

# T5: THE SPEC-6 CASE - reviewGating absent in baseline, "off" in tree -> drift.
# Absent normalizes to "enforce" (D6/A24b); a present-keys-only comparison
# would miss this transition entirely.
read -r dir sha < <(make_repo t5 '{}')
printf '{"reviewGating":{"mode":"off"}}' > "$dir/.claude/persona-config.json"
out="$(bash bin/harness-integrity.sh "$dir" "$sha")"
if echo "$out" | grep -q ' config=drift ' && echo "$out" | grep -q 'fields=reviewGating.mode'; then
  ok "T5 SPEC-6 CASE: reviewGating absent(->enforce) to off registers as drift"
else
  bad "T5 expected config=drift fields=reviewGating.mode, got: $out"
fi

# T6 GUARD: reviewGating absent in BOTH -> config=ok
read -r dir sha < <(make_repo t6 '{}')
out="$(bash bin/harness-integrity.sh "$dir" "$sha")"
if echo "$out" | grep -q ' config=ok '; then
  ok "T6 GUARD: reviewGating absent in both baseline and tree -> config=ok"
else
  bad "T6 expected config=ok, got: $out"
fi

# T7 GUARD: reviewGating "enforce" in tree, absent in baseline -> config=ok
# (same effective value, NOT a weakening).
read -r dir sha < <(make_repo t7 '{}')
printf '{"reviewGating":{"mode":"enforce"}}' > "$dir/.claude/persona-config.json"
out="$(bash bin/harness-integrity.sh "$dir" "$sha")"
if echo "$out" | grep -q ' config=ok '; then
  ok "T7 GUARD: explicit reviewGating.mode=enforce vs absent-baseline is the same effective value -> config=ok"
else
  bad "T7 expected config=ok (same effective value), got: $out"
fi

# T8: config file deleted -> config=missing
read -r dir sha < <(make_repo t8 '{"gatedAgents":["lead-programmer"]}')
rm -f "$dir/.claude/persona-config.json"
out="$(bash bin/harness-integrity.sh "$dir" "$sha")"
if echo "$out" | grep -q ' config=missing '; then
  ok "T8 deleted config file -> config=missing"
else
  bad "T8 expected config=missing, got: $out"
fi

# T9 GUARD: fileHashes rewritten, everything else equal -> config=ok
read -r dir sha < <(make_repo t9 '{"gatedAgents":["lead-programmer"],"fileHashes":{"a":"1"}}')
printf '{"gatedAgents":["lead-programmer"],"fileHashes":{"a":"2","b":"3"}}' \
  > "$dir/.claude/persona-config.json"
out="$(bash bin/harness-integrity.sh "$dir" "$sha")"
if echo "$out" | grep -q ' config=ok '; then
  ok "T9 GUARD: fileHashes-only rewrite is excluded from the disarm surface -> config=ok"
else
  bad "T9 expected config=ok (fileHashes excluded), got: $out"
fi

# T10 GUARD: a drift COMMITTED mid-session (baseline sha still the older one)
# must NOT report ok - committing the weakening does not hide it.
read -r dir sha < <(make_repo t10 '{"gatedAgents":["lead-programmer"]}')
printf '{"gatedAgents":[]}' > "$dir/.claude/persona-config.json"
git -C "$dir" -c user.email=t@example.com -c user.name=t add -A
git -C "$dir" -c user.email=t@example.com -c user.name=t commit -q -m weaken
out="$(bash bin/harness-integrity.sh "$dir" "$sha")"
if echo "$out" | grep -q ' config=drift '; then
  ok "T10 GUARD: committing the weakening does not hide it from the older baseline sha"
else
  bad "T10 expected config=drift even after committing the weakening, got: $out"
fi

# ---- remaining disarm-surface fields, for completeness of all nine --------

# T11: personaSelection weakened (reviewer removed)
read -r dir sha < <(make_repo t11 '{"personaSelection":["reviewer"]}')
printf '{"personaSelection":[]}' > "$dir/.claude/persona-config.json"
out="$(bash bin/harness-integrity.sh "$dir" "$sha")"
if echo "$out" | grep -q ' config=drift ' && echo "$out" | grep -q 'fields=personaSelection'; then
  ok "T11 personaSelection weakened (reviewer removed) registers as drift"
else
  bad "T11 expected config=drift fields=personaSelection, got: $out"
fi

# T12: dispatchHygiene.requireContract true -> false (must not be swallowed by
# jq's `//`, which treats false the same as absent)
read -r dir sha < <(make_repo t12 '{"dispatchHygiene":{"requireContract":true}}')
printf '{"dispatchHygiene":{"requireContract":false}}' > "$dir/.claude/persona-config.json"
out="$(bash bin/harness-integrity.sh "$dir" "$sha")"
if echo "$out" | grep -q ' config=drift ' && echo "$out" | grep -q 'fields=dispatchHygiene.requireContract'; then
  ok "T12 dispatchHygiene.requireContract weakened true -> false registers as drift"
else
  bad "T12 expected config=drift fields=dispatchHygiene.requireContract, got: $out"
fi

# T13 GUARD: requireContract absent in both -> config=ok (default true both sides)
read -r dir sha < <(make_repo t13 '{}')
out="$(bash bin/harness-integrity.sh "$dir" "$sha")"
if echo "$out" | grep -q ' config=ok '; then
  ok "T13 GUARD: dispatchHygiene.requireContract absent in both -> config=ok"
else
  bad "T13 expected config=ok, got: $out"
fi

# T14: markerCommitCheck.mode weakened block -> off
read -r dir sha < <(make_repo t14 '{"markerCommitCheck":{"mode":"block"}}')
printf '{"markerCommitCheck":{"mode":"off"}}' > "$dir/.claude/persona-config.json"
out="$(bash bin/harness-integrity.sh "$dir" "$sha")"
if echo "$out" | grep -q ' config=drift ' && echo "$out" | grep -q 'fields=markerCommitCheck.mode'; then
  ok "T14 markerCommitCheck.mode weakened block -> off registers as drift"
else
  bad "T14 expected config=drift fields=markerCommitCheck.mode, got: $out"
fi

# T15: humanReviewMode weakened critical -> off
read -r dir sha < <(make_repo t15 '{"humanReviewMode":"critical"}')
printf '{"humanReviewMode":"off"}' > "$dir/.claude/persona-config.json"
out="$(bash bin/harness-integrity.sh "$dir" "$sha")"
if echo "$out" | grep -q ' config=drift ' && echo "$out" | grep -q 'fields=humanReviewMode'; then
  ok "T15 humanReviewMode weakened critical -> off registers as drift"
else
  bad "T15 expected config=drift fields=humanReviewMode, got: $out"
fi

# T16: testAndLintCommand weakened to empty
read -r dir sha < <(make_repo t16 '{"testAndLintCommand":"bash tests/validate.sh"}')
printf '{"testAndLintCommand":""}' > "$dir/.claude/persona-config.json"
out="$(bash bin/harness-integrity.sh "$dir" "$sha")"
if echo "$out" | grep -q ' config=drift ' && echo "$out" | grep -q 'fields=testAndLintCommand'; then
  ok "T16 testAndLintCommand weakened to empty registers as drift"
else
  bad "T16 expected config=drift fields=testAndLintCommand, got: $out"
fi

# T17: multiple simultaneously drifted fields are all named
read -r dir sha < <(make_repo t17 '{"gatedAgents":["lead-programmer"],"humanReviewMode":"critical"}')
printf '{"gatedAgents":[],"humanReviewMode":"off"}' > "$dir/.claude/persona-config.json"
out="$(bash bin/harness-integrity.sh "$dir" "$sha")"
if echo "$out" | grep -q ' config=drift ' \
   && echo "$out" | grep -qE 'fields=[^ ]*gatedAgents' \
   && echo "$out" | grep -qE 'fields=[^ ]*humanReviewMode'; then
  ok "T17 multiple simultaneously drifted fields are all named"
else
  bad "T17 expected both gatedAgents and humanReviewMode named, got: $out"
fi

# T18: an unresolvable baseline sha (no git repo / bad sha) must not falsely
# report drift and must still exit 0 - nothing can be compared, so it fails
# toward config=ok rather than crashing or fabricating a verdict.
dir="$tmproot/t18"
mkdir -p "$dir/.claude"
printf '{"gatedAgents":["lead-programmer"]}' > "$dir/.claude/persona-config.json"
rc=0
out="$(bash bin/harness-integrity.sh "$dir" deadbeef)" || rc=$?
if [ "$rc" = 0 ] && echo "$out" | grep -q ' config=ok '; then
  ok "T18 unresolvable baseline sha does not falsely report drift, exits 0"
else
  bad "T18 expected config=ok and exit 0 with unresolvable baseline, got rc=$rc out=$out"
fi

# T19 MUTATION PROOF: T5 and T7 (the two load-bearing spec-6 GUARD/drift
# cases) must depend on the absent-key default actually being "enforce" -
# not on something already true. A mutant that defaults absent reviewGating
# to "off" instead must flip BOTH: T5's drift becomes a false config=ok, and
# T7's GUARD becomes a false config=drift.
mkdir -p "$tmproot/mutant-root/bin"
ln -s "$PWD/hooks" "$tmproot/mutant-root/hooks"
mutant="$tmproot/mutant-root/bin/harness-integrity.sh"
cp bin/harness-integrity.sh "$mutant"
needle='// "enforce"'
before_n="$(grep -cF "$needle" "$mutant" || true)"
sed -i 's/\/\/ "enforce"/\/\/ "off"/' "$mutant"
after_n="$(grep -cF "$needle" "$mutant" || true)"

read -r dir sha < <(make_repo t19a '{}')
printf '{"reviewGating":{"mode":"off"}}' > "$dir/.claude/persona-config.json"
mut_out_t5="$(bash "$mutant" "$dir" "$sha")"

read -r dir sha < <(make_repo t19b '{}')
printf '{"reviewGating":{"mode":"enforce"}}' > "$dir/.claude/persona-config.json"
mut_out_t7="$(bash "$mutant" "$dir" "$sha")"

if [ "${before_n:-0}" = 1 ] && [ "${after_n:-0}" = 0 ] \
   && echo "$mut_out_t5" | grep -q ' config=ok ' \
   && echo "$mut_out_t7" | grep -q ' config=drift '; then
  ok "T19 mutation proof: a wrong absent-key default flips T5 to a false config=ok AND T7 to a false config=drift"
else
  bad "T19 mutation not applied or did not flip both cases (before=$before_n after=$after_n t5=$mut_out_t5 t7=$mut_out_t7)"
fi

exit "$fail"
