Unit: rp-u3

## Objective
Findings C and D, plus the qw-u4 review addendum (2026-10-20). After this unit:
- `bin/unit-bookkeeping.sh dispatch` forces `model: opus` when the ladder helper exits non-zero, even if
  it printed a tier, except that `EXHAUSTED` stays `EXHAUSTED` (the exhaustion stop routes to the human
  and must never become a dispatch); `review` already does the same for the reviewer-tier helper. The
  usage line names `review <unit> <baseline> [--implementer-tier <t>]`. The header's `Range:` line is two
  full SHAs (`git rev-parse` of the baseline), even for a short or symbolic baseline such as `HEAD~1`.
- `agents/reviewer.md` points the auto-suffix residual at `docs/orchestrator-rationale.md`, "N1: reviewer
  dispatch naming, the unobserved residual", where qw-u2 moved it, instead of the orchestrator's
  "Dispatch naming" section.
- The codex and cursor orchestrator ports say the same as `agents/orchestrator.md` about the scribe under
  review gating off: "When you dispatch scribe, quote each unit's reviewer PASS verdict line verbatim in
  that dispatch; scribe closes an issue only on its own quoted line."
- `tests/prompt-diet-pins.test.sh` pins: the reviewer pointer; the orchestrator's sentence pointing to the
  `start-feature-team` command; qw-u4's unpinned safety phrases (orchestrator stub: "ask through one
  `AskUserQuestion` call" and the "If that section cannot be read ..." fallback; protocol subsection:
  "never retry or rephrase the write", "Write only from this session's answer", "never pick one for them",
  "Do not relay the decision in the prompt"); the port scribe sentence; and the absence of three more
  narratives qw-u3 removed ("not an exemption", "Not an alternative to the WIP sentinel", "a complementary
  safety layer"). These pins read the current files, not git history.
This is spec Step 3.

## Retrieval
Fast path, no tracker issue. Spec: `docs/plans/antislop-review-patches/spec.md`, "Step 3 (rp-u3)" and
"Context", findings C and D, and the qw-u4 addendum. This file is the contract of record. Dispatch after
rp-u2; no queued contract edits these files or the pinned sentences.

## Affected files
- `tests/unit-bookkeeping.test.sh` (anchor: line matching `exit "$fail"`, the last line)
- `bin/unit-bookkeeping.sh` (anchors: line matching `usage() { echo "usage: unit-bookkeeping.sh dispatch`; line matching `  local unit="$2" contract="" ladder="${UB_LADDER:-$dir/ladder-tier.sh}" line tier`; line matching `  line="$(bash "$ladder" "${args[@]}" | head -n1)"`; line matching `  echo "Range: $base..$(git rev-parse HEAD)"`)
- `tests/prompt-diet-pins.test.sh` (anchor: line matching `# Later units append their rows below this line.`)
- `agents/reviewer.md` (anchor: line matching `  If the marker-write attempt is refused because a gate names an identity`)
- `adapters/codex/agents/orchestrator.toml`, `adapters/cursor/agents/orchestrator.md` (anchor: line matching `milestone audit gate. When you dispatch scribe for a unit, quote the`)
- `.claude-plugin/plugin.json`, `package.json`, `CHANGELOG.md`
- generated only, by `node bin/cli.js --update`: `.claude/bin/unit-bookkeeping.sh`, `.claude/agents/*.md`,
  `.claude/persona-protocol*.md`, `.claude/protocol-digest.md`, the config's `fileHashes` and `pluginVersion`

## Ordered edits
1. file: `tests/unit-bookkeeping.test.sh`
   anchor: line matching `exit "$fail"` (the last line)
   indent: 0
   before: `exit "$fail"`
   after:
~~~
# rp-u3: a ladder that prints a tier and exits non-zero yields opus, EXHAUSTED stays EXHAUSTED, the usage
# names --implementer-tier, and Range: is two full SHAs for a symbolic baseline.
printf '#!/usr/bin/env bash\necho "ladder-tier: haiku n=0 ladder=haiku,sonnet,opus reason=default"\nexit 3\n' > "$T/stub/ladderbad"
UB_LADDER="$T/stub/ladderbad" bash "$UB" dispatch u12 | grep -qx 'model: opus' && ok "(o) non-zero ladder exit -> opus" || bad "(o) non-zero ladder exit -> opus"
printf '#!/usr/bin/env bash\necho "ladder-tier: EXHAUSTED n=6 ladder=haiku,sonnet,opus reason=default"\nexit 3\n' > "$T/stub/ladderex"
UB_LADDER="$T/stub/ladderex" bash "$UB" dispatch u13 | grep -qx 'model: EXHAUSTED' && ok "(o) non-zero exit keeps EXHAUSTED" || bad "(o) non-zero exit keeps EXHAUSTED"
u="$(bash "$UB" 2>&1)"; printf '%s\n' "$u" | grep -qF 'review <unit> <baseline> [--implementer-tier <t>]' && ok "(p) usage names --implementer-tier" || bad "(p) usage omits --implementer-tier"
stub rtier 'sonnet'
UB_REVIEWER_TIER="$T/stub/rtier" bash "$UB" review u14 HEAD~1 >/dev/null
grep -qx "Range: $BASE..$(git rev-parse HEAD)" "$HDR/u14.header" && ok "(q) symbolic baseline resolved to a full SHA" || bad "(q) $(grep '^Range:' "$HDR/u14.header")"

exit "$fail"
~~~
2. command: `bash -c 'bash tests/unit-bookkeeping.test.sh | grep -c "^FAIL"'`
   expect: 0
   The red step: it prints `3` (the first (o) case, (p) and (q) fail; the EXHAUSTED case already passes).
3. file: `bin/unit-bookkeeping.sh`
   anchor: line matching `usage() { echo "usage: unit-bookkeeping.sh dispatch`
   indent: 0
   before: `usage() { echo "usage: unit-bookkeeping.sh dispatch <unit> [--contract <path>] | review <unit> <baseline>" >&2; exit 2; }`
   after: `usage() { echo "usage: unit-bookkeeping.sh dispatch <unit> [--contract <path>] | review <unit> <baseline> [--implementer-tier <t>]" >&2; exit 2; }`
4. file: `bin/unit-bookkeeping.sh`
   anchor: line matching `  local unit="$2" contract="" ladder="${UB_LADDER:-$dir/ladder-tier.sh}" line tier`
   indent: 2
   before: `  local unit="$2" contract="" ladder="${UB_LADDER:-$dir/ladder-tier.sh}" line tier`
   after: `  local unit="$2" contract="" ladder="${UB_LADDER:-$dir/ladder-tier.sh}" line tier rc`
5. file: `bin/unit-bookkeeping.sh`
   anchor: line matching `  line="$(bash "$ladder" "${args[@]}" | head -n1)"`
   indent: 2
   before:
~~~
  line="$(bash "$ladder" "${args[@]}" | head -n1)"
  read -r -a f <<< "$line"
  tier="${f[1]:-}"
  if [ "${f[0]:-}" != ladder-tier: ]; then tier=opus; fi
  case "$tier" in haiku|sonnet|opus|EXHAUSTED) ;; *) tier=opus ;; esac
