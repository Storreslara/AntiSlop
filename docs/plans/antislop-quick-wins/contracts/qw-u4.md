Unit: qw-u4

## Objective
Move the orchestrator's ESCALATE-TO-HUMAN procedure (129 lines, steps 1 to 7 plus the untyped-agent rule)
verbatim out of `agents/orchestrator.md` into a new subsection `### Orchestrator steps on an
ESCALATE-TO-HUMAN verdict` at the end of the protocol's "Fourth verdict: escalate-to-human" section, and
leave a 12-line stub that names the subsection and keeps the five invariants inline. No persona inlines
"Fourth verdict" (every row of `PROTOCOL_SECTIONS_BY_PERSONA` drops it), so the orchestrator reads the
procedure on demand, exactly as `agents/reviewer.md` already does for the same section. The installed
`.claude/agents/orchestrator.md` shrinks by at least 7000 bytes (7647 measured); no other mirror changes
beyond its version stamp. The two tests that pin text of the moved block follow it to the protocol copies.
This is spec Step 4 (b-1 iii).

## Retrieval
Fast path, no tracker issue. Spec: `docs/plans/antislop-quick-wins/spec.md`, "Step 4 (qw-u4)" and "Context,
b". This file is the contract of record. Dispatch it only after qw-u3 has reached PASS (it extends the pins
test that qw-u2 created and qw-u3 extended).

## Affected files
- `tests/prompt-diet-pins.test.sh` (anchor: line matching `# qw-u4 appends its rows below this line.`)
- `agents/orchestrator.md` (the block from the line starting `**On an \`ESCALATE-TO-HUMAN\` verdict**` up to, not including, the blank line before `If no \`reviewer\` persona exists in this project`)
- `templates/persona-protocol.md` (anchor: line matching `## Continuing after a FAIL verdict`; the new subsection goes directly before it, at the end of "Fourth verdict")
- `tests/adapter-protocol-parity.test.js` (anchor: line matching `  for (const rel of ['agents/orchestrator.md', '.claude/agents/orchestrator.md']) {`)
- `tests/packet-view-script.test.sh` (anchors: lines matching `# T10 - orchestrator steps 2 and 3` and `for f in agents/orchestrator.md .claude/agents/orchestrator.md; do`)
- `.claude-plugin/plugin.json`, `package.json`, `CHANGELOG.md`
- generated only, by `node bin/cli.js --update`: `.claude/agents/*.md` (orchestrator body; every other mirror only its stamp line), `.claude/persona-protocol.md`, `.claude/persona-protocol-slim.md`, `.claude/protocol-digest.md`, the config's `fileHashes` and `pluginVersion`
- outside the repo (scratch, not committed): `/tmp/qw-u4-stub.md`, `/tmp/qw-u4-move.py`

## Ordered edits
1. file: `tests/prompt-diet-pins.test.sh`
   anchor: line matching `# qw-u4 appends its rows below this line.`
   indent: 0
   before: `# qw-u4 appends its rows below this line.`
   after:
~~~
# qw-u4: the ESCALATE-TO-HUMAN procedure moves verbatim into the protocol's Fourth verdict section; the
# orchestrator keeps a stub that names the subsection and carries the five invariants.
for f in agents/orchestrator.md .claude/agents/orchestrator.md; do
  has "$f" 'subsection of the `## Fourth verdict: escalate-to-human` section in `.claude/persona-protocol.md`'
  has "$f" 'Your job is **surfacing, not deciding**.'
  has "$f" 'print the marker'"'"'s card verbatim, never a summary'
  has "$f" 'never run `run.sh` or `view.sh` yourself'
  has "$f" 'relay the human'"'"'s answer verbatim'
  has "$f" '**prompt-confirmed decision write**, from this session'"'"'s answer and never on your own initiative'
  has "$f" 'afresh with `subagent_type: reviewer` set explicitly'
  has "$f" 'do not relay the decision in the prompt'
  hasnot "$f" 'Make **one** `AskUserQuestion` call'
  hasnot "$f" 'Twice a `general-purpose` agent dispatched this way'
done
for f in templates/persona-protocol.md .claude/persona-protocol.md; do
  has "$f" '### Orchestrator steps on an ESCALATE-TO-HUMAN verdict'
  has "$f" 'Print the marker'"'"'s lines 1 through the `---` fold line in chat **verbatim**'
  has "$f" 'Read `CHANGES.md` in that packet directory **(if present)**'
  has "$f" 'Read `EXAMPLES.md` in that packet directory **(if present)**'
  has "$f" '**Never run `run.sh` or `view.sh` yourself and never pre-digest a result**'
  has "$f" 'Make **one** `AskUserQuestion` call'
  has "$f" 'Make the **prompt-confirmed decision write**'
  has "$f" '**with `subagent_type: reviewer` set explicitly**'
  has "$f" '**never dispatch review-adjacent work to an untyped or generic agent.**'
