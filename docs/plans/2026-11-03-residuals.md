# Residuals after 0.32.0-0.34.0 (2026-11-03)

Slug `residuals`, unit prefix `rs-`. Plan dir `docs/plans/2026-11-03-residuals/` (appendix, contracts).
Baseline for every fact below: `b93658d3`.

## Goal

User request (2026-11-02, authoritative): close the residual findings left after 0.32.0-0.34.0 (ten
numbered items), record the two user-accepted residuals, ship as 0.35.0. After this plan:
- G1 (item 1). A `SIGTERM`, `SIGINT` or `SIGHUP` that reaches `dispatch-hygiene.sh` never moves the
  writer-dispatch stamp.
- G2 (item 2). `unit-bookkeeping.sh check` escalates when the repo holds a submodule.
- G3 (item 3). A false `Review gating: off` header no longer withholds markers: the reviewer confirms `off`
  from the config before it skips a marker write.
- G4 (item 4). The token-usage scripts attribute a `roast-work`-only transcript to the reviewer.
- G5 (item 5, item 7 code comment, item 9). Stale lib text is fixed in all four copies, the no-script
  fallback message stops prescribing a hand-written flag line, and a failed route-gate rewrite is tested.
- G6 (items 6, 7, 10). ADR, wiki, glossary and CHANGELOG text match the code; each residual this plan does
  not fix is recorded as accepted, with its reason.

## Decisions

- **D1 Already closed at baseline (no unit).** Item 8: zero criteria (`bin/unit-bookkeeping.sh:170`
  `no-criteria`), `sensitive:` lines (:137-139), non-numeric judge (:132 regex needs digits), C7 cwd (:186
  `cd` to the top), inner precheck stdin (:154 `</dev/null`), flag TOCTOU and symlink (:214 `! -L`, :217
  `dd conv=notrunc,nocreat`), `unit-size.sh --at-least` after `--contract` (`bin/unit-size.sh:34`, exit 2).
  Item 10 "moves to medium covers only fail": `templates/persona-protocol.md:250` names the flag, `fail`,
  `escalate` and no `check:` line. Item 6 lines 15-16: the l2-ttl bullet already reads "$6.0 net ... $10.1
  gross less $4.1" and l2-slim gives 24,917 and 42,940 (fixed by l2-release).
- **D2 Accepted, recorded only (rs-docs writes them into ADR-0046).** (a) No pre-block on Bash writes to
  protected paths (user). (b) A writer deleting its own flag after its last stop (user). (c) `check`'s total
  run time can pass the 600 s Bash ceiling (precheck plus deferred re-runs, 590 s each); the cancelled call
  prints no `check:` line, which the protocol already routes to `medium`, so it fails closed. (d) The
  dashboard views lost with `decisions.js` (plan excerpt browser, milestone-auditor paste-back, defer/skip
  composer): not trivially restorable, since commit 2c1e5a2a also rewrote `discover.js` and 647 lines of
  `index.html`. (e) rv-routemark contract criterion 3's expected exit code (1, really 2): that contract is
  spent and the mutation was caught either way; no action.
- **D3 Signals (item 1).** Three traps after `trap sg_exit EXIT` set `sg_stamp_due=0` and exit 143, 130, 129.
  Reproduced at baseline: a jq shim that signals the hook at its `dispatchHygiene.mode` read leaves the stamp
  moved for all three signals (rc 143/130/129); with the traps in a scratch copy, none moves it.
- **D4 Submodules (item 2).** Escalate `submodule` when `git ls-files -s` lists a mode-160000 entry or fails,
  rather than scanning inside each submodule: a submodule repo loses the small lane, never the review. This
  repo has no gitlinks, so its own small units are unaffected.
- **D5 Gating header (item 3).** Off is the unsafe direction, so the reviewer runs the one `jq` command when
  the header says `off` as well as when it is absent; `enforce` in the header is still trusted. The same edit
  drops "or wrong" from the run-the-checks bullet (l2-revprose note: the reviewer cannot tell "wrong"
  without the inspection the sentence forbids). Ports keep reading the key directly; untouched.