~~~
   after:
~~~
  line="$(bash "$ladder" "${args[@]}")"; rc=$?
  line="$(printf '%s\n' "$line" | head -n1)"
  read -r -a f <<< "$line"
  tier="${f[1]:-}"
  if [ "${f[0]:-}" != ladder-tier: ]; then tier=opus; fi
  case "$tier" in haiku|sonnet|opus|EXHAUSTED) ;; *) tier=opus ;; esac
  # A failed helper forces opus, except that exhaustion stays EXHAUSTED: that stop goes to the human.
  if [ "$rc" -ne 0 ] && [ "$tier" != EXHAUSTED ]; then tier=opus; fi
~~~
6. file: `bin/unit-bookkeeping.sh`
   anchor: line matching `  echo "Range: $base..$(git rev-parse HEAD)"`
   indent: 2
   before: `  echo "Range: $base..$(git rev-parse HEAD)"`
   after: `  echo "Range: $(git rev-parse "$base^{commit}")..$(git rev-parse HEAD)"`
7. command: `bash tests/unit-bookkeeping.test.sh`
   expect: 0
8. file: `tests/prompt-diet-pins.test.sh`
   anchor: line matching `# Later units append their rows below this line.`
   indent: 0
   insert-after:
~~~

# rp-u3: the reviewer's pointer to the moved residual, the orchestrator's teams-command pointer, qw-u4's
# safety phrases, the ported scribe sentence, and three more narratives qw-u3 removed. Current files only.
for f in agents/reviewer.md .claude/agents/reviewer.md; do
  has "$f" '(see `docs/orchestrator-rationale.md`, "N1: reviewer dispatch naming, the unobserved residual")'
  hasnot "$f" '`agents/orchestrator.md`'"'"'s "Dispatch naming" section'
