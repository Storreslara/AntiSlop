Unit: st-u1

## Objective
Two shared hook libraries for the structural stage's mechanised pre-review (spec Step 1, variation f):
- `hooks/scripts/lib/sensitive-paths.sh`: reviewer-tier.sh's `SENSITIVE_PATHS` array and
  `touches_sensitive_path`, moved byte for byte. reviewer-tier.sh sources it, so the class has one
  definition that `review-precheck.sh` (st-u2) and `unit-size.sh` (st-u4) reuse without drift.
- `hooks/scripts/lib/unit-scope.sh`: unit-scope classification (`us_section`, `us_entries`, `us_listed`,
  `us_named_in`, `us_plugin_version`, `us_version_name`, `us_classify`). It renders aof-u3b's standing
  exceptions as seven classes: `listed`, `criteria`, `fail-record`, `fix-contract`, `plugin-version`,
  `judge` and `out`. st-u2 and st-u3 use it, so the precheck and the scope gate cannot disagree.

reviewer-tier.sh's behaviour does not change: the same 11 patterns, the same 63 checks. Its mutation control
mc13 now mutates the library copy. Both libraries are Claude-only (the adapters have no reviewer-tier.sh).

## Retrieval
Fast path, no tracker issue. Spec: `docs/plans/antislop-structural/spec.md`, "Step 1 (st-u1)" and "Context,
f". This file is the contract of record. Dispatch it only after qw-u6 has reached PASS (its validate.sh
block is this unit's anchor).

## Affected files
- `tests/scope-libs.test.sh` (anchor: new file, mode 755)
- `hooks/scripts/lib/sensitive-paths.sh` (anchor: new file, mode 644)
- `hooks/scripts/lib/unit-scope.sh` (anchor: new file, mode 644)
- `hooks/scripts/reviewer-tier.sh` (anchors: line matching `# Size alone is unsafe: measured over the last 50 commits, three small diffs`; line matching `. "$(dirname "${BASH_SOURCE[0]}")/lib/state-access.sh"`)
- `tests/reviewer-tier.test.sh` (anchor: line matching `if mutate no-agents-anchor`)
- `bin/cli.js` (anchor: line matching `const CLAUDE_ONLY_HOOK_LIB_FILES = [`)
- `tests/validate.sh` (anchor: line matching `echo "== orchestrator-model: sonnet by default, orchestratorModel opt-out (Node, qw-u6) =="`)
- `.claude-plugin/plugin.json`, `package.json`, `CHANGELOG.md`
- generated only, by `node bin/cli.js --update`: `.claude/hooks/scripts/lib/sensitive-paths.sh`, `.claude/hooks/scripts/lib/unit-scope.sh`, `.claude/hooks/scripts/reviewer-tier.sh`, the config's `fileHashes` and `pluginVersion`

## Ordered edits
1. file: `tests/scope-libs.test.sh`
   anchor: new file (mode 755)
   indent: 0
   insert-after:
~~~
#!/usr/bin/env bash
# scope-libs (st-u1): hooks/scripts/lib/sensitive-paths.sh (the reviewer-tier
# sensitive-path class, moved out of reviewer-tier.sh unchanged) and
# hooks/scripts/lib/unit-scope.sh (unit-scope classification). Temp repos only.
set -uo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
fail=0
ok()  { echo "OK   $*"; }
bad() { echo "FAIL $*"; fail=1; }
. "$ROOT/hooks/scripts/lib/sensitive-paths.sh"
. "$ROOT/hooks/scripts/lib/unit-scope.sh"
T="$(mktemp -d)"; trap 'rm -rf "$T"' EXIT

# (a) the class is the one reviewer-tier.sh used: 11 patterns, same members.
[ "${#SENSITIVE_PATHS[@]}" = 11 ] && ok "(a) 11 patterns" || bad "(a) pattern count ${#SENSITIVE_PATHS[@]}"
for p in hooks/x.sh .claude/hooks/scripts/y.sh adapters/codex/hooks/z.sh bin/cli.js tests/validate.sh \
         templates/persona-protocol.md templates/settings-fragment.json .claude/settings.local.json \
         .claude-plugin/plugin.json agents/reviewer.md .claude/agents/reviewer.md; do
  touches_sensitive_path "$p" && ok "(a) sensitive $p" || bad "(a) not sensitive: $p"