- **D6 `Mode: advisory` (item 10): prose-only, reviewer-honoured.** No hook reads it (dispatch-hygiene.sh:77)
  and enforcing it would add hook code with no other consumer. The reviewer's gating bullet gains "or for a
  dispatch whose second non-blank line is `Mode: advisory`" (advisory verdict, no marker); the glossary
  entries that say the route gate reads it or writes an advisory stamp are corrected. The orchestrator text
  and its pin (`tests/reviewer-dispatch-line-order.test.js`) stay.
- **D7 Fallback message (item 5).** Without `unit-bookkeeping.sh`, the unrecognized-namespace text becomes
  "ask the user to add a first line 'defer: <reason>' or 'skip: <reason>' to a flag that exists." The
  script branch keeps its text and pin `(l2-g1)`; pin `(l2-g2)` moves to the new text.
- **D8 Budgets.** No unit touches `agents/orchestrator.md` (16,361 of 16,384 bytes). `agents/reviewer.md`
  (24,430) may grow by at most 200 bytes. `tests/abtest-arms.test.sh` stays untouched. Mirrors only through
  `node bin/cli.js --update --force-render`, and the writer commits all of its output.
- **D9 Co-located adds.** rs-release also fixes the 0.34.0 l2-abfix bullet "`(l2-a1)` to `(l2-a4)`" to
  `(l2-a7)` (pins a5-a7 exist in `tests/abtest-row.test.sh`, `tests/abtest-stream.test.sh`; l2-abfix note).
- **D10 Order.** rs-stamp, rs-corelib, rs-check, rs-tokens, rs-prose, rs-docs, rs-release, one at a time.
  Every unit but rs-release adds one `[Unreleased]` CHANGELOG bullet naming its id. rs-docs runs after the
  code units because it records their closures.

## Units

Every unit's last criterion: `bash tests/validate.sh >/dev/null 2>&1` (Bash tool timeout 600000 ms), exit
0. Every unit that changes a rendered source also has: `node bin/cli.js --update --force-render >/dev/null
&& git diff --quiet -- .claude adapters ':!.claude/agent-memory'`, exit 0 (mutation: mirror left stale →
exit 1). CHANGELOG criterion: `sed -n '/^## \[Unreleased\]/,/^## \[0\.34\.0\]/p' CHANGELOG.md | grep -c
'<id>'` → `1`.

### 1. rs-stamp: signals never move the writer-dispatch stamp (item 1)
Files: `hooks/scripts/dispatch-hygiene.sh`, `tests/dispatch-hygiene.test.sh`, `CHANGELOG.md`, `.claude/`
copies. Do NOT touch `hooks/scripts/lib/`, `bin/`. Per D3; update header item 0a and the :174-175 comment.
Tests `(rs-s1)` TERM, `(rs-s2)` INT, `(rs-s3)` HUP: jq PATH shim signals the hook at its mode read, each run
in a subshell (an `INT` child otherwise aborts the test script), stamp pre-set to 2026-01-01 stays.
1. run: `o=$(bash tests/dispatch-hygiene.test.sh 2>&1); r=$?; grep '^OK ' <<<"$o" | grep -oE '\(rs-s[1-3]\)' | sort -u | wc -l | tr -d ' '; exit $r`
   → `3`; mutation: drop the three traps → FAIL, exit 1.