done
has docs/orchestrator-rationale.md '## N1: reviewer dispatch naming, the unobserved residual'
for f in agents/orchestrator.md .claude/agents/orchestrator.md; do
  has "$f" 'If the `start-feature-team` command is running, its rules govern instead of the routing/review-ownership rules above'
  has "$f" 'ask through one `AskUserQuestion` call'
  has "$f" 'If that section cannot be read, print the whole marker verbatim, write nothing, and tell the human to resolve the escalation from their terminal or the Microworld dashboard.'
done
for f in templates/persona-protocol.md .claude/persona-protocol.md; do
  has "$f" 'never retry or rephrase the write'
  has "$f" 'Write only from this session'"'"'s answer'
  has "$f" 'never pick one for them'
  has "$f" 'Do not relay the decision in the prompt'
done
for f in agents/orchestrator.md adapters/codex/agents/orchestrator.toml adapters/cursor/agents/orchestrator.md; do
  has "$f" 'When you dispatch scribe, quote each unit'"'"'s reviewer PASS verdict line verbatim in that dispatch; scribe closes an issue only on its own quoted line.'
  hasnot "$f" 'When you dispatch scribe for a unit'
done
for f in templates/persona-protocol.md .claude/persona-protocol.md .claude/agents/orchestrator.md \
         .claude/agents/reviewer.md .claude/agents/spec-master.md .claude/agents/task-master.md \
         .claude/agents/milestone-auditor.md .claude/agents/lead-programmer.md; do
  hasnot "$f" 'not an exemption'
  hasnot "$f" 'Not an alternative to the WIP sentinel'
  hasnot "$f" 'a complementary safety layer'
done
~~~
9. command: `bash -c 'bash tests/prompt-diet-pins.test.sh | grep -c "^FAIL"'`
   expect: 0
   The red step: it prints `8` (the `has` and `hasnot` reviewer rows for `agents/reviewer.md` and its mirror, and the `has` and `hasnot` scribe rows for both ports, before edits 10 to 12).
10. file: `agents/reviewer.md`
   anchor: line matching `  If the marker-write attempt is refused because a gate names an identity`
   indent: 2
   before:
~~~
  If the marker-write attempt is refused because a gate names an identity that is the dispatch's own name, this is most likely a harness name-collision auto-suffix applied to your dispatch's `agent_type` after spawn — a residual the orchestrator's `reviewer-route-gate.sh` cannot observe at dispatch time, since it only inspects the requested name, never the post-spawn identity (see `agents/orchestrator.md`'s "Dispatch naming" section). Report the block, your completed verdict (PASS/FAIL), and the exact marker body it would have written, so a correctly-dispatched replacement can confirm the result rather than re-derive a completed review from scratch.
~~~
   after:
~~~
  If the marker-write attempt is refused because a gate names an identity that is the dispatch's own name, this is most likely a harness name-collision auto-suffix applied to your dispatch's `agent_type` after spawn — a residual the orchestrator's `reviewer-route-gate.sh` cannot observe at dispatch time, since it only inspects the requested name, never the post-spawn identity (see `docs/orchestrator-rationale.md`, "N1: reviewer dispatch naming, the unobserved residual"). Report the block, your completed verdict (PASS/FAIL), and the exact marker body it would have written, so a correctly-dispatched replacement can confirm the result rather than re-derive a completed review from scratch.
~~~
11. file: `adapters/codex/agents/orchestrator.toml`
   anchor: line matching `milestone audit gate. When you dispatch scribe for a unit, quote the`
   indent: 0
   before:
~~~
milestone audit gate. When you dispatch scribe for a unit, quote the
reviewer's PASS verdict line verbatim in that dispatch; scribe closes an
issue only on that quoted line.
~~~
   after:
~~~
milestone audit gate. When you dispatch scribe, quote each unit's reviewer
PASS verdict line verbatim in that dispatch; scribe closes an issue only on
its own quoted line.
~~~
12. file: `adapters/cursor/agents/orchestrator.md`
   anchor: line matching `milestone audit gate. When you dispatch scribe for a unit, quote the`
   indent: 0
   before:
~~~
milestone audit gate. When you dispatch scribe for a unit, quote the
reviewer's PASS verdict line verbatim in that dispatch; scribe closes an
issue only on that quoted line.
~~~
   after:
~~~
milestone audit gate. When you dispatch scribe, quote each unit's reviewer
PASS verdict line verbatim in that dispatch; scribe closes an issue only on
its own quoted line.
~~~
13. command: `perl -0pi -e 's/("version": "\d+\.\d+\.)(\d+)"/$1.($2+1)."\""/e' .claude-plugin/plugin.json package.json`
   expect: 0
   This adds one to the patch version in both files (expected one above what rp-u2 wrote).
