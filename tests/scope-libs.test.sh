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

# (e2) us_executed_in: a path a command runs (interpreter script or command position), not one it reads.
printf 'bash -c "bash tests/v.sh >/dev/null; echo $?"; node tests/n.test.js && grep -c x src/named.js\n' > "$T/x2.txt"
us_executed_in tests/v.sh "$T/x2.txt" && ok "(e2) bash script executed" || bad "(e2) bash script"
us_executed_in tests/n.test.js "$T/x2.txt" && ok "(e2) node script executed" || bad "(e2) node script"
us_executed_in src/named.js "$T/x2.txt" && bad "(e2) read operand taken as executed" || ok "(e2) read operand not executed"

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
printf 'run: `bash tests/v.sh` and `grep -c x src/named.js`\n' > "$T/r2.txt"
[ "$(us_classify tests/v.sh "$R1" /dev/null /dev/null "$T/r2.txt" /dev/null)" = out ] && ok "(f) a criterion-executed path is not criteria" || bad "(f) executed path classed criteria"
[ "$(us_classify src/named.js "$R1" /dev/null /dev/null "$T/r2.txt" /dev/null)" = criteria ] && ok "(f) a criterion-read path is criteria" || bad "(f) read path"
printf 'src/store.js\npackage\n' > "$T/n.txt"
[ "$(us_classify src/store.js "$R1" "$T/l.txt" /dev/null "$T/r.txt" "$T/f.txt" "$T/n.txt")" = excluded ] && ok "(f) Do NOT touch wins over listed" || bad "(f) excluded"
[ "$(us_classify package.json "$R1" /dev/null /dev/null /dev/null /dev/null "$T/n.txt")" = plugin-version ] && ok "(f) exclusion is exact only" || bad "(f) exclusion not exact"

# (g) us_entries reads a named section.
printf '## Affected files\n- `a/b.js`\n\n## Do NOT touch\n- `c/d.js` (reason `e.f`)\n' > "$T/g.md"
[ "$(us_entries "$T/g.md" "Do NOT touch" | tr '\n' ' ')" = 'c/d.js e.f ' ] && ok "(g) Do NOT touch entries" || bad "(g) section entries"
[ "$(us_entries "$T/g.md" | tr '\n' ' ')" = 'a/b.js ' ] && ok "(g) default section" || bad "(g) default section"

exit "$fail"