2. run (standalone repro, measured at baseline): `S=$(mktemp -d); mkdir $S/b; printf '#!/bin/bash\ncase "$*" in *dispatchHygiene.mode*) kill -$SIG $HYG_PID; sleep 0.3;; esac\nexec %s "$@"\n' "$(command -v jq)" > $S/b/jq; chmod +x $S/b/jq; r=; for g in TERM INT HUP; do c=$S/$g/.claude; mkdir -p $c/reviewed; echo '{}' > $c/persona-config.json; touch -d 2026-01-01 $c/reviewed/.writer-dispatch-stamp; (jq -cn '{tool_name:"Agent",tool_input:{subagent_type:"lead-programmer",prompt:"do it"}}' | SIG=$g PATH=$S/b:$PATH CLAUDE_PROJECT_DIR=$S/$g bash -c 'export HYG_PID=$$; exec bash hooks/scripts/dispatch-hygiene.sh' >/dev/null 2>&1); r="$r $g $(find $c/reviewed/.writer-dispatch-stamp -newermt 2026-01-02 | wc -l)"; done; echo $r`
   → `TERM 0 INT 0 HUP 0`; mutation: baseline code → `TERM 1 INT 1 HUP 1`.
3. CHANGELOG, mirror, validate.

### 2. rs-corelib: lib text, fallback message, failed-rewrite test (items 5, 7, 9)
Files: `hooks/scripts/lib/stop-gate-core.sh`, `hooks/scripts/lib/state-access.sh`, `tests/stop-gate.test.sh`,
`tests/reviewer-route-gate-caller.test.sh`, `CHANGELOG.md`, `.claude/` and `adapters/` copies. Do NOT touch
`hooks/scripts/*.sh` entries, `bin/`. (a) `stop-gate-core.sh:30` "at each gated dispatch" → "at each
allowed gated dispatch". (b) D7. (c) The comment above `state_replace_pending_review` (`state-access.sh:110`)
ends "...with a 644 file; the fallback create after a mktemp or mv failure uses the umask." (d) `(rs-r1)`: an
allowed reviewer dispatch with `.claude` made read-only (`chmod a-w`, SKIP as root, restored for cleanup)
leaves a plain flag's first line unchanged, rc 0, no `review-dispatched flags=` log line.
1. run: `for d in hooks/scripts/lib .claude/hooks/scripts/lib adapters/codex/hooks/scripts/lib adapters/cursor/hooks/scripts/lib; do echo $(grep -c 'at each allowed gated dispatch' $d/stop-gate-core.sh) $(grep -c 'into a flag that exists' $d/stop-gate-core.sh) $(grep -c 'uses the umask' $d/state-access.sh); done | sort -u`
   → `1 0 1`; mutation: one copy stale → a second line `0 1 0`.
2. run: `o=$(bash tests/stop-gate.test.sh 2>&1); r=$?; grep -c "^OK   (l2-g2)" <<<"$o"; grep -c 'ask the user to add a first line' tests/stop-gate.test.sh; exit $r`
   → `1` then `1`; mutation: old message kept → `(l2-g2)` FAIL, exit 1.
3. run: `o=$(bash tests/reviewer-route-gate-caller.test.sh 2>&1); r=$?; grep -c '^OK   (rs-r1)' <<<"$o"; exit $r`
   → `1`; mutation: on mktemp failure write the mark in place (`> "$flag"`) → FAIL, exit 1.
4. CHANGELOG, mirror, validate.

### 3. rs-check: escalate on submodules (item 2)
Files: `bin/unit-bookkeeping.sh`, `tests/unit-bookkeeping.test.sh`, `CHANGELOG.md`, `.claude/` copies. Do
NOT touch `hooks/`, `bin/review-precheck.sh`. Per D4, right after the `index-flags` rule; extend the C1-C2c
comment. `(rs-k1)`: a fixture whose HEAD commits a gitlink (`git update-index --add --cacheinfo
160000,<sha>,sub`) → `check: escalate unit=ue reason=submodule`; `(l2-k3)` still passes.
1. run: `o=$(bash tests/unit-bookkeeping.test.sh 2>&1); r=$?; grep -c '^OK   (rs-k1)' <<<"$o"; exit $r`
   → `1`; mutation: drop the rule → FAIL, exit 1.
2. run: `grep -c 'finish escalate submodule' bin/unit-bookkeeping.sh .claude/bin/unit-bookkeeping.sh`
   → `bin/unit-bookkeeping.sh:1` then `.claude/bin/unit-bookkeeping.sh:1`; mutation: mirror stale → `:0`.