done

# Later units append their rows below this line.
~~~
2. command: `bash tests/prompt-diet-pins.test.sh`
   expect: 1
   The red step: the new rows fail before the move.
3. file: `/tmp/qw-u4-stub.md`
   anchor: new file, written with the **Write tool** (not a Bash heredoc: the text names the packet directory and the DECISION file, and `human-decision-gate.sh` refuses Bash text that spells both)
   indent: 0
   insert-after:
~~~
**On an `ESCALATE-TO-HUMAN` verdict** — this project's `reviewer` (if present) wrote
`.claude/reviewed/<task-id>.escalated` plus a durable packet at `.claude/human-review/<task-id>/`, and
turn-end stays blocked until the unit is resolved. Your job is **surfacing, not deciding**. Read the
`### Orchestrator steps on an ESCALATE-TO-HUMAN verdict` subsection of the `## Fourth verdict:
escalate-to-human` section in `.claude/persona-protocol.md` (in this plugin's own repo:
`templates/persona-protocol.md`) and follow its seven steps. They never relax these invariants: print the
marker's card verbatim, never a summary; never run `run.sh` or `view.sh` yourself; ask through one
`AskUserQuestion` call and relay the human's answer verbatim; create the DECISION file only through the
**prompt-confirmed decision write**, from this session's answer and never on your own initiative; then
dispatch this project's `reviewer` (if present) afresh with `subagent_type: reviewer` set explicitly, and
do not relay the decision in the prompt. If that section cannot be read, print the whole marker verbatim,
write nothing, and tell the human to resolve the escalation from their terminal or the Microworld dashboard.
~~~
4. file: `/tmp/qw-u4-move.py`
   anchor: new file, written with the Write tool
   indent: 0
   insert-after:
~~~
import sys
o_path, t_path = 'agents/orchestrator.md', 'templates/persona-protocol.md'
o = open(o_path).read().split('\n')
start = [i for i, l in enumerate(o) if l.startswith('**On an `ESCALATE-TO-HUMAN` verdict**')]
end = [i for i, l in enumerate(o) if l.startswith('If no `reviewer` persona exists in this project')]
assert len(start) == 1 and len(end) == 1 and start[0] < end[0], (start, end)
block = o[start[0]:end[0]]
while block and block[-1] == '':
    block.pop()
assert len(block) == 129, len(block)
t = open(t_path).read().split('\n')
anchor = [i for i, l in enumerate(t) if l == '## Continuing after a FAIL verdict']
assert len(anchor) == 1, anchor
head = ['### Orchestrator steps on an ESCALATE-TO-HUMAN verdict',
        '',
        'The orchestrator reads this subsection on demand; in it, "you" is the orchestrator.',
        '`agents/orchestrator.md` keeps a short stub that points here and restates the invariants.',
        '']
t[anchor[0]:anchor[0]] = head + block + ['']
open(t_path, 'w').write('\n'.join(t))
stub = open(sys.argv[1]).read().rstrip('\n').split('\n')
o[start[0]:start[0] + len(block)] = stub
open(o_path, 'w').write('\n'.join(o))
print('moved', len(block), 'lines; stub', len(stub), 'lines')
~~~
5. command: `python3 /tmp/qw-u4-move.py /tmp/qw-u4-stub.md`
   expect: 0
   stdout: `moved 129 lines; stub 12 lines`. The script moves the block byte for byte (no text of it is retyped) and replaces it with the stub; an assertion error means an anchor or the block length changed, so stop and report.
6. file: `tests/adapter-protocol-parity.test.js`
   anchor: line matching `  for (const rel of ['agents/orchestrator.md', '.claude/agents/orchestrator.md']) {` (inside the check `orchestrator escalation steps handle a marker with no fold line or no decide: line`)
   indent: 2
   before: `  for (const rel of ['agents/orchestrator.md', '.claude/agents/orchestrator.md']) {`
   after: `  for (const rel of ['templates/persona-protocol.md', '.claude/persona-protocol.md']) {`
7. file: `tests/packet-view-script.test.sh`
   anchor: line matching `# T10 - orchestrator steps 2 and 3`
   indent: 0
   before:
~~~
# T10 - orchestrator steps 2 and 3 both strip the Read tool's line-number prefixes
for f in agents/orchestrator.md .claude/agents/orchestrator.md; do
~~~
   after:
~~~
# T10 - the orchestrator's escalation steps 2 and 3 (in the protocol's Fourth verdict section since qw-u4)
# both strip the Read tool's line-number prefixes
for f in templates/persona-protocol.md .claude/persona-protocol.md; do
~~~
8. command: `perl -0pi -e 's/("version": "\d+\.\d+\.)(\d+)"/$1.($2+1)."\""/e' .claude-plugin/plugin.json package.json`
   expect: 0
   This adds one to the patch version in both files (expected 0.31.190 to 0.31.191).
