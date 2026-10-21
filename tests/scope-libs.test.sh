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
grep -qxF '  && . "$(dirname "${BASH_SOURCE[0]}")/lib/sensitive-paths.sh"; } 2>/dev/null || { echo opus; exit 0; }' "$ROOT/hooks/scripts/reviewer-tier.sh" && ok "(b) reviewer-tier.sh sources the lib, opus when it cannot" || bad "(b) source line missing"
grep -qxF 'declare -F touches_sensitive_path unit_id_sanitize state_unit_marker_exists >/dev/null || { echo opus; exit 0; }' "$ROOT/hooks/scripts/reviewer-tier.sh" && ok "(b) reviewer-tier.sh checks the functions are defined" || bad "(b) declare -F guard missing"

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

# (g) us_entries reads a named section; a token in a Do NOT touch reason is not an entry (rp-u9).
printf '## Affected files\n- `a/b.js`\n\n## Do NOT touch\n- `c/d.js` (reason `e.f`)\n' > "$T/g.md"
[ "$(us_entries "$T/g.md" "Do NOT touch" | tr '\n' ' ')" = 'c/d.js ' ] && ok "(g) Do NOT touch entries" || bad "(g) section entries"
[ "$(us_entries "$T/g.md" | tr '\n' ' ')" = 'a/b.js ' ] && ok "(g) default section" || bad "(g) default section"

# (h) rp-u9: `## Do NOT touch` excludes a bullet's whole subject only. The bullets are copied verbatim
# from the contracts of aof-u1 to aof-u4, aof-u3b, qw-u1 to qw-u6, rp-u1 to rp-u3 and st-u1 (fixtures, not
# the live files); the last five bullets are grammar cases.
cat > "$T/h.md" << 'MD'
## Do NOT touch
- `bin/ladder-tier.sh`, `bin/contract-guard.js`, `bin/contract-score.js`, `bin/fail-count.sh`,
  `bin/escalation-card.sh`: no script edits. The layout already resolves under `.claude/`.
- `bin/harness-integrity.sh` and `hooks/scripts/session-start.sh` (spec R2; re-arming the drift check is a
  separate operator decision).
- `hooks/hooks.json`, `templates/settings-fragment.json`, `harness-integrity-gate.sh`'s Set A lists.
- Anything under `eval/`.
- `hooks/scripts/lib/reviewer-route-gate-core.sh` and the stamp format it writes.
- `hooks/scripts/stop-gate.sh`, the entry point, unless the new function needs a lib that is already sourced
  there. It should not.
- `agents/scribe.md`, `agents/spec-master.md`, and the Scribe dispatch convention in orchestrator.md: those
  are aof-u4.
- `.claude/` copies by hand: `node bin/cli.js --update` rewrites them, including the version stamp in
  `.claude/protocol-digest.md` and `.claude/persona-protocol*.md`; that stamp change is expected, not a scope breach