14. file: `CHANGELOG.md`
   anchor: line matching `## [Unreleased]`
   indent: 0
   insert-after:
~~~

**Bookkeeping fail-safe and stale prose (rp-u3, VERSION).** bin/unit-bookkeeping.sh: `dispatch` prints `model: opus` when the ladder helper exits non-zero, even if it printed a tier (an `EXHAUSTED` line stays `EXHAUSTED`); the usage names `[--implementer-tier <t>]`; the reviewer dispatch header's `Range:` is two full SHAs. agents/reviewer.md points the name-collision residual at docs/orchestrator-rationale.md N1. The codex and cursor orchestrator ports say the scribe quotes each unit's PASS line, as agents/orchestrator.md does. tests/prompt-diet-pins.test.sh pins these, the orchestrator's teams-command pointer, qw-u4's escalation safety phrases and the absence of three more removed narratives.
~~~
   Replace `VERSION` with the version that edit 13 wrote.
15. command: `node bin/cli.js --update`
   expect: 0
16. command: `bash -c 'bash tests/prompt-diet-pins.test.sh >/dev/null && bash tests/unit-bookkeeping.test.sh >/dev/null'`
   expect: 0
17. command: `git add -u && git commit -m "fix(rp-u3): bookkeeping fails safe on a ladder error; repoint and pin stale prose"`
   expect: 0
   Run `git status --short` first: if a tracked file outside "Affected files" is modified, stop and report it.

## Do NOT touch
- `agents/orchestrator.md` and `templates/persona-protocol.md` (pinned, not edited; st-u4 and rp-u5 own their edits; criterion 5)
- `docs/orchestrator-rationale.md` and `commands/start-feature-team.md` (pinned targets; criterion 5)
- `bin/ladder-tier.sh` and `hooks/scripts/reviewer-tier.sh` (helpers unchanged; criterion 5)

## Acceptance criteria
1. run: `bash -c 'bash tests/unit-bookkeeping.test.sh >/dev/null 2>&1; echo $?'`
   exit: 0
   stdout: `0`
   mutation: delete the line `  if [ "$rc" -ne 0 ] && [ "$tier" != EXHAUSTED ]; then tier=opus; fi`; the first (o) case fails and stdout is `1`. Dropping `&& [ "$tier" != EXHAUSTED ]` fails the second (o) case.
2. run: `bash -c 'bash tests/prompt-diet-pins.test.sh >/dev/null 2>&1; echo $?'`
   exit: 0
   stdout: `0`
   mutation: change "never pick one for them" to "pick one for them" in templates/persona-protocol.md and run `--update`; two rows fail and stdout is `1`.
3. run: `bash -c 'cmp bin/unit-bookkeeping.sh .claude/bin/unit-bookkeeping.sh && tr -s " \n" " " < adapters/codex/agents/orchestrator.toml | grep -c "scribe closes an issue only on its own quoted line" && tr -s " \n" " " < adapters/cursor/agents/orchestrator.md | grep -c "scribe closes an issue only on its own quoted line"'`
   exit: 0
   stdout: `1` then `1` (two lines)
   mutation: skip edit 15 (`--update`); `cmp` reports a difference and the command exits 1.
4. run: `bash -c 'b=$(git log --format=%H --grep="(rp-u3)" | tail -1); l=$(git log --format=%H --grep="(rp-u3)" | head -1); git diff --name-only "$b^..$l" -- . ":(exclude).claude" | sort | tr "\n" " "'`
   exit: 0
   stdout: `.claude-plugin/plugin.json CHANGELOG.md adapters/codex/agents/orchestrator.toml adapters/cursor/agents/orchestrator.md agents/reviewer.md bin/unit-bookkeeping.sh package.json tests/prompt-diet-pins.test.sh tests/unit-bookkeeping.test.sh `
   mutation: also edit `agents/orchestrator.md` in an rp-u3 commit; it joins the list.
5. run: `bash -c 'b=$(git log --format=%H --grep="(rp-u3)" | tail -1); l=$(git log --format=%H --grep="(rp-u3)" | head -1); git diff --name-only "$b^..$l" -- agents/orchestrator.md templates docs/orchestrator-rationale.md commands bin/ladder-tier.sh hooks | wc -l'`
   exit: 0
   stdout: `0`
   mutation: edit `bin/ladder-tier.sh` in an rp-u3 commit; stdout is `1`.
