Unit: rfp-u1

## Objective
Before it returns FAIL, the reviewer challenges its own **judgment defects**: the defects it found by
reading code, as opposed to mechanical FAIL grounds such as a `review-precheck.sh` failure line, an
uncommitted tree, an out-of-scope path, or a command whose output shows the failure. It spawns one
foreground, unnamed `explorer` that tries to disprove each one against the whole file, its callers and the
baseline. Every REFUTED or CONFIRMED answer must carry an artifact, and the reviewer re-checks each artifact
itself. If every defect is refuted, the verdict is PASS, so no FAIL block is written and no ladder attempt is
used up. If nothing stands and some answers are UNCERTAIN, the verdict is INSUFFICIENT-CONTEXT. The pass
writes no marker.

The unit adds one bullet to `agents/reviewer.md` and one clause to its advisory-section order. It adds prose
pins for the new text and a route-gate test case proving that a reviewer may spawn `explorer` without a
review-join stamp being written. It ends with the P3 bump, the CHANGELOG entry and the regenerated `.claude/`
mirrors, all in the same commit. No hook, protocol, orchestrator or adapter file changes.

## Retrieval
Fast path, no tracker issue. Spec: `docs/plans/2026-10-27-refutation-pass.md` ("Step 1", "Context" and its
decision tables, "Cost model"). This file is the contract of record.

## Affected files
- `tests/persona-prose-pins.test.sh` (anchor: line matching `if [ "$fail" -eq 0 ]; then echo "All persona-prose-pins checks passed."; else echo "persona-prose-pins: FAILED"; fi`)
- `tests/reviewer-route-gate-caller.test.sh` (anchor: line matching `check_exit caller-empty                      ""                         reviewer 0`)
- `agents/reviewer.md` (anchors: line matching `first (if fired), then \`ubiquitous-language\` (if fired) — never precede or`; line matching `- **On FAIL (both orchestration modes)**: also write a durable`)
- `.claude-plugin/plugin.json`, `package.json`, `CHANGELOG.md`
- generated only, by `node bin/cli.js --update`: `.claude/agents/*.md` (stamp lines; reviewer also its body), `.claude/persona-protocol.md`, `.claude/persona-protocol-slim.md`, `.claude/protocol-digest.md`, the config's `fileHashes` and `pluginVersion`

## Ordered edits
1. file: `tests/persona-prose-pins.test.sh`
   anchor: line matching `if [ "$fail" -eq 0 ]; then echo "All persona-prose-pins checks passed."; else echo "persona-prose-pins: FAILED"; fi`
   indent: 0
   insert-before:
~~~
for f in agents/reviewer.md .claude/agents/reviewer.md; do
  has "$f" 'Refutation pass (before any FAIL verdict)'
  has "$f" 'Skip the refutation pass, and keep every defect as found, when any FAIL ground is mechanical'
  has "$f" 'when more than 5 judgment defects remain'
  has "$f" 'spawn `explorer` once, in the foreground and with no `name:`'
  has "$f" 're-read the whole file and its callers, not only the hunk'
  has "$f" 'when unsure, answer UNCERTAIN, never CONFIRMED'
  has "$f" 'a verdict with no artifact is UNCERTAIN'
  has "$f" 'If none stands and one or more is UNCERTAIN, return INSUFFICIENT-CONTEXT'
  has "$f" 'without a second refutation pass'
  has "$f" '`NOTE[code]: refuted: D<n>'
  has "$f" 'review gating off, in the `refutation` section instead'
  has "$f" 'a FAIL it prevents writes no `.fail` block'
  has "$f" 'then `refutation` (if run)'
  hasnot "$f" 'refuter'
done
~~~
   Run `bash tests/persona-prose-pins.test.sh`: it must now exit 1, with 26 `FAIL` lines for the two reviewer
   files (the `hasnot` pins already pass). This is the red step.
2. file: `tests/reviewer-route-gate-caller.test.sh`
   anchor: line matching `check_exit caller-empty                      ""                         reviewer 0`
   indent: 0
   insert-after:
~~~