9. file: `CHANGELOG.md`
   anchor: line matching `## [Unreleased]`
   indent: 0
   insert-after:
~~~

**Escalation procedure read on demand (qw-u4, VERSION).** The orchestrator's ESCALATE-TO-HUMAN steps 1 to 7 move verbatim from agents/orchestrator.md to a new subsection "Orchestrator steps on an ESCALATE-TO-HUMAN verdict" at the end of the protocol's Fourth verdict section, which no persona inlines. The orchestrator keeps a 12-line stub with the five invariants and reads the subsection when a verdict arrives, as the reviewer already does. The orchestrator prompt is about 7.6k bytes smaller. The fold-line, decide-line and line-prefix pins in tests/adapter-protocol-parity.test.js and tests/packet-view-script.test.sh now check the protocol copies.
~~~
   Replace `VERSION` with the version that edit 8 wrote.
10. command: `node bin/cli.js --update`
   expect: 0
11. command: `bash tests/prompt-diet-pins.test.sh`
   expect: 0
12. command: `git add -u && git commit -m "feat(qw-u4): the orchestrator reads its escalation procedure on demand; moved verbatim, invariants kept"`
   expect: 0
   Run `git status --short` first: if a tracked file outside "Affected files" is modified, stop and report it. The two `/tmp` files are not committed.

## Do NOT touch
- `bin/cli.js` (no matrix change: "Fourth verdict" stays dropped from every row; criterion 4 proves no other mirror gained it)
- `adapters/` (the codex and cursor ports carry their own condensed escalation text; criterion 5)
- `agents/reviewer.md` (its on-demand pointer to the same section already exists)
- `agents/orchestrator.md` from the paragraph starting `If no` (the no-reviewer paragraph) to the end of the file
- `.claude/agents/` and `.claude/persona-protocol.md` by hand (only `node bin/cli.js --update` writes them)

## Acceptance criteria
1. run: `bash -c 'bash tests/prompt-diet-pins.test.sh >/dev/null; echo $?'`
   exit: 0
   stdout: `0`
   mutation: skip edit 5; the orchestrator still holds `Make **one** \`AskUserQuestion\` call` and the protocol lacks the subsection, so rows fail and stdout is `1`.
2. run: `bash -c 'b=$(git log --format=%H --grep="(qw-u4)" | tail -1); old=$(git show "$b^:.claude/agents/orchestrator.md" | wc -c); new=$(wc -c < .claude/agents/orchestrator.md); echo $(( old - new >= 7000 ))'`
   exit: 0
   stdout: `1`
   mutation: use the whole 129-line block as the stub file in edit 3; the mirror shrinks by about 0 and stdout is `0`.
3. run: `bash -c 'b=$(git log --format=%H --grep="(qw-u4)" | tail -1); f="${TMPDIR:-/tmp}/qw-u4-block.md"; git show "$b^:agents/orchestrator.md" | awk "/^\*\*On an .ESCALATE-TO-HUMAN. verdict\*\*/{p=1} /^If no .reviewer. persona exists in this project/{p=0} p" > "$f"; echo $(for t in templates/persona-protocol.md .claude/persona-protocol.md; do python3 -c "import sys;b=open(sys.argv[1]).read().rstrip(chr(10));print(open(sys.argv[2]).read().count(b))" "$f" "$t"; done)'`
   exit: 0
   stdout: `1 1`
   mutation: change one word inside the moved block in `templates/persona-protocol.md` and re-run `--update`; the verbatim block is no longer found and stdout is `0 0`.
4. run: `bash -c 'b=$(git log --format=%H --grep="(qw-u4)" | tail -1); for f in .claude/agents/*.md; do [ "$f" = .claude/agents/orchestrator.md ] && continue; n=$(git diff -U0 "$b^..HEAD" -- "$f" | grep "^[-+][^-+]" | grep -vc "antislop v0\."); [ "$n" = 0 ] || echo "$f $n"; done'`
   exit: 0
   stdout: empty
   mutation: add `'Fourth verdict: escalate-to-human'` to the reviewer row's `include` in `bin/cli.js` (and remove it from `drop`); the reviewer mirror gains the section and the command prints `.claude/agents/reviewer.md <n>`.
5. run: `bash -c 'b=$(git log --format=%H --grep="(qw-u4)" | tail -1); git diff --name-only "$b^..HEAD" -- adapters bin hooks agents/reviewer.md | wc -l'`
   exit: 0
   stdout: `0`
   mutation: edit `adapters/cursor/agents/orchestrator.md` in a qw-u4 commit; stdout is at least `1`.