done
for p in src/store.js tests/store.test.js bin/cli.jsx docs/hooks.md README.md; do
  touches_sensitive_path "$p" && bad "(a) wrongly sensitive: $p" || ok "(a) not sensitive $p"
done
# (b) reviewer-tier.sh no longer defines the class itself and sources the lib.
grep -q '^SENSITIVE_PATHS=(' "$ROOT/hooks/scripts/reviewer-tier.sh" && bad "(b) reviewer-tier.sh still defines SENSITIVE_PATHS" || ok "(b) class defined once"
grep -qxF '. "$(dirname "${BASH_SOURCE[0]}")/lib/sensitive-paths.sh"' "$ROOT/hooks/scripts/reviewer-tier.sh" && ok "(b) reviewer-tier.sh sources the lib" || bad "(b) source line missing"

# (c) us_section / us_entries read only the named section, outside fences.
cat > "$T/c.md" << 'MD'
Unit: u1

## Objective
`not/this.js`

## Affected files
- `src/store.js` (anchor: line matching `const x = [`)
- `test`
- `.claude-plugin/plugin.json`, `package.json`
- generated only, by `node bin/cli.js --update`: `.claude/agents/*.md`
```
## Acceptance criteria
- `fenced/away.js`
```
- `docs/*.md`

## Acceptance criteria
1. run: `bash tests/a.test.sh src/named.js`
MD
us_entries "$T/c.md" > "$T/e.txt"
for e in src/store.js .claude-plugin/plugin.json package.json '.claude/agents/*.md' 'docs/*.md'; do
  grep -qxF -- "$e" "$T/e.txt" && ok "(c) entry $e" || bad "(c) missing entry $e"
done
grep -qxF 'not/this.js' "$T/e.txt" && bad "(c) entry from another section" || ok "(c) other sections ignored"
grep -qxF 'fenced/away.js' "$T/e.txt" && bad "(c) fenced line taken" || ok "(c) fenced lines skipped"
grep -qxF 'test' "$T/e.txt" && bad "(c) token with no / or . taken" || ok "(c) bare word skipped"
grep -q 'node bin/cli.js' "$T/e.txt" && bad "(c) command token taken" || ok "(c) command with spaces skipped"
[ "$(us_section "$T/c.md" "Acceptance criteria" | grep -c 'run:')" = 1 ] && ok "(c) real criteria section found once" || bad "(c) criteria section"

# (d) us_listed: exact, directory prefix, glob; never a sibling prefix.
printf 'src/store.js\ntest/\ndocs/*.md\n' > "$T/l.txt"
us_listed src/store.js "$T/l.txt" && ok "(d) exact" || bad "(d) exact"
us_listed test/unit/a.test.js "$T/l.txt" && ok "(d) directory prefix" || bad "(d) directory prefix"
us_listed docs/guide.md "$T/l.txt" && ok "(d) glob" || bad "(d) glob"
us_listed src/store.json "$T/l.txt" && bad "(d) sibling prefix matched" || ok "(d) no sibling prefix"
us_listed testing/x.js "$T/l.txt" && bad "(d) directory sibling matched" || ok "(d) no directory sibling"
us_listed src/store.js /dev/null && bad "(d) empty list matched" || ok "(d) empty list matches nothing"

# (e) us_named_in: whole path tokens only.
printf 'bash tests/a.test.sh src/named.js; cmp bin/x.sh .claude/bin/x.sh\n' > "$T/r.txt"
us_named_in src/named.js "$T/r.txt" && ok "(e) named" || bad "(e) named"
us_named_in bin/x.sh "$T/r.txt" && ok "(e) named before a space" || bad "(e) named before a space"
us_named_in named.js "$T/r.txt" && bad "(e) suffix of a path matched" || ok "(e) suffix not matched"
us_named_in src/named.j "$T/r.txt" && bad "(e) prefix of a path matched" || ok "(e) prefix not matched"

