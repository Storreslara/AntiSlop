#!/usr/bin/env bash
# Behavioural suite for hooks/scripts/reviewer-tier.sh (Step 5 of
# docs/plans/2026-08-01-efficiency-audit-remediation-pass1.md). Builds a
# throwaway git repo whose commits have exactly known numstat shapes, so the
# 40-line / 3-file boundaries can be pinned on BOTH sides rather than by
# example. CLAUDE_PROJECT_DIR points at the fixture, so the real
# .claude/reviewed/ marker directory is never read or written.
set -euo pipefail
cd "$(dirname "$0")/.."
SCRIPT="$PWD/hooks/scripts/reviewer-tier.sh"
fail=0

tmproot="$(mktemp -d)"
trap 'rm -rf "$tmproot"' EXIT
repo="$tmproot/repo"
mkdir -p "$repo"
git -C "$repo" init -q
git -C "$repo" config user.email tester@example.com
git -C "$repo" config user.name tester
git -C "$repo" config commit.gpgsign false
: > "$repo/README"
git -C "$repo" add -A
git -C "$repo" commit -qm base

snap() {
  # <label> -> commits the current worktree, echoes the range it spans
  git -C "$repo" add -A
  git -C "$repo" commit -qm "$1"
  echo "$(git -C "$repo" rev-parse HEAD~1)..$(git -C "$repo" rev-parse HEAD)"
}

add_commit() {
  # <label> <path:lines>... -> echoes the sha..sha range that commit spans
  local label="$1"; shift
  local pair path lines
  for pair in "$@"; do
    path="${pair%%:*}"
    lines="${pair##*:}"
    mkdir -p "$repo/$(dirname "$path")"
    seq 1 "$lines" > "$repo/$path"
  done
  snap "$label"
}

run_case() {
  # <label> <expected> <task-id> <range> [script-under-test]
  local label="$1" expected="$2" tid="$3" range="$4" script="${5:-$SCRIPT}"
  local got rc=0
  got="$(cd "$repo" && CLAUDE_PROJECT_DIR="$repo" bash "$script" "$tid" "$range" 2>/dev/null)" || rc=$?
  if [ "$rc" = 0 ] && [ "$got" = "$expected" ]; then
    echo "OK   $label -> $expected"
  else
    echo "FAIL $label expected '$expected', got '$got' (rc=$rc)"
    fail=1
  fi
}

r_small=$(add_commit small docs/small.md:5)
r_hooks=$(add_commit hooksdir hooks/scripts/probe.sh:5)
r_l39=$(add_commit l39 docs/l39.md:39)
r_l40=$(add_commit l40 docs/l40.md:40)
r_l41=$(add_commit l41 docs/l41.md:41)
r_f2=$(add_commit f2 docs/f2a.md:1 docs/f2b.md:1)
r_f3=$(add_commit f3 docs/f3a.md:1 docs/f3b.md:1 docs/f3c.md:1)
r_f4=$(add_commit f4 docs/f4a.md:1 docs/f4b.md:1 docs/f4c.md:1 docs/f4d.md:1)

# Markers are seeded only after every commit, so they stay untracked and
# cannot perturb any range's numstat.
mkdir -p "$repo/.claude/reviewed"
printf 'FAIL unit-fail 2026-08-01T00:00:00Z missing: constraint X\n' \
  > "$repo/.claude/reviewed/unit-fail.fail"
printf 'PASS unit-pass 2026-08-01T00:00:00Z criteria: true\n' \
  > "$repo/.claude/reviewed/unit-pass.pass"

echo "-- required cases --"
run_case "(a) under-threshold non-sensitive diff"      sonnet unit-1     "$r_small"
run_case "(b) under-threshold diff touching hooks/"    opus   unit-1     "$r_hooks"
run_case "(c) over-line-threshold diff"                opus   unit-1     "$r_l41"
run_case "(d) over-file-threshold diff"                opus   unit-1     "$r_f4"
run_case "(e) empty range"                             opus   unit-1     ""
run_case "(f) malformed range (unresolvable revs)"     opus   unit-1     "no-such-a..no-such-b"
run_case "(g) malformed range (leading dash)"          opus   unit-1     "--output=/dev/null"
run_case "(h) unit with an existing FAIL record"       opus   unit-fail  "$r_small"
run_case "(i) a PASS record is not a disqualifier"     sonnet unit-pass  "$r_small"

echo "-- boundary sweep: MAX_CHANGED_LINES=40 --"
run_case "(j) 39 changed lines (below the limit)"      sonnet unit-1     "$r_l39"
run_case "(k) 40 changed lines (at the limit)"         sonnet unit-1     "$r_l40"
run_case "(l) 41 changed lines (above the limit)"      opus   unit-1     "$r_l41"

echo "-- boundary sweep: MAX_CHANGED_FILES=3 --"
run_case "(m) 2 changed files (below the limit)"       sonnet unit-1     "$r_f2"
run_case "(n) 3 changed files (at the limit)"          sonnet unit-1     "$r_f3"
run_case "(o) 4 changed files (above the limit)"       opus   unit-1     "$r_f4"

echo "-- sensitive path classes: one case per pattern --"
run_case "(p) ^hooks/"                        opus   unit-1 "$(add_commit p1 hooks/hooks.json:1)"
run_case "(q) ^\.claude/hooks/"               opus   unit-1 "$(add_commit p2 .claude/hooks/x.sh:1)"
run_case "(r) ^adapters/.*hooks"              opus   unit-1 "$(add_commit p3 adapters/codex/hooks/hooks.json:1)"
run_case "(s) ^bin/cli\.js\$"                 opus   unit-1 "$(add_commit p4 bin/cli.js:1)"
run_case "(t) ^tests/validate\.sh\$"          opus   unit-1 "$(add_commit p5 tests/validate.sh:1)"
run_case "(u) ^templates/persona-protocol.*\.md\$" opus unit-1 "$(add_commit p6 templates/persona-protocol-slim.md:1)"
run_case "(v) ^templates/settings-fragment\.json\$" opus unit-1 "$(add_commit p7 templates/settings-fragment.json:1)"
run_case "(w) ^\.claude/settings.*\.json\$"   opus   unit-1 "$(add_commit p8 .claude/settings.local.json:1)"
run_case "(x) ^\.claude-plugin/"              opus   unit-1 "$(add_commit p9 .claude-plugin/plugin.json:1)"