3. CHANGELOG, mirror, validate.

### 4. rs-tokens: reviewer attribution by `roast-work` (item 4)
Files: `scripts/token-usage/agg.py`, `scripts/token-usage/agg2.py`, `scripts/token-usage/cache.py`,
`tests/token-usage.test.sh`, `tests/fixtures/token-usage-roast/`, `CHANGELOG.md`. Do NOT touch
`tests/fixtures/token-usage/` (its medians are pinned). Add `frozenset(['antislop:roast-work']): 'reviewer'`
to each signature map; keep the old pair (older transcripts). New fixture: one reviewer subagent transcript
whose only `<command-name>` is `antislop:roast-work`, with no parent Agent tool_use. `(rs-t1)` agg.py,
`(rs-t2)` agg2.py, `(rs-t3)` cache.py attribute it to `reviewer`.
1. run: `grep -c "frozenset(\['antislop:roast-work'\]): 'reviewer'" scripts/token-usage/agg.py scripts/token-usage/agg2.py scripts/token-usage/cache.py`
   → three lines ending `:1`; mutation: cache.py entry missing → `cache.py:0`.
2. run: `o=$(bash tests/token-usage.test.sh 2>&1); r=$?; grep '^ok ' <<<"$o" | grep -oE 'rs-t[1-3]' | sort -u | wc -l | tr -d ' '; exit $r`
   → `3`; mutation: agg2.py entry missing → `2`, exit 1.
3. CHANGELOG, validate.

### 5. rs-prose: reviewer gating header, `Mode: advisory`, spec-master example (items 3, 10)
Files: `agents/reviewer.md`, `agents/spec-master.md`, `tests/persona-prose-pins.test.sh`, `CHANGELOG.md`,
`.claude/` copies. Do NOT touch `agents/orchestrator.md`, `adapters/`, `hooks/`, `bin/`. Per D5/D6:
reviewer.md:95 "if a header line is absent or wrong, check for yourself" → "if a header line is absent, or
the `Review gating:` line says `off`, check for yourself"; :181 "only when it is absent, read the key with"
→ "when it is absent or says `off`, read the key with"; "Under `off` your verdict is advisory" → "Under
`off`, or for a dispatch whose second non-blank line is `Mode: advisory`, your verdict is advisory".
spec-master.md:199 "even when true. Example:" → "even when true. Example (in `appendix.md`):". Pins: `has`
the three new reviewer phrases and `hasnot` the two old ones, for both reviewer copies.
1. run: `echo $(for f in agents/reviewer.md .claude/agents/reviewer.md; do t=$(tr -s ' \n' ' ' < $f); for p in 'or the `Review gating:` line says `off`, check for yourself' 'when it is absent or says `off`, read the key with' 'second non-blank line is `Mode: advisory`, your verdict is advisory' 'absent or wrong' 'only when it is absent, read the key'; do grep -cF -- "$p" <<<"$t"; done; done)`
   → `1 1 1 0 0 1 1 1 0 0`; mutation: mirror stale → second half `0 0 0 1 1`.
2. run: `bash tests/persona-prose-pins.test.sh >/dev/null; echo $? $(grep -cF 'Mode: advisory' tests/persona-prose-pins.test.sh)`
   → `0 1`; mutation: revert reviewer.md → `1 1`.
3. run: `[ "$(wc -c < agents/reviewer.md)" -le 24630 ] && echo ok` → `ok`; mutation: +300 bytes → exit 1.
4. run: `grep -c 'even when true. Example (in `appendix.md`):' agents/spec-master.md .claude/agents/spec-master.md`
   → both `:1`; mutation: mirror stale → `.claude/agents/spec-master.md:0`.
5. CHANGELOG, mirror, validate.