# (f) us_classify order and the two version classes.
cd "$T" || exit 1
g() { git -c user.email=t@t -c user.name=t "$@"; }
git init -q p && cd p && g commit -q --allow-empty -m base && R0="$(git rev-parse HEAD)"
mkdir -p .claude-plugin && echo '{}' > .claude-plugin/plugin.json && git add -A && g commit -q -m plugin && R1="$(git rev-parse HEAD)"
printf 'FAIL u1 2026-10-20T00:00:00Z\ntier: sonnet\n- lib/fixed.js:3 off by one\n' > "$T/f.txt"
printf 'src/fix.js\n' > "$T/x.txt"
[ "$(us_classify src/store.js "$R1" "$T/l.txt" /dev/null "$T/r.txt" "$T/f.txt")" = listed ] && ok "(f) listed" || bad "(f) listed"
[ "$(us_classify src/named.js "$R1" "$T/l.txt" /dev/null "$T/r.txt" "$T/f.txt")" = criteria ] && ok "(f) criteria" || bad "(f) criteria"
[ "$(us_classify lib/fixed.js "$R1" "$T/l.txt" /dev/null "$T/r.txt" "$T/f.txt")" = fail-record ] && ok "(f) fail-record" || bad "(f) fail-record"
[ "$(us_classify src/fix.js "$R1" "$T/l.txt" "$T/x.txt" /dev/null /dev/null)" = fix-contract ] && ok "(f) fix-contract" || bad "(f) fix-contract"
[ "$(us_classify package.json "$R1" /dev/null /dev/null /dev/null /dev/null)" = plugin-version ] && ok "(f) plugin-version in the plugin layout" || bad "(f) plugin-version"
[ "$(us_classify package.json "$R0" /dev/null /dev/null /dev/null /dev/null)" = judge ] && ok "(f) judge outside the plugin layout" || bad "(f) judge"
[ "$(us_classify CONTEXT.md "$R1" "$T/l.txt" /dev/null "$T/r.txt" "$T/f.txt")" = out ] && ok "(f) out" || bad "(f) out"

exit "$fail"
~~~
2. command: `bash tests/scope-libs.test.sh`
   expect: 1
   The red step: neither library exists yet.
3. file: `hooks/scripts/lib/sensitive-paths.sh`
   anchor: new file (mode 644)
   indent: 0
   insert-after:
~~~
# sensitive-paths.sh (st-u1): the reviewer-tier sensitive-path class, sourced by
# reviewer-tier.sh, unit-size.sh and review-precheck.sh so the three never drift.
# Sourced, never executed (mode 644). Defines SENSITIVE_PATHS and
# touches_sensitive_path <path> (exit 0 when the path is in the class).

# Size alone is unsafe: measured over the last 50 commits, three small diffs
# (1f 28L, 2f 41L, 1f 25L) were security/logic-critical. Size is therefore
# conjunctive with this path-class exclusion, which is never optional.
SENSITIVE_PATHS=(
  '^hooks/'
  '^\.claude/hooks/'
  '^adapters/.*hooks'
  '^bin/cli\.js$'
  '^tests/validate\.sh$'
  '^templates/persona-protocol.*\.md$'
  '^templates/settings-fragment\.json$'
  '^\.claude/settings.*\.json$'
  '^\.claude-plugin/'
  '^agents/'
  '^\.claude/agents/'
)

touches_sensitive_path() {
  local re
  for re in "${SENSITIVE_PATHS[@]}"; do
    # `&& return 0` here would make a non-matching pattern the loop body's
    # exit status, which `set -e` treats as a script failure.
    if [[ "$1" =~ $re ]]; then
      return 0
    fi
  done
  return 1
}
~~~
4. file: `hooks/scripts/lib/unit-scope.sh`
   anchor: new file (mode 644)
   indent: 0
   insert-after:
~~~
# unit-scope.sh (st-u1): unit-scope classification shared by review-precheck.sh
# (the reviewer's mechanical pre-review) and writer-scope-gate.sh (SubagentStop).
# Sourced, never executed (mode 644). Pure functions over files and git objects;
# nothing here writes a file.