- `CONTEXT.md` and `docs/adr/`: the draft ADR in the spec is landed later by scribe, not by this unit.
- `.claude/agents/orchestrator.md` by hand (only `node bin/cli.js --update` writes it)
- `agents/orchestrator.md` ESCALATE-TO-HUMAN steps (qw-u4 moves them; leave them as they are)
- `bin/cli.js` (no matrix change; section headings are unchanged, so `tests/protocol-doc-drift.test.js` counts stay valid)
- `agents/orchestrator.md` from the paragraph starting `If no` (the no-reviewer paragraph) to the end of the file
- `adapters/codex/agents/reviewer.toml`, `adapters/cursor/agents/reviewer.md` and the two adapter protocol ports (their scaffolds install no `.claude/bin/`; criterion 5)
- `agents/reviewer.md`, `agents/lead-programmer.md` and every other `agents/*.md` frontmatter (subagent tiers are unchanged)
- `hooks/hooks.json` and every other `hooks/scripts/*.sh` except reviewer-tier.sh (no gate or registration change; criterion 5)
- `agents/` and `templates/` (no prose in this unit)
- `hooks/scripts/lib/unit-scope.sh`, `hooks/scripts/writer-scope-gate.sh`, `bin/review-precheck.sh` (st-u1 to st-u3 own them; spec Open Question 1)
- `docs/guide.md` partial: lines 10 to 20 only
- `docs/guide2.md` (partial: its first section)
- `docs/x.md` — an em-dash reason naming `docs/r1.md`
- `docs/y.md` - a dash reason naming `docs/r2.md`
- `docs/z.md`, `docs/w.md`, or `docs/v.md`.
MD
us_exclusions "$T/h.md" > "$T/hx.txt"
want='bin/ladder-tier.sh bin/contract-guard.js bin/contract-score.js bin/fail-count.sh bin/escalation-card.sh bin/harness-integrity.sh hooks/scripts/session-start.sh CONTEXT.md docs/adr/ bin/cli.js agents/ templates/ hooks/scripts/lib/unit-scope.sh hooks/scripts/writer-scope-gate.sh bin/review-precheck.sh docs/x.md docs/y.md docs/z.md docs/w.md docs/v.md '
[ "$(tr '\n' ' ' < "$T/hx.txt")" = "$want" ] && ok "(h) whole-subject bullets only" || bad "(h) exclusions: $(tr '\n' ' ' < "$T/hx.txt")"
cmp -s "$T/hx.txt" <(us_entries "$T/h.md" "Do NOT touch") && ok "(h) us_entries reads Do NOT touch through us_exclusions" || bad "(h) us_entries Do NOT touch differs"
for p in agents/orchestrator.md tests/protocol-doc-drift.test.js hooks/hooks.json hooks/scripts/lib/reviewer-route-gate-core.sh .claude/protocol-digest.md \
         hooks/scripts/stop-gate.sh agents/scribe.md .claude/agents/orchestrator.md adapters/codex/agents/reviewer.toml \
         agents/reviewer.md docs/guide.md docs/guide2.md docs/r1.md docs/r2.md; do
  us_excluded "$p" "$T/hx.txt" && bad "(h) wrongly excluded: $p" || ok "(h) not excluded: $p"
done
printf 'agents/orchestrator.md\n' > "$T/ho.txt"
[ "$(us_classify agents/orchestrator.md "$R1" "$T/ho.txt" /dev/null /dev/null /dev/null "$T/hx.txt")" = listed ] && ok "(h) qw-u2/qw-u4: the main edited file stays listed" || bad "(h) main edited file excluded"
[ "$(us_classify bin/cli.js "$R1" "$T/ho.txt" /dev/null /dev/null /dev/null "$T/hx.txt")" = excluded ] && ok "(h) a whole-file bullet still excludes" || bad "(h) whole-file bullet lost"