6. run: `bash -c 'b=$(git log --format=%H --grep="(rp-u3)" | tail -1); l=$(git log --format=%H --grep="(rp-u3)" | head -1); bash hooks/scripts/version-stamp-check.sh "$b^..$l" | cut -d" " -f1-4'`
   exit: 0
   stdout: `version-stamp-check: ok touched: yes`
   mutation: skip edit 13; stdout reads `version-stamp-check: violation touched: yes`.
7. run: `bash -c 'bash tests/validate.sh >/dev/null 2>&1; echo $?'` (Bash tool timeout 600000 ms)
   exit: 0
   stdout: `0`
   mutation: put `exit 1` as line 2 of tests/prompt-diet-pins.test.sh; validate.sh exits 1 and stdout is `1`.

## Pre-resolved context
tdd: yes edit 1 adds the bookkeeping cases and edit 2 shows them red (`3`); edit 8 adds the pins and edit 9 shows them red (`8`) before the prose edits 10 to 12.
helper-exit: `bin/ladder-tier.sh` always exits 0 (header line 2; lines 141-149), so a non-zero exit means the helper broke; `review_cmd` already forces opus on a non-zero reviewer-tier exit (line 80). Before this unit, `line="$(bash "$ladder" ... | head -n1)"` took `head`'s status.
pins-checked: every `has` phrase occurs once in each named file at 82844f70 except the ones edits 10 to 12 create; every `hasnot` phrase is absent from every named file at 82844f70 except the two the edits remove. "Do not relay the decision in the prompt" (capital D) is the protocol's wording; the orchestrator's lowercase "do not relay the decision in the prompt" is already pinned by the qw-u4 rows.
accepted: qw-u4 addendum item 2 (the stub's fallback names the terminal route whose template lives in the section it assumes unreadable) is recorded as accepted in the spec, not changed here: inlining a DECISION template into the orchestrator body would put the packet path and `DECISION` in persona prose that every Bash heredoc quoting it trips `human-decision-gate.sh` on. Items 3 and 4 are spec notes only.
proof: spec-master applied edits 1 to 17 to a scratch clone (8b931f0f, qw-u5 landed, plus rp-u1 and rp-u2) with a script that requires each `before:` payload to occur exactly once: every payload matched once, edits 2 and 9 printed `3` and `8`, edit 16 exited 0, and criteria 1 to 6 printed the stated stdout after `VERSION` was replaced; adapter-protocol-parity, writer-tier-consistency, cli-backfill, persona-prose-pins, bin-helpers-scaffold and human-decision-gate stayed green. validate.sh was not run by spec-master.
chained: no queued contract (qw-u6, st-u1 to st-u4) edits any file in this unit's list except `agents/reviewer.md` (st-u2 edit 6, at "Scope the review with the blast-radius script", outside line 328); none of the pinned phrases occurs in a queued contract.
blast-radius: bin/unit-bookkeeping.sh:12, :33, :44-48, :61; agents/reviewer.md:328; adapters/codex/agents/orchestrator.toml:96-98; adapters/cursor/agents/orchestrator.md:90-92; tests/unit-bookkeeping.test.sh:99; tests/prompt-diet-pins.test.sh:93. Caller: agents/orchestrator.md "Per-unit model routing" runs `.claude/bin/unit-bookkeeping.sh`. Line numbers are at 82844f70; work from the anchors.
version: .claude-plugin/plugin.json and package.json read 0.31.193 at 82844f70 and 0.31.195 after rp-u1 and rp-u2; edit 13 adds one to whatever they read when the unit starts (expected 0.31.196).
mirrors: `.claude/` copies change only through `node bin/cli.js --update` (constitution P2).
commit-message: fix(rp-u3): bookkeeping fails safe on a ladder error; repoint and pin stale prose
diagnosis: none
review-packet:
~~~
unit: rp-u3
changed files: <FILL: changed files>
commit: <FILL: commit SHA>
criterion 1: <FILL: exit and stdout>
criterion 2: <FILL: exit and stdout>
criterion 3: <FILL: exit and stdout>
criterion 4: <FILL: exit and stdout>
criterion 5: <FILL: exit and stdout>
criterion 6: <FILL: exit and stdout>
criterion 7: <FILL: exit and stdout>
~~~

## Escalation
If a `before:` payload is not found verbatim, stop and report the current text. If a `has` row fails after
edits 10 to 12 because a later unit rewrapped or reworded a pinned sentence, stop and report the row and
the current text; do not edit the pinned file. If `node bin/cli.js --update` reports a mirror as diverged,
quote it and stop. If a gate blocks a command, report it and wait. Anything outside "Affected files" goes
to your report as a proposal.