# us_section <file> <heading>: the lines of `## <heading>` up to the next `## `
# heading, outside ``` and ~~~ fences.
us_section() {
  awk -v h="## $2" '
    /^[[:space:]]*(```|~~~)/ { fence = !fence; next }
    fence { next }
    /^## / { on = ($0 == h || index($0, h " ") == 1); next }
    on { print }
  ' "$1"
}

# us_entries <file>: every backtick-quoted token with no space that contains a
# `/` or a `.` in the file's `## Affected files` section, one per line.
us_entries() {
  us_section "$1" "Affected files" | grep -oE '`[^` ]+`' | tr -d '`' | grep -E '[/.]' || true
}

# us_listed <path> <entries-file>: exit 0 when an entry equals the path, is a
# directory prefix of it, or is a glob that matches it.
us_listed() {
  local p="$1" e
  [ -s "$2" ] || return 1
  while IFS= read -r e || [ -n "$e" ]; do
    e="${e%/}"
    [ -n "$e" ] || continue
    [ "$p" = "$e" ] && return 0
    case "$p" in "$e"/*) return 0 ;; esac
    case "$e" in *[*?]*) [[ "$p" == $e ]] && return 0 ;; esac
  done < "$2"
  return 1
}

# us_named_in <path> <text-file>: exit 0 when the path occurs in the text as a
# whole path token (no path character directly before or after it).
us_named_in() {
  [ -s "$2" ] || return 1
  local q
  q="$(printf '%s' "$1" | sed 's/[][\.*^$+?(){}|/]/\\&/g')"
  grep -qE "(^|[^A-Za-z0-9._/-])${q}(\$|[^A-Za-z0-9._/-])" "$2"
}

# us_plugin_version <path> <rev>: exit 0 when <rev> is this plugin's own repo
# layout (it tracks .claude-plugin/plugin.json) and the path is one of the three
# version-stamp files that constitution P3 and validate.sh require every
# version-bumping commit to change.
us_plugin_version() {
  git cat-file -e "$2:.claude-plugin/plugin.json" 2>/dev/null || return 1
  case "$1" in .claude-plugin/plugin.json|package.json|CHANGELOG.md) return 0 ;; esac
  return 1
}

# us_version_name <path>: exit 0 for a file name that commonly holds a version
# stamp in other projects; such a path is left to the reviewer (class judge).
us_version_name() {
  case "${1##*/}" in package.json|plugin.json|CHANGELOG.md|VERSION|pyproject.toml|Cargo.toml|setup.cfg) return 0 ;; esac
  return 1
}

# us_classify <path> <rev> <listed> <fix-listed> <criteria-text> <fail-text>:
# prints exactly one class word: listed | criteria | fail-record | fix-contract |
# plugin-version | judge | out. Every file argument may be /dev/null.
us_classify() {
  local p="$1"
  if us_listed "$p" "$3"; then echo listed
  elif us_named_in "$p" "$5"; then echo criteria
  elif us_named_in "$p" "$6"; then echo fail-record
  elif us_listed "$p" "$4"; then echo fix-contract
  elif us_plugin_version "$p" "$2"; then echo plugin-version
  elif us_version_name "$p"; then echo judge
  else echo out
  fi
}
~~~
5. file: `hooks/scripts/reviewer-tier.sh`
   anchor: line matching `# Size alone is unsafe: measured over the last 50 commits, three small diffs`
   indent: 0
   before:
~~~
# Size alone is unsafe: measured over the last 50 commits, three small diffs
# (1f 28L, 2f 41L, 1f 25L) were security/logic-critical. Size is therefore
# conjunctive with this path-class exclusion, which is never optional.
SENSITIVE_PATHS=(
  '^hooks/'
  '^\.claude/hooks/'
  '^adapters/.*hooks'
  '^bin/cli\.js$'
  '^tests/validate\.sh$'
  '^templates/persona-protocol.*\.md$'
  '^templates/settings-fragment\.json$'
  '^\.claude/settings.*\.json$'
  '^\.claude-plugin/'
  '^agents/'
  '^\.claude/agents/'
)

opus() { echo opus; exit 0; }

touches_sensitive_path() {
  local re
  for re in "${SENSITIVE_PATHS[@]}"; do
    # `&& return 0` here would make a non-matching pattern the loop body's
    # exit status, which `set -e` treats as a script failure.
    if [[ "$1" =~ $re ]]; then
      return 0
    fi
  done
  return 1
}
~~~
   after:
~~~
opus() { echo opus; exit 0; }
~~~
6. file: `hooks/scripts/reviewer-tier.sh`
   anchor: line matching `. "$(dirname "${BASH_SOURCE[0]}")/lib/state-access.sh"`
   indent: 0
   before: `. "$(dirname "${BASH_SOURCE[0]}")/lib/state-access.sh"`
   after:
~~~
. "$(dirname "${BASH_SOURCE[0]}")/lib/state-access.sh"
. "$(dirname "${BASH_SOURCE[0]}")/lib/sensitive-paths.sh"
~~~
7. file: `tests/reviewer-tier.test.sh`
   anchor: line matching `if mutate no-agents-anchor`
   indent: 0
   before:
~~~
if mutate no-agents-anchor "/^  '\^agents\/'\$/d"; then
  run_at "(mc13) ^agents/ anchor removed: case (aq) flips to" \
    sonnet unit-1 "$r_agents" "$repo" "$repo" "$MUTANT"
fi
~~~
   after:
~~~
# st-u1: the path class lives in lib/sensitive-paths.sh, so this control
# mutates the lib copy beside an unmutated copy of the script, then restores it.
SP="$tmproot/lib/sensitive-paths.sh"
cp "$SP" "$tmproot/sp.orig" && cp "$SCRIPT" "$tmproot/rt-copy.sh"
sed "/^  '\^agents\/'\$/d" "$tmproot/sp.orig" > "$SP"
if cmp -s "$SP" "$tmproot/sp.orig"; then
  echo "FAIL mutation control 'no-agents-anchor': the sed matched nothing"
  fail=1
else
  run_at "(mc13) ^agents/ anchor removed: case (aq) flips to" \
    sonnet unit-1 "$r_agents" "$repo" "$repo" "$tmproot/rt-copy.sh"
fi
cp "$tmproot/sp.orig" "$SP"
~~~
8. file: `bin/cli.js`
   anchor: line matching `const CLAUDE_ONLY_HOOK_LIB_FILES = [`
   indent: 0
   before: `const CLAUDE_ONLY_HOOK_LIB_FILES = ['benign-command.sh'];`
   after: `const CLAUDE_ONLY_HOOK_LIB_FILES = ['benign-command.sh', 'sensitive-paths.sh', 'unit-scope.sh'];`
9. file: `tests/validate.sh`
   anchor: line matching `echo "== orchestrator-model: sonnet by default, orchestratorModel opt-out (Node, qw-u6) =="`
   indent: 0
   before:
~~~
echo "== orchestrator-model: sonnet by default, orchestratorModel opt-out (Node, qw-u6) =="
if node tests/orchestrator-model.test.js > /dev/null 2>&1; then
  echo "OK   tests/orchestrator-model.test.js"
else
  echo "FAIL tests/orchestrator-model.test.js"
  fail=1
fi
~~~
   after:
~~~
echo "== orchestrator-model: sonnet by default, orchestratorModel opt-out (Node, qw-u6) =="
if node tests/orchestrator-model.test.js > /dev/null 2>&1; then
  echo "OK   tests/orchestrator-model.test.js"
else
  echo "FAIL tests/orchestrator-model.test.js"
  fail=1
fi

echo
echo "== scope-libs: sensitive-path class and unit-scope classes shared by precheck and scope gate (Bash, st-u1) =="
if bash tests/scope-libs.test.sh > /dev/null; then
  echo "OK   tests/scope-libs.test.sh"
else
  echo "FAIL tests/scope-libs.test.sh"
  fail=1
fi
~~~
10. command: `bash -c 'bash tests/scope-libs.test.sh >/dev/null && bash tests/reviewer-tier.test.sh >/dev/null; echo $?'`
   expect: 0
   It prints `0`. If reviewer-tier.test.sh fails, the move changed behaviour: stop and report.
11. command: `perl -0pi -e 's/("version": "\d+\.\d+\.)(\d+)"/$1.($2+1)."\""/e' .claude-plugin/plugin.json package.json`
   expect: 0
   This adds one to the patch version in both files (expected 0.31.194 to 0.31.195). The bump is required even though no
   `agents/` or `templates/` file changes: `--update` installs new files only when `pluginVersion` moves.
12. file: `CHANGELOG.md`
   anchor: line matching `## [Unreleased]`
   indent: 0
   insert-after:
~~~

**Shared scope libraries (st-u1, VERSION).** reviewer-tier.sh's sensitive-path class moves unchanged into `hooks/scripts/lib/sensitive-paths.sh`, which reviewer-tier.sh now sources, and the new `hooks/scripts/lib/unit-scope.sh` classifies a changed path against a unit's scope (listed, criteria, fail-record, fix-contract, plugin-version, judge, out) for the coming precheck and scope gate. No behaviour change; reviewer-tier.test.sh's mc13 control now mutates the library copy. New test tests/scope-libs.test.sh.
~~~
   Replace `VERSION` with the version that edit 11 wrote.
13. command: `node bin/cli.js --update`
   expect: 0
14. command: `git add tests/scope-libs.test.sh hooks/scripts/lib/sensitive-paths.sh hooks/scripts/lib/unit-scope.sh .claude/hooks/scripts/lib/sensitive-paths.sh .claude/hooks/scripts/lib/unit-scope.sh && git add -u && git commit -m "refactor(st-u1): shared sensitive-path and unit-scope hook libraries"`
   expect: 0
   Run `git status --short` first: if a tracked file outside "Affected files" is modified (for example another agent's memory note), stop and report it instead of committing it.

## Do NOT touch
- `hooks/hooks.json` and every other `hooks/scripts/*.sh` except reviewer-tier.sh (no gate or registration change; criterion 5)
- `adapters/` (both libraries are Claude-only: `CLAUDE_ONLY_HOOK_LIB_FILES`, never `SHARED_HOOK_LIB_FILES`; criterion 5)
- `agents/` and `templates/` (no prose in this unit)
- `.claude/hooks/` by hand (only `node bin/cli.js --update` writes it)

## Acceptance criteria
1. run: `bash -c 'bash tests/scope-libs.test.sh >/dev/null; echo $?'`
   exit: 0
   stdout: `0`
   mutation: in `us_listed`, change `"$e"/*` to `"$e"*`; case (d) prints `FAIL (d) sibling prefix matched` and stdout is `1`.
2. run: `bash -c 'bash tests/reviewer-tier.test.sh >/dev/null 2>&1; echo $?'`
   exit: 0
   stdout: `0`
   mutation: skip edit 7; mc13 prints `FAIL mutation control 'no-agents-anchor': the sed matched nothing` and stdout is `1` (spec-master observed this on a clone).
3. run: `bash -c 'b=$(git log --format=%H --grep="(st-u1)" | tail -1); diff <(git show "$b^:hooks/scripts/reviewer-tier.sh" | sed -n "/^SENSITIVE_PATHS=(/,/^)/p") <(sed -n "/^SENSITIVE_PATHS=(/,/^)/p" hooks/scripts/lib/sensitive-paths.sh) >/dev/null && ! grep -q "^SENSITIVE_PATHS=(" hooks/scripts/reviewer-tier.sh && echo same'`
   exit: 0
   stdout: `same`
   mutation: delete the `'^agents/'` line from the library; diff reports it, stdout is empty and the exit is 1.
4. run: `bash -c 'for f in hooks/scripts/lib/sensitive-paths.sh hooks/scripts/lib/unit-scope.sh hooks/scripts/reviewer-tier.sh; do cmp "$f" ".claude/$f" || exit 1; done'`
   exit: 0
   stdout: empty
   mutation: append a line to `.claude/hooks/scripts/lib/unit-scope.sh`; cmp reports the difference and exits 1.
5. run: `bash -c 'b=$(git log --format=%H --grep="(st-u1)" | tail -1); git diff --name-only "$b^..HEAD" -- adapters hooks/hooks.json agents templates | wc -l'`
   exit: 0
   stdout: `0`
   mutation: put the two libraries in `SHARED_HOOK_LIB_FILES` instead; `--update` writes them under `adapters/*/hooks/scripts/lib/` and stdout is at least `2`.
6. run: `node -e "require('./bin/cli.js'); console.log('loads')"`
   exit: 0
   stdout: `loads`
   mutation: skip edit 8; `assertHookLibDeclarationComplete` throws "not classified" and the exit is 1.
7. run: `bash -c 'b=$(git log --format=%H --grep="(st-u1)" | tail -1); test "$(git show "$b^:.claude-plugin/plugin.json" | grep "\"version\"")" != "$(grep "\"version\"" .claude-plugin/plugin.json)" && test "$(grep -c "(st-u1, " CHANGELOG.md)" = 1 && echo moved'`
   exit: 0
   stdout: `moved`
   mutation: skip edit 11; the versions are equal, stdout is empty and the exit is 1.
8. run: `bash -c 'bash tests/validate.sh >/dev/null 2>&1; echo $?'` (Bash tool timeout 600000 ms)
   exit: 0
   stdout: `0`
   mutation: put `exit 1` as line 2 of tests/scope-libs.test.sh; validate.sh exits 1 and stdout is `1`.

## Pre-resolved context
tdd: yes the test (edit 1) fails first (edit 2). spec-master applied edits 1 to 9 to a clone at eb59e217: scope-libs 46 checks pass, reviewer-tier 63 checks pass, the array diff is empty, `--update` installs both libraries (cmp clean), and cli-hook-propagation, protected-paths-coverage, trust-model-bijection, cli-backfill, state-access-constraints and bin-helpers-scaffold stay green. validate.sh was not run by spec-master.
blast-radius: hooks/scripts/reviewer-tier.sh:17 (source lines), hooks/scripts/reviewer-tier.sh:22-51 (class and function), tests/reviewer-tier.test.sh:337-340 (mc13), bin/cli.js:685 (CLAUDE_ONLY_HOOK_LIB_FILES; checked at load by assertHookLibDeclarationComplete), bin/cli.js:644 (buildHookScriptSpecs installs lib/ recursively). Line numbers are at eb59e217; work from the anchors.
moved-verbatim: edit 3's library body after its 4-line header is the exact text edit 5 removes, minus the `opus()` line, which stays in reviewer-tier.sh. Criterion 3 checks the array against the parent commit.
mutation-controls: mc1 (`if touches_sensitive_path` inverted) still mutates the call site, which stays in reviewer-tier.sh. Only mc13 named a pattern line, so only mc13 moves. The new mc13 copies reviewer-tier.sh beside the mutated library copy in `$tmproot`, because a mutant sources `$(dirname)/lib/`.
classes: `us_classify <path> <rev> <listed> <fix-listed> <criteria-text> <fail-text>` checks in this order: listed (exact, directory prefix or glob), criteria (a whole path token in a criteria `run:` line), fail-record, fix-contract, plugin-version (only when `<rev>` tracks `.claude-plugin/plugin.json`: plugin.json, package.json, CHANGELOG.md), judge (a common version-file name), out.
version: .claude-plugin/plugin.json and package.json read 0.31.194 after qw-u6 if no fix round bumped; edit 11 adds one (expected 0.31.195).
mirrors: `.claude/` copies and `fileHashes` change only through `node bin/cli.js --update` (constitution P2).
prior-fail: the reviewer-tier `.fail` records concern rename, quoting and unit-id defects at the call site; none is in the moved span. mw-step1 (vacuous registration): the validate.sh block is its own `if` section (criterion 8's mutation).
commit-message: refactor(st-u1): shared sensitive-path and unit-scope hook libraries
diagnosis: none
review-packet:
~~~
unit: st-u1
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
If a `before:` payload is not found verbatim (qw-u6's validate.sh block may be rewrapped by a fix round), stop and
report the current text; do not improvise. If `tests/reviewer-tier.test.sh` fails after edit 7 for any case but mc13,
the move changed behaviour: stop and report. If `node bin/cli.js --update` refuses, quote it and stop. If a gate
blocks a command, report it and wait. Anything outside "Affected files" goes to your report as a proposal.