### 6. rs-docs: ADRs, wiki, glossaries (items 7, 10; records D2)
Files: `docs/adr/0045-reviewer-by-lane.md`, `docs/adr/0046-lean-pipeline-2.md`, `.claude/wiki/architecture.md`,
`.claude/wiki/changelog.md`, `CONTEXT.md`, `docs/harness-glossary.md`, `CHANGELOG.md`. Do NOT touch `agents/`,
`hooks/`, `bin/`, `tests/`. ADR-0045 Accepted residuals gain a status note on the `--skip-worktree` line:
closed by ADR-0046 except the submodule case, closed by rs-check. architecture.md "Retired (0.32.0)" line:
"the human-decision gate are gone" → retired, the gate a registered stub. ADR-0046: :11 "a one-line or
one-row edit" → "a small, test-pinned edit"; :18 "deletes a non-empty sentinel" → "deletes any sentinel,
empty or not,"; :19 "with a mode-644 file" → "with a mode-644 file on the main path; the fallback create after
a mktemp or mv failure uses the umask". Its residual list marks each closure with its unit id (rs-stamp,
rs-check, rs-tokens, rs-corelib for :30, rs-prose for the D5 correction) and adds D2 (a)-(d), each ending
"Accepted (2026-11-03 residuals plan)." Citations: wiki changelog `review-precheck.sh:192-198` →
`:193-199`, `unit-scope.sh:19-35` → `:19-40`; CONTEXT.md and glossary `reviewed-path-gate.sh:36` →
`:36-37`. Glossary: **advisory dispatch** drops "the machine-readable form `reviewer-route-gate-core.sh`
reads" for "prose only: no hook reads it; the reviewer writes no marker for it"; **advisory review-join
stamp** gains "Retired (lp-joinstamp): no hook writes it."
1. run: `grep -F 'closed by ADR-0046' docs/adr/0045-reviewer-by-lane.md | grep -c submodule` → `1`; mutation: no note → `0`, exit 1.
2. run: `a=.claude/wiki/architecture.md; echo $(grep -cF 'human-decision gate are gone' $a) $(grep -F 'Retired (0.32.0)' $a | grep -c stub)` → `0 1`; mutation: old line → `1 0`.
3. run: `f=docs/adr/0046-lean-pipeline-2.md; echo $(grep -c 'deletes a non-empty sentinel' $f) $(grep -c 'one-line or one-row edit' $f) $(grep -c 'small, test-pinned edit' $f) $(grep -c 'uses the umask' $f) $(grep -c 'Accepted (2026-11-03 residuals plan)\.' $f)` → `0 0 1 1 4`; mutation: one accepted item missing → last `3`.
4. run: `f=docs/adr/0046-lean-pipeline-2.md; n=0; for u in rs-stamp rs-check rs-tokens rs-corelib rs-prose; do grep -q "$u" $f && n=$((n+1)); done; echo $n` → `5`; mutation: rs-tokens unrecorded → `4`.
5. run: `w=.claude/wiki/changelog.md; g="CONTEXT.md docs/harness-glossary.md"; echo $(grep -c 'review-precheck.sh:192-198\|unit-scope.sh:19-35' $w) $(grep -c 'review-precheck.sh:193-199' $w) $(grep -c 'unit-scope.sh:19-40' $w) $(cat $g | grep -c 'reviewed-path-gate.sh:36`') $(cat $g | grep -c 'reviewed-path-gate.sh:36-37`')` → `0 1 1 0 2`; mutation: glossary cite unchanged → `0 1 1 1 1`.
6. run: `t=$(tr -s ' \n' ' ' < docs/harness-glossary.md); echo $(grep -cF 'machine-readable form `reviewer-route-gate-core.sh` reads' <<<"$t") $(grep -oF 'no hook reads it; the reviewer writes no marker for it' <<<"$t" | wc -l) $(grep -oF 'Retired (lp-joinstamp): no hook writes it.' <<<"$t" | wc -l)` → `0 1 1`; mutation: entry unchanged → `1 0 1`.
7. CHANGELOG, validate.