6. run: `bash -c 'node tests/adapter-protocol-parity.test.js >/dev/null && bash tests/packet-view-script.test.sh >/dev/null && node tests/protocol-doc-drift.test.js >/dev/null && node tests/protocol-cross-references.test.js >/dev/null && bash tests/persona-prose-pins.test.sh >/dev/null && node tests/writer-tier-consistency.test.js >/dev/null; echo $?'`
   exit: 0
   stdout: `0`
   mutation: skip edit 6; the parity check prints `agents/orchestrator.md: missing the no-fold-line rule` and stdout is `1` (spec-master ran this on a clone).
7. run: `bash -c 'b=$(git log --format=%H --grep="(qw-u4)" | tail -1); bash hooks/scripts/version-stamp-check.sh "$b^..HEAD" | cut -d" " -f1-4'`
   exit: 0
   stdout: `version-stamp-check: ok touched: yes`
   mutation: skip edit 8; stdout reads `version-stamp-check: violation touched: yes`.
8. run: `bash -c 'bash tests/validate.sh >/dev/null 2>&1; echo $?'` (Bash tool timeout 600000 ms)
   exit: 0
   stdout: `0`
   mutation: put `exit 1` as line 2 of tests/prompt-diet-pins.test.sh; validate.sh exits 1 and stdout is `1`.

## Pre-resolved context
tdd: yes the pins rows (edit 1) fail first (edit 2). spec-master ran edits 4 to 10 on a clone of 1d4abf5a: `moved 129 lines; stub 12 lines`, mirror -7647 bytes, criteria 2, 3 and 4 printed `1`, `1 1` and nothing; with edits 6 and 7 the parity, packet-view, doc-drift, cross-reference, prose-pin, writer-tier, default-implementer-model and cli-backfill suites all exit 0; without them parity and packet-view T10 fail.
blast-radius: agents/orchestrator.md:247-375 (the block; 129 lines plus one trailing blank), templates/persona-protocol.md:805 (`## Continuing after a FAIL verdict`), bin/cli.js:790 (every row drops "Fourth verdict"), tests/adapter-protocol-parity.test.js:283, tests/packet-view-script.test.sh:130-131, agents/reviewer.md:293 (the precedent pointer). Line numbers are at 1d4abf5a; work from the anchors.
pins-searched: a 45-character sliding window over `tests/` found the fold and decide pins; a second search for shorter literals found T10 in tests/packet-view-script.test.sh (`without the Read tool's line-number prefixes`, 44 characters, counted twice). The spec's earlier claim that the parity test was the only pin was wrong; this contract corrects it. validate.sh's optional-persona paragraph check covers `agents/orchestrator.md`: the stub names `reviewer` with "(if present)" and "this project".
rule-map: steps 1 to 7 and the untyped-agent paragraph -> the new protocol subsection, byte for byte (criterion 3). Invariants kept in the stub (edit 3): I1 card verbatim, never a summary (step 1); I2 never run run.sh or view.sh (step 4); I3 one AskUserQuestion call, the answer relayed verbatim (step 5); I4 the DECISION file only through the prompt-confirmed decision write, never on own initiative (step 6); I5 a fresh reviewer dispatch with `subagent_type: reviewer`, no relayed decision (step 7). Fallback when the section cannot be read: whole marker verbatim, no write, terminal or dashboard route.
cross-references: the moved text refers only to steps inside itself ("the `run.sh` rule below", "as in step 5"); the stub writes no `"Fourth verdict" below`, so tests/protocol-cross-references.test.js C2.2 stays green. No README, CONTEXT.md, glossary or ADR text cites the orchestrator's step numbers (searched).
gate-note: the stub and this contract name the packet directory and the DECISION file together. Author them with the Write tool as edits 3 and 4 say. If Write is not available in your dispatch, do not rephrase or split the text to get a Bash heredoc past `human-decision-gate.sh`; report and wait.
version: .claude-plugin/plugin.json and package.json read 0.31.190 after qw-u3 if no fix round bumped; edit 8 adds one (expected 0.31.191).
mirrors: `.claude/` copies change only through `node bin/cli.js --update` (constitution P2).
commit-message: feat(qw-u4): the orchestrator reads its escalation procedure on demand; moved verbatim, invariants kept
diagnosis: none
review-packet:
~~~
unit: qw-u4
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
If edit 5 raises an assertion (an anchor is missing, appears twice, or the block is not 129 lines), an
earlier unit changed the block: stop and report the current line numbers; do not adjust the count. If a
`before:` payload is not found verbatim, stop and report the current text. If `node bin/cli.js --update`
refuses, quote its message and stop. If a gate blocks a command, report it and wait. Anything outside
"Affected files" goes to your report as a proposal.