echo "-- near misses: the anchors must not over-match --"
run_case "(y) docs/hooks/ is not ^hooks/"     sonnet unit-1 "$(add_commit n1 docs/hooks/notes.md:1)"
run_case "(z) bin/cli.js.bak is not ^bin/cli\.js\$" sonnet unit-1 "$(add_commit n2 bin/cli.js.bak:1)"
run_case "(aa) tests/validate.sh.orig is not ^tests/validate\.sh\$" sonnet unit-1 "$(add_commit n3 tests/validate.sh.orig:1)"
run_case "(ab) a persona-protocol .md.txt does not end in .md" sonnet unit-1 "$(add_commit n4 templates/persona-protocol.md.txt:1)"

# The anchors are matched against whatever `git diff --numstat` prints, so any
# path shape git rewrites (rename compaction, C-quoting) can slip a sensitive
# path past them. These assert the anchors do not UNDER-match.
echo "-- numstat path shapes --"
git -C "$repo" mv docs/small.md hooks/scripts/moved.md
r_rename=$(snap rename-into-hooks)
run_case "(ac) a file renamed into hooks/"    opus   unit-1 "$r_rename"

printf 'x\n' > "$repo/hooks/scripts/café.sh"
r_utf8=$(snap utf8-path)
run_case "(ad) a non-ASCII path under hooks/" opus   unit-1 "$r_utf8"

printf 'x\n' > "$repo/hooks/scripts/we\"ird.sh"
r_quoted=$(snap quoted-path)
run_case "(ae) a path git C-quotes anyway"    opus   unit-1 "$r_quoted"

# The mirror of (ad): quotepath=false is what makes a non-ASCII path readable
# at all, so a benign one stays measurable instead of tripping the quote guard.
printf 'x\n' > "$repo/docs/café.md"
r_utf8_ok=$(snap utf8-path-benign)
run_case "(af) a non-ASCII path outside the sensitive set" sonnet unit-1 "$r_utf8_ok"

# The header claims anything unmeasurable prints opus; a range that resolves
# but measures nothing, and a missing task id, are both unmeasurable.
echo "-- fail-closed edges --"
run_case "(ag) a valid range with zero changed files" opus unit-1 "HEAD..HEAD"
run_case "(ah) an empty task id"                      opus ""     "$r_small"

# --- Mutation controls (acceptance criterion 4) ---------------------------
# reviewer-tier.sh sources nothing, so a plain copy is a complete runnable
# mutant - no lib/ sibling to carry along. Each control asserts the named case
# FLIPS under the mutation, which is what proves the assertion binds to that
# code path (and, for the constants, to the exact value rather than to the
# direction).
MUTANT=""
mutate() {
  # <name> <sed-expr>: writes the mutant to $MUTANT, fails loudly if the sed
  # matched nothing (a silently-unmutated copy would "prove" anything).
  MUTANT="$tmproot/$1.sh"
  sed "$2" "$SCRIPT" > "$MUTANT"
  if cmp -s "$MUTANT" "$SCRIPT"; then
    echo "FAIL mutation control '$1': the sed matched nothing"
    fail=1
    return 1
  fi
  return 0
}

echo "-- mutation controls --"
if mutate invert-sensitive 's/if touches_sensitive_path/if ! touches_sensitive_path/'; then
  run_case "(mc1) sensitive-path check inverted: case (b) flips to" \
    sonnet unit-1 "$r_hooks" "$MUTANT"
fi
if mutate lines-41 's/^MAX_CHANGED_LINES=40$/MAX_CHANGED_LINES=41/'; then
  run_case "(mc2) MAX_CHANGED_LINES 40->41: case (l) flips to" \
    sonnet unit-1 "$r_l41" "$MUTANT"
fi
if mutate files-4 's/^MAX_CHANGED_FILES=3$/MAX_CHANGED_FILES=4/'; then
  run_case "(mc3) MAX_CHANGED_FILES 3->4: case (o) flips to" \
    sonnet unit-1 "$r_f4" "$MUTANT"
fi
if mutate renames-on 's/ --no-renames//'; then
  run_case "(mc4) rename detection re-enabled: case (ac) flips to" \
    sonnet unit-1 "$r_rename" "$MUTANT"
fi
if mutate quotepath-on 's/-c core\.quotepath=false //'; then
  run_case "(mc5) path quoting re-enabled: case (af) flips to" \
    opus unit-1 "$r_utf8_ok" "$MUTANT"
fi
if mutate quote-guard-off "/in '\"'/d"; then
  run_case "(mc6) C-quoted-path guard removed: case (ae) flips to" \
    sonnet unit-1 "$r_quoted" "$MUTANT"
fi
if mutate empty-range-ok '/\[ "\$files" -gt 0 \]/d'; then
  run_case "(mc7) zero-file guard removed: case (ag) flips to" \
    sonnet unit-1 "HEAD..HEAD" "$MUTANT"
fi
if mutate empty-id-ok '/\[ -n "\$task_id" \]/d'; then
  run_case "(mc8) empty-task-id guard removed: case (ah) flips to" \
    sonnet "" "$r_small" "$MUTANT"
fi

exit "$fail"