### 7. rs-release: 0.35.0 (item 6)
Files: `.claude-plugin/plugin.json`, `package.json`, `CHANGELOG.md`, `.claude/` re-stamps from `--update`.
Do NOT touch anything else. One commit `chore(rs-release): release 0.35.0`: version 0.35.0 in both files;
`## [0.35.0] - <date>` below `## [Unreleased]` with one residuals bullet over the six unit bullets. In 0.34.0:
"and retires `.escalated`" → "and finishes retiring the `.escalated` wording"; add a `(l2-scribe)` bullet
(glossary entries, ADR-0046, wiki changelog, retired-name notes; commit d87cbc5d); D9.
1. run: `cat .claude-plugin/plugin.json package.json | grep -c '"version": "0.35.0",'` → `2`; mutation: one unbumped → `1`.
2. run: `grep -nE '^## \[' CHANGELOG.md | head -2 | sed -E 's/ - [0-9-]{10}$/ - D/'` → `3:## [Unreleased]` then `5:## [0.35.0] - D`; mutation: no heading → `[0.34.0]` second.
3. run: `s=$(sed -n '/^## \[0\.35/,/^## \[0\.34/p' CHANGELOG.md); n=0; for u in stamp corelib check tokens prose docs; do grep -qw "rs-$u" <<<"$s" && n=$((n+1)); done; echo $n` → `6`; mutation: heading below one bullet → `5`.
4. run: `c=$(git log -1 --format=%H -F --grep='(rs-release)'); [ -n "$c" ] || exit 1; bash hooks/scripts/version-stamp-check.sh "$c^..$c" | cut -d' ' -f1,2` → `version-stamp-check: ok`; mutation: no heading → `violation`.
5. run: `git grep -lE 'antislop v0\.34\.|"pluginVersion": "0\.34\.' -- .claude | wc -l` → `0`; mutation: skip `--update` → non-zero.
6. run: `g="-F --grep=(rs-release)"; echo $(git log --oneline $g | wc -l) $(git log --format= --name-only $g | grep . | grep -vxcE '\.claude-plugin/plugin\.json|package\.json|CHANGELOG\.md|\.claude/.+')` → `1 0`; mutation: also commit `agents/scribe.md` → `1 1`.
7. run: `s=$(sed -n '/^## \[0\.34/,/^## \[0\.33/p' CHANGELOG.md); echo $(grep -c 'and retires `.escalated`' <<<"$s") $(grep -c '(l2-scribe)' <<<"$s") $(grep -c '`(l2-a1)` to `(l2-a7)`' <<<"$s")` → `0 1 1`; mutation: no l2-scribe bullet → `0 0 1`.
8. mirror, validate.

## Open Questions

None. Items 3, 10 (`Mode: advisory`) and the fallback text (D5-D7) carry recommended defaults the user may
override before dispatch: (1) D6 alternative: drop the convention and its pin instead; (2) D4 alternative:
scan inside each submodule instead of escalating.

## Dispatch

Contracts, in dispatch order (committed before dispatch): [rs-stamp](2026-11-03-residuals/contracts/rs-stamp.md),
[rs-corelib](2026-11-03-residuals/contracts/rs-corelib.md), [rs-check](2026-11-03-residuals/contracts/rs-check.md),
[rs-tokens](2026-11-03-residuals/contracts/rs-tokens.md), [rs-prose](2026-11-03-residuals/contracts/rs-prose.md),
[rs-docs](2026-11-03-residuals/contracts/rs-docs.md), [rs-release](2026-11-03-residuals/contracts/rs-release.md).

## Scribe update hint

rs-docs is the knowledge unit. Knowledge proposals (not applied by spec-master): `docs/harness-glossary.md`
**marker check** and **writer-dispatch stamp** could name the signal case (rs-stamp); **small-lane check**
could list the `submodule` escalation (rs-check). No new ADR: D3-D7 each revert in a small, test-pinned edit.
