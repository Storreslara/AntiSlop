Unit: rp-u14

## Objective
Review notes on `bin/review-precheck.sh` (st-u2, 0.31.201; st-u2-fix1, bc96b47a, 0.31.202) and its reviewer
bullet, from st-u2's PASS (`.claude/reviewed/st-u2.pass`). After this unit:
- (d) `--fix-contract` is read at the first commit after the baseline that touches it (the commit that added
  it), never from the working tree. A fix contract changed after that commit prints
  `fix-contract: changed-since-added <path>`, one never committed `fix-contract: not-committed <path>`; both
  are failure lines. Today the working-tree copy's `## Affected files` widens the scope, so a writer that
  edits its own fix contract licenses a leaked file. An absolute or `..` spelling resolves like `--contract`.
- (b) In a fix round the script also runs the fix contract's criteria (as read at that commit), as
  `fix criterion <n>: ...` lines counted in `fails=`, `deferred=` and `judge=`. Today it never runs them.
- (c) An empty range (no changed file outside `.claude/` and `docs/plans/`; a baseline equal to HEAD is the
  usual cause) prints `scope: judge no-changed-files <base>..<head>`, counted in `judge=`. Today it prints
  `result=pass files=0` with nothing flagged.
- (f) Both scope libraries are sourced with `>/dev/null 2>&1`: a library that prints when sourced no longer
  puts a stray line before the packet (the guard the operator deferred to "a later unit that already
  edits the script", spec Clarifications, Open Question 7).
- (a, e) `agents/reviewer.md`'s pre-review bullet names the new failure lines and the judge line, says
  "contract of record" (CONTEXT.md **contract of record**), and says what to do when
  `contract: not-at-baseline` fires because the contract was committed after the given baseline: re-run
  with the commit that added it as the baseline when no commit of the unit lies before it; otherwise the
  line stands.
- `tests/review-precheck.test.sh` gains case (l) and the (j) prose pins follow the new bullet.
No baseline-choice sentence is added to `agents/orchestrator.md` or `bin/unit-bookkeeping.sh` (spec Step 11).
This is spec Step 11.

## Retrieval
Fast path, no tracker issue. Spec: `docs/plans/antislop-review-patches/spec.md`, "Step 11 (rp-u13, rp-u14)"
and "Context, rp-u11 and st-u2 review notes". This file is the contract of record. Dispatch it after rp-u13
(spec Dispatch section); no queued unit edits `bin/review-precheck.sh`, `tests/review-precheck.test.sh` or
`agents/reviewer.md`.

## Affected files
- `tests/review-precheck.test.sh` (anchors: line matching `# (j) prose: the reviewer and the protocol name the pre-review script and its FAIL rule.`; line matching `'The script reads the contract only from the baseline commit.' \`)
- `bin/review-precheck.sh` (anchors: line matching `# --fix-contract is the exception: it is written after the baseline, so it is read from the working tree.`; line matching `. "$lib/sensitive-paths.sh" 2>/dev/null || exit 2`; line matching `    echo "review-precheck: contract not found: $contract" >&2; exit 2`; line matching `[ -z "$fixc" ] || { [ -f "$fixc" ] && us_entries "$fixc" > "$W/fix"; }`; line matching `done < "$W/changed"`; line matching `  say "criteria: none (no contract; run the project's test and lint command yourself)"`)
- `agents/reviewer.md` (anchor: line matching `  the code. The script reads the contract only from the baseline commit. Do not`)
- `.claude-plugin/plugin.json`, `package.json`, `CHANGELOG.md`
- generated only, by `node bin/cli.js --update`: `.claude/bin/review-precheck.sh`, `.claude/agents/reviewer.md`,
  `.claude/agents/*.md`, `.claude/persona-protocol*.md` and `.claude/protocol-digest.md` (version stamps
  only), the config's `fileHashes` and `pluginVersion`

## Ordered edits
1. file: `tests/review-precheck.test.sh`
   anchor: line matching `# (j) prose: the reviewer and the protocol name the pre-review script and its FAIL rule.`
   indent: 0
   before:
~~~
# (j) prose: the reviewer and the protocol name the pre-review script and its FAIL rule.
~~~
   after:
~~~
# (l) rp-u14: a fix contract is read at the commit that added it and its criteria run as `fix criterion`
# lines; a fix contract never committed, or edited after that commit, is a failure line; an empty range is a
# counted judge line; a scope library that prints when sourced leaves no stray line in the packet.
g reset -q --hard "$BASE"
F=docs/plans/p/contracts/u1-fix1.md
cat > "$F" << 'MD'
Unit: u1

## Affected files
- `src/b.js`

## Acceptance criteria
1. run: `bash -c 'test -f src/b.js && echo fixed'`
   exit: 0
   stdout: `fixed`
   mutation: none
MD
out="$(bash "$PC" u1 "$BASE" --contract "$C" --fix-contract "$F")"
printf '%s\n' "$out" | grep -qxF "fix-contract: not-committed $F" && ok "(l) uncommitted fix contract is a failure line" || bad "(l) no not-committed line"
printf '%s\n' "$out" | grep -q '^fix criterion ' && bad "(l) a criterion ran from an uncommitted fix contract" || ok "(l) no fix criterion ran"
g add "$F" && g commit -q -m 'docs(p): fix contract u1-fix1'
printf 'a\nb\n' > src/a.js && printf 'b\n' > src/b.js && g add -A && g commit -q -m 'u1: fix'
out="$(bash "$PC" u1 "$BASE" --contract "$C" --fix-contract "$F")"
for l in 'scope: ok src/b.js fix-contract' 'fix criterion 1: pass exit=0'; do
  printf '%s\n' "$out" | grep -qxF -- "$l" && ok "(l) $l" || bad "(l) missing: $l"
done
first "$out" | grep -q '^precheck: result=pass .* fails=0 deferred=1 judge=1$' && ok "(l) fix round passes" || bad "(l) header: $(first "$out")"
printf '%s\n' "$out" | grep -q 'no-changed-files' && bad "(l) a non-empty range got the empty-range line" || ok "(l) non-empty range: no empty-range line"
[ "$(bash "$PC" u1 "$BASE" --contract "$C" --fix-contract "$(git rev-parse --show-toplevel)/$F")" = "$out" ] && ok "(l) an absolute --fix-contract gives the same packet" || bad "(l) absolute fix contract differs"
sed -i '/^- `src\/b.js`$/a - `CONTEXT.md`' "$F" && printf 'x\n' > CONTEXT.md && g add -A && g commit -q -m 'u1: widen the fix contract'
out="$(bash "$PC" u1 "$BASE" --contract "$C" --fix-contract "$F")"
printf '%s\n' "$out" | grep -qxF "fix-contract: changed-since-added $F" && ok "(l) fix contract edited after it was added" || bad "(l) fix contract edit not flagged"
printf '%s\n' "$out" | grep -qxF 'scope: out CONTEXT.md' && ok "(l) the widened entry licenses nothing" || bad "(l) widened entry used"
g reset -q --hard HEAD~1
H="$(git rev-parse HEAD)"; out="$(bash "$PC" u1 "$H" --contract "$C")"
printf '%s\n' "$out" | grep -qxF "scope: judge no-changed-files $H..$H" && ok "(l) empty range: judge line" || bad "(l) empty range not flagged"
first "$out" | grep -q '^precheck: result=pass .* judge=2$' && ok "(l) empty range counted in judge=" || bad "(l) empty range header: $(first "$out")"
L="$(mktemp -d)"; mkdir -p "$L/bin" "$L/hooks/scripts/lib" && cp "$PC" "$L/bin/" && cp "$ROOT/hooks/scripts/lib/sensitive-paths.sh" "$ROOT/hooks/scripts/lib/unit-scope.sh" "$L/hooks/scripts/lib/"
printf 'echo leaked\n' >> "$L/hooks/scripts/lib/unit-scope.sh"
out="$(bash "$L/bin/review-precheck.sh" u1 "$BASE" --contract "$C")"
first "$out" | grep -q '^precheck: ' && ! printf '%s\n' "$out" | grep -qxF leaked && ok "(l) a library that prints when sourced: no stray line" || bad "(l) stray line: $(first "$out")"
rm -rf "$L"

# (j) prose: the reviewer and the protocol name the pre-review script and its FAIL rule.
~~~
2. file: `tests/review-precheck.test.sh`
   anchor: line matching `'The script reads the contract only from the baseline commit.' \`
   indent: 0
   before:
~~~
           'or `contract: not-at-baseline` line is a FAIL ground on its own' \
           'The script reads the contract only from the baseline commit.' \
~~~
   after:
~~~
           '`fix-contract: changed-since-added` or `fix-contract: not-committed` line is a FAIL ground on its own' \
           'The script reads the contract of record only from the baseline commit and the fix contract only from the commit that added it, and runs the criteria of both.' \
           'shows none of the unit'"'"'s commits, re-run with that commit as the baseline and judge that packet; otherwise the line stands.' \
           '`scope: judge no-changed-files` line means the range is empty, so check the baseline first.' \
~~~
3. command: `bash -c 'bash tests/review-precheck.test.sh 2>/dev/null | grep -c "^FAIL"'`
   expect: 0
   The red step: it prints `15` (seven (l) rows and the four new (j) pins in both reviewer copies).
4. file: `bin/review-precheck.sh`
   anchor: line matching `# --fix-contract is the exception: it is written after the baseline, so it is read from the working tree.`
   indent: 0
   before:
~~~
# A contract that is not at the baseline is a failure line (`contract: not-at-baseline`), not a fallback.
# --fix-contract is the exception: it is written after the baseline, so it is read from the working tree.
~~~
   after:
~~~
# A contract that is not at the baseline is a failure line (`contract: not-at-baseline`), not a fallback.
# --fix-contract is written after the baseline, so it is read at the first commit after the baseline that
# touches it (the commit that added it), never from the working tree (rp-u14): a fix contract changed after
# that commit is `fix-contract: changed-since-added`, one never committed `fix-contract: not-committed`.
# Its criteria run after the contract's, as `fix criterion <n>:` lines.
~~~
5. file: `bin/review-precheck.sh`
   anchor: line matching `. "$lib/sensitive-paths.sh" 2>/dev/null || exit 2`
   indent: 0
   before:
~~~
. "$lib/sensitive-paths.sh" 2>/dev/null || exit 2
. "$lib/unit-scope.sh" 2>/dev/null || exit 2
~~~
   after:
~~~
# Both streams hidden: a library that prints when sourced must not put a stray line before the packet (rp-u14).
. "$lib/sensitive-paths.sh" >/dev/null 2>&1 || exit 2
. "$lib/unit-scope.sh" >/dev/null 2>&1 || exit 2
~~~
6. file: `bin/review-precheck.sh`
   anchor: line matching `    echo "review-precheck: contract not found: $contract" >&2; exit 2`
   indent: 0
   before:
~~~
  else
    echo "review-precheck: contract not found: $contract" >&2; exit 2
  fi
fi
~~~
   after:
~~~
  else
    echo "review-precheck: contract not found: $contract" >&2; exit 2
  fi
fi

# The fix contract is pinned the same way, at the commit that added it: editing it after task-master
# committed it must not widen the unit's scope or change its criteria (rp-u14).
fcfile=""
if [ -n "$fixc" ]; then
  f0="$fixc"; fixc="$(top_rel "$f0")" || { echo "review-precheck: fix contract is not a path inside the repository: $f0" >&2; exit 2; }
  if git cat-file -e "$base:$fixc" 2>/dev/null; then fat="$base"
  else fat="$(git log --reverse --format=%H "$base..$head" -- "$fixc" | head -n1)"; fi
  if [ -n "$fat" ] && git cat-file -e "$fat:$fixc" 2>/dev/null; then
    git show "$fat:$fixc" > "$W/fixc"; fcfile="$W/fixc"
    if ! git show "$head:$fixc" 2>/dev/null | cmp -s "$W/fixc" -; then failon "fix-contract: changed-since-added $fixc"; fi
  else
    failon "fix-contract: not-committed $fixc"
  fi
fi
~~~
7. file: `bin/review-precheck.sh`
   anchor: line matching `[ -z "$fixc" ] || { [ -f "$fixc" ] && us_entries "$fixc" > "$W/fix"; }`
   indent: 0
   before:
~~~
[ -z "$fixc" ] || { [ -f "$fixc" ] && us_entries "$fixc" > "$W/fix"; }
~~~
   after:
~~~
[ -z "$fcfile" ] || us_entries "$fcfile" > "$W/fix"
~~~
8. file: `bin/review-precheck.sh`
   anchor: line matching `done < "$W/changed"`
   indent: 0
   before:
~~~
done < "$W/changed"
~~~
   after:
~~~
done < "$W/changed"
# An empty range grades nothing; a baseline equal to HEAD, or past the unit's commits, is the usual cause.
[ -s "$W/changed" ] || { say "scope: judge no-changed-files $base..$head"; judge=$((judge + 1)); }
~~~
9. file: `bin/review-precheck.sh`
   anchor: line matching `  say "criteria: none (no contract; run the project's test and lint command yourself)"`
   indent: 0
   before:
~~~
else
  say "criteria: none (no contract; run the project's test and lint command yourself)"
fi
~~~
   after:
~~~
else
  say "criteria: none (no contract; run the project's test and lint command yourself)"
fi
if [ -n "$fcfile" ]; then
  while IFS=$'\t' read -r n cmd want spec lg; do
    [ -n "$n" ] || continue
    if [ "$lg" = 1 ]; then say "fix criterion $n: deferred long"; deferred=$((deferred + 1)); continue; fi
    l="$(run_one "$n" "$cmd" "$want" "$spec")"; rc=$?
    say "fix $l"
    [ "$rc" = 1 ] && fails=$((fails + 1))
    [ "$rc" = 3 ] && judge=$((judge + 1))
  done < <(crit_items "$fcfile")
fi
~~~
10. file: `agents/reviewer.md`
   anchor: line matching `  the code. The script reads the contract only from the baseline commit. Do not`
   indent: 0
   before:
~~~
  `scope: out`, `scope: excluded`, `scope: no-affected-list`,
  `criterion <n>: fail`, `version-stamp: ... violation`,
  `contract: changed-since-baseline` or `contract: not-at-baseline` line
  is a FAIL ground on its own: return FAIL quoting those lines, without reading
  the code. The script reads the contract only from the baseline commit. Do not
  re-run a criterion it reports `pass`; run each `deferred`
  one yourself with `--criterion <n>`, and decide each `judge` line yourself.
~~~
   after:
~~~
  `scope: out`, `scope: excluded`, `scope: no-affected-list`,
  `criterion <n>: fail`, `fix criterion <n>: fail`, `version-stamp: ... violation`,
  `contract: changed-since-baseline`, `contract: not-at-baseline`,
  `fix-contract: changed-since-added` or `fix-contract: not-committed` line
  is a FAIL ground on its own: return FAIL quoting those lines, without reading
  the code. The script reads the contract of record only from the baseline
  commit and the fix contract only from the commit that added it, and runs the
  criteria of both. If `contract: not-at-baseline` fires because the contract
  of record was committed after the baseline you were given, take the commit
  that added it (`git log --diff-filter=A --format=%H -- <contract path> | tail -n1`):
  when `git log --oneline <baseline>..<that commit>` shows none of the unit's
  commits, re-run with that commit as the baseline and judge that packet;
  otherwise the line stands. Do not
  re-run a criterion it reports `pass`; run each `deferred`
  one yourself with `--criterion <n>` (a deferred `fix criterion` by hand, from
  the fix contract), and decide each `judge` line yourself; a
  `scope: judge no-changed-files` line means the range is empty, so check the
  baseline first.
~~~
11. command: `perl -0pi -e 's/("version": "\d+\.\d+\.)(\d+)"/$1.($2+1)."\""/e' .claude-plugin/plugin.json package.json`
   expect: 0
   This adds one to the patch version in both files (expected 0.31.212 to 0.31.213).
12. file: `CHANGELOG.md`
   anchor: line matching `## [Unreleased]`
   indent: 0
   insert-after:
~~~

**Review pre-check: the fix contract is pinned at its commit and its criteria run; an empty range is a judge line (rp-u14, VERSION).** bin/review-precheck.sh reads `--fix-contract` at the first commit after the baseline that touches it (the commit that added it), never from the working tree, so a writer can no longer widen its scope by editing its own fix contract; a fix contract changed after that commit prints `fix-contract: changed-since-added`, one never committed `fix-contract: not-committed` (both failure lines); its criteria now run as `fix criterion <n>:` lines; a range with no changed file prints `scope: judge no-changed-files <base>..<head>`, counted in `judge=`; both scope libraries are sourced with stdout hidden too. agents/reviewer.md: the pre-review bullet names the new lines, says contract of record, and tells the reviewer to re-run with the commit that added the contract as the baseline when `contract: not-at-baseline` fires only because the given baseline predates it. tests/review-precheck.test.sh case (l).
~~~
   Replace `VERSION` with the version that edit 11 wrote.
13. command: `node bin/cli.js --update`
   expect: 0
14. command: `bash tests/review-precheck.test.sh`
   expect: 0
15. command: `git add -u -- bin/review-precheck.sh tests/review-precheck.test.sh agents/reviewer.md .claude-plugin/plugin.json package.json CHANGELOG.md .claude && git commit -m "fix(rp-u14): review-precheck pins the fix contract at its commit and runs its criteria, flags an empty range, hides library output"`
   expect: 0
   Run `git status --short` first: if a tracked file outside "Affected files" is modified, stop and report it.

## Do NOT touch
- `templates/persona-protocol.md` (its reviewer sentence stays true: the script still re-runs the checks; rp-u7 edits its line 41; criterion 7)
- `agents/orchestrator.md` and `bin/unit-bookkeeping.sh` (the baseline stays the one the writer's packet states; no baseline-choice sentence: spec Step 11; criterion 7)
- `hooks/scripts/lib/unit-scope.sh` and `tests/scope-libs.test.sh` (rp-u13's; criterion 7)
- `adapters/` (the codex and cursor reviewer ports carry no pre-review bullet; criterion 7)

## Acceptance criteria
1. run: `bash -c 'bash tests/review-precheck.test.sh >/dev/null 2>&1; echo $?'`
   exit: 0
   stdout: `0`
   mutation: change `[ -z "$fcfile" ] || us_entries "$fcfile" > "$W/fix"` back to `[ -z "$fixc" ] || { [ -f "$fixc" ] && us_entries "$fixc" > "$W/fix"; }`; case (l) prints `FAIL (l) widened entry used` and stdout is `1`. Deleting the `say "fix $l"` line fails the (l) `fix criterion 1` row; deleting the `no-changed-files` line fails both (l) empty-range rows; changing `. "$lib/unit-scope.sh" >/dev/null 2>&1` back to `2>/dev/null` fails the (l) stray-line row (spec-master ran all four).
2. run: `bash -c 'cmp bin/review-precheck.sh .claude/bin/review-precheck.sh && echo same'`
   exit: 0
   stdout: `same`
   mutation: skip edit 13 (`--update`); `cmp` reports a difference and the command exits 1.
3. run: `bash -c 'h=$(git rev-parse HEAD); CLAUDE_PROJECT_DIR="$(mktemp -d)" bash bin/review-precheck.sh rp-u14-probe "$h" --affected x.md | grep -c "^scope: judge no-changed-files $h\.\.$h$"'`
   exit: 0
   stdout: `1`
   mutation: delete the `[ -s "$W/changed" ] || ...` line of edit 8; stdout is `0` and the exit is 1.
4. run: `bash -c 'n=0; for f in agents/reviewer.md .claude/agents/reviewer.md; do t=$(tr -s " \n" " " < "$f"); for p in "fix criterion <n>: fail" "fix-contract: not-committed" "contract of record only from the baseline commit" "re-run with that commit as the baseline and judge that packet" "scope: judge no-changed-files"; do printf "%s" "$t" | grep -qF -- "$p" && n=$((n+1)); done; done; t=$(tr -s " \n#" " " < bin/review-precheck.sh); printf "%s" "$t" | grep -qF "never from the working tree (rp-u14)" && n=$((n+1)); echo $n'`
   exit: 0
   stdout: `11`
   mutation: skip edit 10 (the reviewer bullet); stdout is `1`.
5. run: `bash -c 'b=$(git log --format=%H --grep="^[a-z]*(rp-u14): " | tail -1); l=$(git log --format=%H --grep="^[a-z]*(rp-u14): " | head -1); git diff --name-only "$b^..$l" -- . ":(exclude).claude" | LC_ALL=C sort | tr "\n" " "'`
   exit: 0
   stdout: `.claude-plugin/plugin.json CHANGELOG.md agents/reviewer.md bin/review-precheck.sh package.json tests/review-precheck.test.sh `
   mutation: also edit `templates/persona-protocol.md` in an rp-u14 commit; it joins the list.
6. run: `bash -c 'b=$(git log --format=%H --grep="^[a-z]*(rp-u14): " | tail -1); l=$(git log --format=%H --grep="^[a-z]*(rp-u14): " | head -1); bash hooks/scripts/version-stamp-check.sh "$b^..$l" | cut -d" " -f1-4'`
   exit: 0
   stdout: `version-stamp-check: ok touched: yes`
   mutation: skip edit 11; stdout reads `version-stamp-check: violation touched: yes`.
7. run: `bash -c 'b=$(git log --format=%H --grep="^[a-z]*(rp-u14): " | tail -1); l=$(git log --format=%H --grep="^[a-z]*(rp-u14): " | head -1); git diff --name-only "$b^..$l" -- templates agents/orchestrator.md bin/unit-bookkeeping.sh hooks tests/scope-libs.test.sh adapters docs/plans | wc -l'`
   exit: 0
   stdout: `0`
   mutation: edit `bin/unit-bookkeeping.sh` in an rp-u14 commit; stdout is `1`.
8. run: `bash -c 'bash tests/validate.sh >/dev/null 2>&1; echo $?'` (Bash tool timeout 600000 ms)
   exit: 0
   stdout: `0`
   mutation: put `exit 1` as line 2 of tests/review-precheck.test.sh; validate.sh exits 1 and stdout is `1`.

## Pre-resolved context
tdd: yes edits 1 and 2 add case (l) and the new (j) pins; edit 3 shows them red (`15`) before the script and prose edits.
evidence: verified 2026-10-21 against 2bccfd94 (0.31.203). `bin/review-precheck.sh:8` and `:114` read `--fix-contract` from the working tree (`[ -f "$fixc" ] && us_entries "$fixc"`) and nothing runs its criteria (`crit_items` is called on `$cfile` only, `:101` and `:157`); `:120-134` print no line for an empty `$W/changed`, so `bash bin/review-precheck.sh u HEAD --affected x` reports `result=pass ... judge=0` with `size: files=0`; `:28-29` hide stderr only. `agents/reviewer.md:18-30` lists neither a fix-contract line nor the not-at-baseline remedy and says "reads the contract only". Sources: `.claude/reviewed/st-u2.pass` NOTE[spec] 1 and NOTE[code] 4, 5 and 6 (read with the Read tool); spec Clarifications, Open Question 7.
fix-contract-decision: run the fix contract's criteria in the script (the operator's preference), read at the commit that added it. The first commit in `<baseline>..HEAD` that touches the path is that commit (a fix contract already present at the baseline is read there). A fix contract is committed before the lead is dispatched (fast-path rule), so `not-committed` is a FAIL ground, like `contract: not-at-baseline`. Residual: a writer that commits a brand-new fix contract itself, before task-master's, would have it read at its own commit; the orchestrator dispatches the fix contract task-master committed, and the reviewer reads the path from the dispatch. A deferred fix criterion is run by hand from the fix contract (`--criterion <n>` reads the contract of record only).
baseline-decision: no sentence in `agents/orchestrator.md` or `bin/unit-bookkeeping.sh`. The baseline comes from the writer's advisory packet (`agents/lead-programmer.md` "Don't grade your own work"); `unit-bookkeeping.sh review` takes it as given and reads no contract. A fast-path contract is committed before dispatch, so the dispatch-time baseline already holds it; the not-at-baseline case is a packet that names an older commit, and the reviewer's re-run rule (edit 10) covers it without moving the decision to the orchestrator. The re-run is allowed only when `git log --oneline <baseline>..<adding commit>` shows none of the unit's commits, so no unit commit leaves the range.
stdout-guard: applies: the script sources `sensitive-paths.sh` and `unit-scope.sh`; with `echo leaked` appended to the library copy, the packet's first line was `leaked` before this unit.
glossary: "contract of record" is CONTEXT.md's term (its `_Avoid_:` line lists bare "contract"); the bullet's other mentions ("with no contract", `--contract <contract path>`) name the flag or the general case and stay.
chained: no queued contract (st-u3, st-u4, rp-u10, rp-u12, rp-u7, rp-u4, rp-u5, rp-u6, rp-u13) edits `bin/review-precheck.sh`, `tests/review-precheck.test.sh` or `agents/reviewer.md`. spec-master applied them in that order, then this contract, to a clone of the current master with a script that requires each `before:` payload once; see the spec's Dispatch section for the result.
blast-radius: bin/review-precheck.sh:7-8, :28-29, :70-75, :114, :134, :158-162; agents/reviewer.md:24-30; tests/review-precheck.test.sh:159 and :166-167. Callers: agents/reviewer.md pre-review bullet, templates/persona-protocol.md:46 (unchanged), tests/validate.sh section "review-precheck". Line numbers are at 2bccfd94.
version: .claude-plugin/plugin.json and package.json read 0.31.212 after rp-u13 if no fix round bumped; edit 11 adds one (expected 0.31.213).
mirrors: `.claude/` copies change only through `node bin/cli.js --update` (constitution P2).
commit-message: fix(rp-u14): review-precheck pins the fix contract at its commit and runs its criteria, flags an empty range, hides library output
diagnosis: none
review-packet:
~~~
unit: rp-u14
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
If a `before:` payload is not found verbatim (an st-u2 fix round may have touched the script or the test),
stop and report the current text. If a case outside (l) and (j) changes result, quote it and stop. If
`node bin/cli.js --update` reports a mirror as diverged, quote it and stop. If a gate blocks a command,
report it and wait. Anything outside "Affected files" goes to your report as a proposal.