# (i) rp-u9: a glob's `*` and `?` stay inside one path segment; an unsafe path (empty, a newline, a `.` or
# `..` segment) is never listed and classifies `out`.
printf 'docs/*.md\nsrc\ntests/?.sh\nlib/a.b*\n' > "$T/i.txt"
us_listed docs/guide.md "$T/i.txt" && ok "(i) glob within a segment" || bad "(i) glob within a segment"
us_listed docs/adr/0042-x.md "$T/i.txt" && bad "(i) * crossed a /" || ok "(i) * stops at /"
us_listed tests/a.sh "$T/i.txt" && ok "(i) ? is one character" || bad "(i) ? one character"
us_listed tests/x/a.sh "$T/i.txt" && bad "(i) ? crossed a /" || ok "(i) ? stops at /"
us_listed lib/axb1 "$T/i.txt" && bad "(i) a glob's . matched any character" || ok "(i) a glob's . is literal"
us_listed lib/a.b1 "$T/i.txt" && ok "(i) literal . then *" || bad "(i) literal . then *"
us_listed src/../CONTEXT.md "$T/i.txt" && bad "(i) .. counted under src" || ok "(i) .. segment not listed"
us_listed src/./a.js "$T/i.txt" && bad "(i) . segment listed" || ok "(i) . segment not listed"
us_listed "$(printf 'src/a.js\nCONTEXT.md')" "$T/i.txt" && bad "(i) newline path listed" || ok "(i) newline path not listed"
printf 'CONTEXT.md\n' > "$T/ix.txt"
[ "$(us_classify "$(printf 'src/a.js\nCONTEXT.md')" "$R1" "$T/i.txt" /dev/null /dev/null /dev/null "$T/ix.txt")" = out ] && ok "(i) newline path classifies out" || bad "(i) newline path class"
[ "$(us_classify src/../CONTEXT.md "$R1" "$T/i.txt" /dev/null /dev/null /dev/null)" = out ] && ok "(i) .. path classifies out" || bad "(i) .. path class"
[ "$(us_classify src/a.js "$R1" "$T/i.txt" /dev/null /dev/null /dev/null)" = listed ] && ok "(i) a plain path under a listed directory" || bad "(i) plain path"

# (j) rp-u11: `partial:` in any letter case never excludes; a spaced `--` and an em or en dash (spaced or
# not) end the subject; a reason after `,` or `;` is not a separator (no exclusion, as documented).
cat > "$T/j.md" << 'MD'
## Do NOT touch
- `j/p1.sh` (Partial: lines 1-10)
- `j/p2.sh` PARTIAL: its header
- `j/d1.sh` – an en-dash reason
- `j/d2.sh` -- a double-dash reason
- `j/d3.sh`—an unspaced em dash reason
- `j/d4.sh`–an unspaced en dash reason
- `j/c1.sh`, a reason after a comma
- `j/c2.sh`; a reason after a semicolon
- `j/w1.sh` and `j/w2.sh`
MD
[ "$(us_exclusions "$T/j.md" | tr '\n' ' ')" = 'j/d1.sh j/d2.sh j/d3.sh j/d4.sh j/w1.sh j/w2.sh ' ] && ok "(j) partial: any case, dash separators" || bad "(j) exclusions: $(us_exclusions "$T/j.md" | tr '\n' ' ')"
# (j) a file saved with CRLF endings: headings are still found and no CR reaches an entry.
printf '## Affected files\r\n- `src/a.js`\r\n\r\n## Do NOT touch\r\n- `src/b.js` (a reason)\r\n' > "$T/jc.md"
[ "$(us_entries "$T/jc.md")" = src/a.js ] && ok "(j) CRLF: Affected files entry" || bad "(j) CRLF entries: $(us_entries "$T/jc.md" | od -c | head -n1)"
[ "$(us_exclusions "$T/jc.md")" = src/b.js ] && ok "(j) CRLF: Do NOT touch exclusion" || bad "(j) CRLF exclusions: $(us_exclusions "$T/jc.md" | od -c | head -n1)"
# (j) a doubled, leading or trailing slash is never listed and classifies out, so it cannot slip past the
# exact-match exclusion of the file it names.
printf 'src\n' > "$T/jl.txt"; printf 'src/secret.js\n' > "$T/jx.txt"
for p in src//secret.js src/secret.js/ /src/secret.js; do
  us_listed "$p" "$T/jl.txt" && bad "(j) listed: $p" || ok "(j) not listed: $p"
  [ "$(us_classify "$p" "$R1" "$T/jl.txt" /dev/null /dev/null /dev/null "$T/jx.txt")" = out ] && ok "(j) out: $p" || bad "(j) class of $p"
done
[ "$(us_classify src/secret.js "$R1" "$T/jl.txt" /dev/null /dev/null /dev/null "$T/jx.txt")" = excluded ] && ok "(j) the plain path is still excluded" || bad "(j) plain path class"

exit "$fail"