# The refutation pass (agents/reviewer.md): a reviewer may spawn the explorer,
# and that nested dispatch writes no review-join stamp (rfp-u1).
check_exit caller-reviewer-target-explorer   reviewer                   explorer 0
if ls "$tmproot/caller-reviewer-target-explorer/.claude"/.review-join.* >/dev/null 2>&1; then
  echo "FAIL (caller-reviewer-target-explorer-no-stamp) a review-join stamp was written"
  fail=1
else
  echo "OK   (caller-reviewer-target-explorer-no-stamp) no review-join stamp"
fi
~~~
   This case is green today. It pins a premise the pass depends on (see criterion 3's mutation).
3. file: `agents/reviewer.md`
   before: `first (if fired), then \`ubiquitous-language\` (if fired) — never precede or`
   after: `first (if fired), then \`ubiquitous-language\` (if fired), then \`refutation\` (if run) — never precede or`
   (one line, :141 at 1073743d; the `before:` text occurs exactly once)
4. file: `agents/reviewer.md`
   anchor: line matching `- **On FAIL (both orchestration modes)**: also write a durable`
   indent: 0
   insert-before:
~~~
- **Refutation pass (before any FAIL verdict)**: a judgment defect (one you
  found by reading, not a `review-precheck.sh` failure line, an uncommitted
  tree, an out-of-scope path, or a command you ran whose output shows the
  failure; those are mechanical and are never sent) does not reach a FAIL
  verdict unchallenged. Merge duplicates (same `file:line` or same cause)
  first. Skip the refutation pass, and keep every defect as found, when any
  FAIL ground is mechanical, when more than 5 judgment defects remain, on a
  resume after an INSUFFICIENT-CONTEXT the pass caused, or when no subagent
  can be spawned. Otherwise spawn `explorer` once, in the foreground and
  with no `name:`, giving it the baseline, the changed files and one
  `D<n>: <file:line> <claim>` line per judgment defect, and ask it to
  disprove each: re-read the whole file and its callers, not only the hunk,
  and answer (1) does the issue exist at the cited line, (2) is it in the
  change or already at the baseline (`git show <baseline>:<file>`), (3) is
  the impact real or already mitigated by a guard, an earlier validation or
  config elsewhere, one line each:
  `D<n>: REFUTED|CONFIRMED|UNCERTAIN — artifact: <command and output line, or file:line quote>`.
  Tell it: when unsure, answer UNCERTAIN, never CONFIRMED, and a verdict
  with no artifact is UNCERTAIN. Re-check each artifact yourself (read the
  line, re-run the command); a defect whose artifact does not reproduce, or
  that got no answer line, stands as found. A defect already at the
  baseline is REFUTED unless it is an unmet acceptance criterion. If any
  defect stands or is CONFIRMED, return FAIL with only those, and list the
  REFUTED and UNCERTAIN ones in the `refutation` advisory section. If none
  stands and one or more is UNCERTAIN, return INSUFFICIENT-CONTEXT, its
  `missing:` naming the evidence that would settle each (a judgment you
  cannot authoritatively determine); on the resume, decide FAIL or PASS
  without a second refutation pass, and a defect still without an artifact
  becomes a `NOTE[code]: unconfirmed:` line, not a FAIL ground. If all are
  REFUTED, apply the PASS rules (escalation included) and add one
  `NOTE[code]: refuted: D<n> <claim> — <artifact>` line per defect (under
  review gating off, in the `refutation` section instead). The pass writes
  no marker; a FAIL it prevents writes no `.fail` block, so the FAIL-block
  count and the Escalation ladder only count FAILs that survived it.
~~~
   This is 34 lines. Do not reflow it: criterion 4 budgets the reviewer.md diff at 36 added lines and 1
   removed line.
5. command: `perl -0pi -e 's/("version": "\d+\.\d+\.)(\d+)"/$1.($2+1)."\""/e' .claude-plugin/plugin.json package.json`
   expect: 0
   This adds one to the patch version in both files: 0.31.219 to 0.31.220 at 1073743d, or +1 on whatever is
   current at dispatch.
6. file: `CHANGELOG.md`
   anchor: line matching `## [Unreleased]`
   indent: 0
   insert-after:
~~~

**Reviewer refutation pass (rfp-u1, VERSION).** `agents/reviewer.md` gains "Refutation pass (before any FAIL verdict)": before a FAIL whose grounds are all judgment defects (1 to 5 after deduplication), the reviewer spawns one foreground, unnamed `explorer` to disprove each against the whole file, its callers and the baseline; REFUTED and CONFIRMED answers need an artifact the reviewer re-checks; all refuted means PASS with `NOTE[code]: refuted:` lines and no FAIL block, nothing standing with UNCERTAIN left means INSUFFICIENT-CONTEXT. Mechanical FAIL grounds are never sent. The pass writes no marker; the FAIL-block count, the Escalation ladder, the hooks, the orchestrator and the adapter ports are unchanged. `tests/persona-prose-pins.test.sh` pins the bullet and `tests/reviewer-route-gate-caller.test.sh` pins that a reviewer may spawn `explorer` with no review-join stamp. Spec: `docs/plans/2026-10-27-refutation-pass.md`.
~~~
   Replace `VERSION` with the version that edit 5 wrote.
7. command: `node bin/cli.js --update`
   expect: 0
8. command: `bash -c 'bash tests/persona-prose-pins.test.sh >/dev/null && bash tests/reviewer-route-gate-caller.test.sh >/dev/null; echo $?'`
   expect: stdout `0`
9. command: `git add tests/persona-prose-pins.test.sh tests/reviewer-route-gate-caller.test.sh agents/reviewer.md .claude-plugin/plugin.json package.json CHANGELOG.md && git add -u -- .claude ':(exclude).claude/agent-memory' && git commit -m "feat(rfp-u1): the reviewer runs a refutation pass on its judgment defects before any FAIL verdict"`
   expect: 0
   Run `git status --short` first. If a tracked file outside "Affected files" is modified, stop and report it.
   Every later commit of this unit that touches `agents/` (a fix round) repeats edits 5 to 7 in that same
   commit and keeps `(rfp-u1)` in its subject. Constitution P3 is checked per commit (criterion 6).

## Do NOT touch
- `agents/orchestrator.md`, `agents/explorer.md`, `agents/task-master.md` (the routing does not change; criterion 5)
- `templates/` (the FAIL-record format and the INSUFFICIENT-CONTEXT section do not change; criterion 5)
- `hooks/` and `.claude/hooks/` (the route and stop gates already admit the nested spawn; criterion 5)
- `adapters/` (the codex and cursor reviewer ports have no verified spawn primitive and keep today's FAIL path; criterion 5)
- `bin/` (no change to `ladder-tier.sh`, `fail-count.sh` or `review-precheck.sh`; criterion 5)
- `CONTEXT.md` and `docs/adr/` (rfp-u2, the scribe's unit; criterion 5)
- `.claude/agents/` and `.claude/` mirrors by hand (only `node bin/cli.js --update` writes them)

## Acceptance criteria
1. run: `bash -c 'bash tests/persona-prose-pins.test.sh | grep -ciE "^ok +(\.claude/)?agents/reviewer\.md .*(refut|uncertain|judgment defects remain|explorer|whole file|it prevents writes)"; true'`
   exit: 0
   stdout: `28`
   mutation: delete edit 4's bullet and re-run `--update`; only the two `(absent) refuter` lines still match, so stdout is `2`.
2. run: `bash -c 'bash tests/persona-prose-pins.test.sh >/dev/null; echo $?'`
   exit: 0
   stdout: `0`
   mutation: skip edit 7 (`--update`); the 13 `.claude/agents/reviewer.md` `has` pins fail and stdout is `1`.
3. run: `bash -c 'out=$(bash tests/reviewer-route-gate-caller.test.sh 2>&1); rc=$?; printf "%s\n" "$out" | grep -c "^OK   (caller-reviewer-target-explorer"; echo "rc=$rc"'`
   exit: 0
   stdout: `2` then `rc=0`
   mutation: copy `hooks/scripts/reviewer-route-gate.sh` and `hooks/scripts/lib/` to a scratch directory, replace `if [ -f "$config" ] && persona_matches_gate "$target_type" reviewer; then` with `if [ -f "$config" ]; then` in the copied core, and run the suite with `GATE_UNDER_TEST=<scratch>/reviewer-route-gate.sh`. The no-stamp case prints `FAIL`, so stdout is `1` then `rc=1`. spec-master ran this mutation on a scratch copy.
4. run: `bash -c 'b=$(git log --format=%H --grep="(rfp-u1)" | tail -1); l=$(git log --format=%H --grep="(rfp-u1)" | head -1); [ -n "$b" ] || { echo no-commits; exit 1; }; git diff --numstat "$b^..$l" -- agents/reviewer.md | awk "{print (\$1<=36 && \$2<=1) ? \"ok\" : \"over \" \$1 \" \" \$2}"'`
   exit: 0
   stdout: `ok`
   mutation: paste edit 4's payload twice; stdout is `over 69 1`.
5. run: `bash -c 'b=$(git log --format=%H --grep="(rfp-u1)" | tail -1); l=$(git log --format=%H --grep="(rfp-u1)" | head -1); [ -n "$b" ] || { echo no-commits; exit 1; }; git diff --name-only "$b^..$l" -- agents/orchestrator.md agents/explorer.md agents/task-master.md templates hooks adapters bin CONTEXT.md docs/adr | wc -l'`
   exit: 0
   stdout: `0`
   mutation: edit `adapters/cursor/agents/reviewer.md` in an rfp-u1 commit; stdout is at least `1`.
6. run: `bash -c 'b=$(git log --format=%H --grep="(rfp-u1)" | tail -1); l=$(git log --format=%H --grep="(rfp-u1)" | head -1); [ -n "$b" ] || { echo no-commits; exit 1; }; bash hooks/scripts/version-stamp-check.sh "$b^..$l" | cut -d" " -f1-4'`
   exit: 0
   stdout: `version-stamp-check: ok touched: yes`
   mutation: skip edit 5; stdout reads `version-stamp-check: violation touched: yes`.
7. run: `bash -c 'bash tests/validate.sh >/dev/null 2>&1; echo $?'` (Bash tool timeout 600000 ms)
   exit: 0
   stdout: `0`
   mutation: put `exit 1` as line 2 of `tests/persona-prose-pins.test.sh`; validate.sh (:1571) reports it and stdout is `1`.

## Pre-resolved context
- Route gate: `hooks/scripts/lib/reviewer-route-gate-core.sh:78` scopes the name check and the review-join
  stamp to `reviewer` targets. :37-52 block only `gatedAgents` targets. A reviewer-to-explorer spawn exits 0
  and writes no stamp; spec-master ran the edit 2 case on a scratch copy and it printed `OK` twice.
  Reviewer-to-reviewer is refused (`tests/reviewer-route-gate-caller.test.sh:66`).
- Markers: `hooks/scripts/reviewed-path-gate.sh:249` grants `.claude/reviewed/` writes to the reviewer only.
  `explorer` is denied at :292-299 and has no Write/Edit tool.
- Explorer: `agents/explorer.md` frontmatter is `model: haiku`, `effort: low`, `maxTurns: 10`, with no
  `Agent` tool. Spawn it by the explicit name `explorer`, never `Explore`. Leave `name:` unset: a named
  dispatch launches as a teammate while agent teams are enabled.
- Every pin phrase in edit 1 was checked against a scratch copy of `agents/reviewer.md` with edits 3 and 4
  applied: each matches once after `tr -s ' \n' ' '`, none matches at 1073743d, and the flattened file
  contains no `refuter`.
- No test pins the text around "On FAIL (both orchestration modes)" or "INSUFFICIENT-CONTEXT" in
  `agents/reviewer.md`. The edit 4 payload contains no blank line and no `## ` heading, so
  `tests/fail-marker-format-parity.test.sh` and `tests/protocol-doc-drift.test.js` are unaffected.
- The reviewer's scope check excludes `.claude`, so the regenerated mirrors are never out-of-scope paths.
- blast-radius: `agents/reviewer.md:141` (edit 3) and `:241` (edit 4's anchor). The installed copy
  `.claude/agents/reviewer.md` is one line lower (stamp at :13). `tests/persona-prose-pins.test.sh` sits
  before its final `if` line. `tests/reviewer-route-gate-caller.test.sh:71`.

## Escalation
If a `before:` or anchor text is not found exactly once, stop and report the current text. If
`node bin/cli.js --update` refuses (for example on its cross-reference assertion), quote its message and
stop. If a gate blocks a command, report it and wait. If the unit needs a change in any `## Do NOT touch`
path, that is a spec gap: report it, do not make the edit. Anything else outside "Affected files" goes in
your report as a proposal.
