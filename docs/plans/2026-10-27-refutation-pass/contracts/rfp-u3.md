Unit: rfp-u3

## Objective
Enable the reviewer's refutation pass and the FAIL record's telemetry line, together, as one gate (plan R6,
R7).
- `agents/reviewer.md` gains the bullet "Refutation pass (before any FAIL verdict)". It covers:
  - judgment defects only, at most 3, with the skip reasons recorded;
  - the brief from `bash .claude/bin/refutation-brief.sh` (rfp-u1), and one `explorer` spawn with
    `model: sonnet`, in the foreground and unnamed;
  - the reviewer's own re-check, with a guard checked on the defect's own path, its own stated reason, and
    the right to keep a defect standing;
  - `[unconfirmed]` for UNCERTAIN defects in a FAIL;
  - INSUFFICIENT-CONTEXT when only UNCERTAIN defects remain, with a reproduce-or-note resume;
  - the PASS state, unchanged, plus `NOTE[code]: refuted:` notes.
- The other reviewer.md edits:
  - the advisory-section order gains `refutation`;
  - "found no refutation" becomes "found no defect that survived the refutation pass", which removes the
    word collision;
  - the On FAIL bullet names the telemetry line.
- `templates/persona-protocol.md` "FAIL record" defines the last line,
  `refutation: confirmed=<a> refuted=<b> uncertain=<c>` or
  `refutation: skipped=<mechanical|over-cap|resume|no-subagent>`, and the `[unconfirmed]` rule. Through
  `--update` that reaches the orchestrator, lead-programmer, reviewer, spec-master and task-master mirrors.
- The four hand-synced ports say they write `refutation: skipped=no-subagent`.
- New `tests/fail-record-refutation.test.sh` proves that every reader of the record is unaffected.

**Precondition: Gate G passed.** The committed `eval/refutation-replay/report.jsonl` scores
`replay-gate: pass` (criterion 8). Do not dispatch this unit before that.

## Retrieval
Fast path, no tracker issue. Spec: `docs/plans/2026-10-27-refutation-pass.md` ("Resolved decisions",
"Per-defect protocol", "FAIL-record readers", "Step 3"). This file is the contract of record. Dispatch only
after rfp-u1 and rfp-u2 have a PASS and Gate G3 printed `replay-gate: pass`.

## Affected files
- `tests/persona-prose-pins.test.sh` (anchor: line matching `if [ "$fail" -eq 0 ]; then echo "All persona-prose-pins checks passed."; else echo "persona-prose-pins: FAILED"; fi`)
- `tests/reviewer-route-gate-caller.test.sh` (anchor: line matching `check_exit caller-empty                      ""                         reviewer 0`)
- `tests/fail-record-refutation.test.sh` (anchor: new file, mode 755)
- `tests/adapter-fail-tier-pin.test.js` (anchor: line matching `  '(\`unknown\` when the dispatch names no implementer tier)',`)
- `tests/validate.sh` (anchor: line matching `echo "== review-precheck: the reviewer's mechanical pre-review, failure lines are FAIL grounds (Bash, st-u2) =="`)
- `agents/reviewer.md` (anchors: `refutation — and, on a unit that meets the escalation trigger below, only`; `first (if fired), then \`ubiquitous-language\` (if fired) — never precede or`; `you return in your verdict, verbatim, and ending with one blank line so`; `- **On FAIL (both orchestration modes)**: also write a durable`)
- `templates/persona-protocol.md` (anchor: line matching `ladder never reads it), followed by the defect list from the verdict, verbatim. The record`)
- `adapters/codex/agents/reviewer.toml`, `adapters/cursor/agents/reviewer.md` (anchor: line matching `  the same defect list you return in your verdict, verbatim, ending with one`)
- `adapters/codex/agents-md-fragment.md`, `adapters/cursor/rules/persona-protocol.mdc` (anchor: line matching `defect list from the verdict, verbatim. No hook gate depends on it; it exists`)
- `.claude-plugin/plugin.json`, `package.json`, `CHANGELOG.md`
- generated only, by `node bin/cli.js --update`: `.claude/agents/*.md`, `.claude/persona-protocol.md`, `.claude/persona-protocol-slim.md`, `.claude/protocol-digest.md`, the config's `fileHashes` and `pluginVersion`

## Ordered edits
1. file: `tests/persona-prose-pins.test.sh`
   anchor: line matching `if [ "$fail" -eq 0 ]; then echo "All persona-prose-pins checks passed."; else echo "persona-prose-pins: FAILED"; fi`
   indent: 0
   insert-before:
~~~
for f in agents/reviewer.md .claude/agents/reviewer.md; do
  has "$f" 'Refutation pass (before any FAIL verdict)'
  has "$f" 'bash .claude/bin/refutation-brief.sh <baseline>'
  has "$f" '`model: sonnet`, in the foreground and with no `name:`'
  has "$f" 'confirm that the guard stops this defect on this defect'
  has "$f" 'You may keep a defect standing with a stated reason'
  has "$f" 'each UNCERTAIN one prefixed `[unconfirmed]`'
  has "$f" 'FAIL a defect you now reproduce yourself'
  has "$f" 'That PASS writes the same marker, stamp and flag state as any other PASS'
  has "$f" 'found no defect that survived the refutation pass'
  hasnot "$f" 'may not argue away'
  hasnot "$f" 'refuter'
done
for f in templates/persona-protocol.md .claude/persona-protocol.md; do
  has "$f" 'reproduce it before fixing it, and report one that does not reproduce'
done
~~~
   These pins prove that the instruction text shipped to both copies. They do not prove that it is
   followed. The behaviour-bearing checks are the fixture test (edit 3), the route-gate case (edit 2), the
   brief suite (rfp-u1) and the replay gate (criterion 8).
2. file: `tests/reviewer-route-gate-caller.test.sh`
   anchor: line matching `check_exit caller-empty                      ""                         reviewer 0`
   indent: 0
   insert-after:
~~~

# The refutation pass (agents/reviewer.md): a reviewer may spawn the explorer,
# and that nested dispatch writes no review-join stamp (rfp-u3).
check_exit caller-reviewer-target-explorer   reviewer                   explorer 0
if ls "$tmproot/caller-reviewer-target-explorer/.claude"/.review-join.* >/dev/null 2>&1; then
  echo "FAIL (caller-reviewer-target-explorer-no-stamp) a review-join stamp was written"
  fail=1
else
  echo "OK   (caller-reviewer-target-explorer-no-stamp) no review-join stamp"
fi
~~~
3. file: `tests/fail-record-refutation.test.sh` (new, mode 755), content:
~~~
#!/usr/bin/env bash
# rfp-u3: the FAIL record's refutation telemetry line and the `[unconfirmed]` prefix leave every reader of
# the record unaffected (fail-count, ladder-tier, escalation-card, unit-outcomes' FAIL classes), and the
# canonical protocol spells the grammar the fixture uses. Fixtures live under mktemp -d only.
set -uo pipefail
cd "$(dirname "$0")/.."
root="$(pwd)"
fail=0
ok()  { echo "OK   $*"; }
bad() { echo "FAIL $*"; fail=1; }

tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT
proj="$tmp/proj"
mkdir -p "$proj/.claude/reviewed"
rec="$proj/.claude/reviewed/u7.fail"
cat > "$rec" <<'EOF'
FAIL u7 2026-02-01T00:00:00Z
tier: haiku
- src/a.sh:2 first defect
- [unconfirmed] src/a.sh:5 second defect
refutation: confirmed=1 refuted=1 uncertain=1

FAIL u7 2026-02-02T00:00:00Z
tier: sonnet
- review-precheck printed a criterion failure line
refutation: skipped=mechanical

EOF

# (a) fail-count counts blocks, not lines
n="$(bash bin/fail-count.sh u7 "$proj")"
[ "$n" = 2 ] && ok "(a) fail-count prints 2" || bad "(a) fail-count printed [$n]"

# (b) ladder-tier reads n=2
lt="$(bash bin/ladder-tier.sh u7 --project "$proj")"
printf '%s' "$lt" | grep -q ' n=2 ' && ok "(b) ladder-tier n=2" || bad "(b) ladder-tier: $lt"

# (c) escalation-card prints each block's first defect line, never the telemetry line
card="$(bash bin/escalation-card.sh u7 "$proj")"
if printf '%s\n' "$card" | grep -qx '  - src/a.sh:2 first defect' \
   && printf '%s\n' "$card" | grep -qx '  - review-precheck printed a criterion failure line' \
   && ! printf '%s\n' "$card" | grep -q 'refutation:'; then
  ok "(c) escalation-card unaffected"
else
  bad "(c) escalation-card: $card"
fi

# (d) no telemetry token matches a unit-outcomes FAIL class substring (read from the live table)
d="$(node -e '
const s = require("fs").readFileSync("scripts/unit-outcomes.js", "utf8");
const m = s.match(/const CLASSES = (\[[\s\S]*?\n\]);/);
if (!m) { console.log("no-classes"); process.exit(0); }
const C = eval(m[1]);
const toks = ["refutation: confirmed=1 refuted=1 uncertain=1", "[unconfirmed]"]
  .concat(["mechanical", "over-cap", "resume", "no-subagent"].map((r) => "refutation: skipped=" + r));
const hits = [];
for (const t of toks) for (const [c, subs] of C) for (const x of subs) if (t.toLowerCase().includes(x)) hits.push(c + ":" + x);
console.log(hits.length ? "hits " + hits.join(",") : "clean");
')"
[ "$d" = clean ] && ok "(d) no FAIL-class collision" || bad "(d) $d"

# (e) every block ends with exactly one well-formed refutation line, and the protocol spells the grammar
shape="$(awk '
  /^FAIL u7 / { if (inb) { print last }; inb = 1; last = ""; next }
  inb && NF > 0 { last = $0 }
  END { if (inb) print last }
' "$rec" | grep -cvE '^refutation: (confirmed=[0-9]+ refuted=[0-9]+ uncertain=[0-9]+|skipped=(mechanical|over-cap|resume|no-subagent))$')"
flat="$(tr -s ' \n' ' ' < templates/persona-protocol.md)"
if [ "$shape" = 0 ] \
   && printf '%s' "$flat" | grep -qF 'then a last line `refutation: confirmed=<a> refuted=<b> uncertain=<c>`, or `refutation: skipped=<mechanical|over-cap|resume|no-subagent>`'; then
  ok "(e) grammar: fixture and canonical protocol agree"
else
  bad "(e) grammar: non-matching last lines=$shape, or the protocol lacks the grammar"
fi

if [ "$fail" -eq 0 ]; then echo "All fail-record-refutation checks passed."; else echo "fail-record-refutation: FAILED"; fi
exit "$fail"
~~~
   Run it: cases (a) to (d) pass and case (e) fails until edit 9. This is the red step.
4. file: `tests/adapter-fail-tier-pin.test.js`
   anchor: line matching `  '(\`unknown\` when the dispatch names no implementer tier)',`
   indent: 0
   insert-after:
~~~
  'then a last line `refutation: skipped=no-subagent`',
~~~
5. file: `tests/validate.sh`
   anchor: line matching `echo "== review-precheck: the reviewer's mechanical pre-review, failure lines are FAIL grounds (Bash, st-u2) =="`
   indent: 0
   insert-before:
~~~
echo "== fail-record-refutation: FAIL-record readers unaffected by the refutation line (Bash, rfp-u3) =="
if bash tests/fail-record-refutation.test.sh > /dev/null; then
  echo "OK   tests/fail-record-refutation.test.sh"
else
  echo "FAIL tests/fail-record-refutation.test.sh"
  fail=1
fi

echo
~~~
6. file: `agents/reviewer.md`
   before: `  refutation — and, on a unit that meets the escalation trigger below, only`
   after:
~~~
  defect that survived the refutation pass — and, on a unit that meets the
  escalation trigger below, only
~~~
   (The preceding line ends "you found no", so the sentence now reads "you found no defect that survived
   the refutation pass".)
7. file: `agents/reviewer.md`
   before: `  first (if fired), then \`ubiquitous-language\` (if fired) — never precede or`
   after:
~~~
  first (if fired), then `ubiquitous-language` (if fired), then `refutation`
  (if run) — never precede or
~~~
8. file: `agents/reviewer.md`
   before: `  you return in your verdict, verbatim, and ending with one blank line so`
   after:
~~~
  you return in your verdict, verbatim, then the `refutation:` line, and
  ending with one blank line so
~~~
   Then, in the same file, anchor: line matching `- **On FAIL (both orchestration modes)**: also write a durable`, indent 0, insert-before:
~~~
- **Refutation pass (before any FAIL verdict)**: a judgment defect (found
  by reading; a `review-precheck.sh` failure line, an uncommitted tree, an
  out-of-scope path, or a command you ran that shows the failure is
  mechanical, and a defect you reproduced that way is deliberately not
  sent) does not reach a FAIL verdict unchallenged. Merge duplicates (same
  `file:line` or same cause) first. Skip the pass, keeping every defect as
  found, and record why on the FAIL block's `refutation:` line: any
  mechanical ground (`skipped=mechanical`), more than 3 judgment defects
  (`skipped=over-cap`), the resume after an INSUFFICIENT-CONTEXT the pass
  caused (`skipped=resume`), or no subagent can be spawned
  (`skipped=no-subagent`). Otherwise pipe one `D<n>: <file:line> <claim>`
  line per defect into `bash .claude/bin/refutation-brief.sh <baseline>`
  and spawn `explorer` once with its output as the prompt, with
  `model: sonnet`, in the foreground and with no `name:`. For each answer
  line, re-check the artifact yourself: re-run the command or read the
  cited lines, and for a mitigation confirm that the guard stops this
  defect on this defect's own path, not only that the quoted line exists.
  Then state in your own words why the artifact proves or defeats the
  claim. You may keep a defect standing with a stated reason; a defect
  whose artifact does not reproduce, or that got no answer line, stands as
  found. A defect already at the baseline is REFUTED unless it is an unmet
  acceptance criterion. If any defect stands or is CONFIRMED, return FAIL
  with those and with each UNCERTAIN one prefixed `[unconfirmed]`, ending
  the FAIL block with `refutation: confirmed=<a> refuted=<b> uncertain=<c>`;
  the REFUTED ones and your reasons go in the `refutation` advisory
  section. If none stands and one or more is UNCERTAIN, return
  INSUFFICIENT-CONTEXT, its `missing:` naming the evidence that would
  settle each; on the resume, without a second pass, FAIL a defect you now
  reproduce yourself, and make one you cannot reproduce a
  `NOTE[code]: unconfirmed:` line. If all are REFUTED, apply the PASS rules
  (escalation included) and add one
  `NOTE[code]: refuted: D<n> <claim> — <artifact> — <why it defeats the claim>`
  line per defect to the marker's notes (under review gating off, to the
  `refutation` section instead). That PASS writes the same marker, stamp and
  flag state as any other PASS. The pass itself writes no marker; a FAIL it
  prevents writes no `.fail` block, so the FAIL-block count and the
  Escalation ladder only count FAILs that survived it.
~~~
   Do not reflow it. Criterion 5 budgets the reviewer.md diff (edits 6 to 8) at 45 added and 3 removed lines;
   spec-master's scratch copy measured +43 and -3.
9. file: `templates/persona-protocol.md`
   before: `ladder never reads it), followed by the defect list from the verdict, verbatim. The record`
   after:
~~~
ladder never reads it), followed by the defect list from the verdict, verbatim,
then a last line `refutation: confirmed=<a> refuted=<b> uncertain=<c>`, or
`refutation: skipped=<mechanical|over-cap|resume|no-subagent>` when the
reviewer's refutation pass did not run; that line is telemetry, never a defect.
A defect prefixed `[unconfirmed]` is one the refutation pass could neither prove
nor disprove: reproduce it before fixing it, and report one that does not
reproduce instead of changing code for it. The record
~~~
10. files: `adapters/codex/agents/reviewer.toml` and `adapters/cursor/agents/reviewer.md` (each once)
    before: `  the same defect list you return in your verdict, verbatim, ending with one`
    after:
~~~
  the same defect list you return in your verdict, verbatim, then a last line
  `refutation: skipped=no-subagent` (this port runs no refutation pass), ending with one
~~~
11. files: `adapters/codex/agents-md-fragment.md` and `adapters/cursor/rules/persona-protocol.mdc` (each once)
    before: `defect list from the verdict, verbatim. No hook gate depends on it; it exists`
    after:
~~~
defect list from the verdict, verbatim, then a last line
`refutation: skipped=no-subagent` (this port runs no refutation pass; the line
is telemetry, never a defect). No hook gate depends on it; it exists
~~~
12. command: `perl -0pi -e 's/("version": "\d+\.\d+\.)(\d+)"/$1.($2+1)."\""/e' .claude-plugin/plugin.json package.json`
    expect: 0 (+1 on whatever is current at dispatch)
13. file: `CHANGELOG.md`
    anchor: line matching `## [Unreleased]`
    indent: 0
    insert-after:
~~~

**Reviewer refutation pass and FAIL-record telemetry (rfp-u3, VERSION).** `agents/reviewer.md` gains "Refutation pass (before any FAIL verdict)". Before a FAIL whose grounds are all judgment defects (1 to 3 after deduplication), the reviewer pipes them into `.claude/bin/refutation-brief.sh` and spawns one `explorer` (`model: sonnet`, foreground, unnamed) to disprove each against the whole file, its callers and the baseline. It re-checks every artifact itself (a guard must stop the defect on its own path), states its own reason, and may keep a defect standing. If all are refuted, the verdict is PASS with `NOTE[code]: refuted:` notes and no FAIL block. If only UNCERTAIN defects remain, the verdict is INSUFFICIENT-CONTEXT. UNCERTAIN defects in a FAIL are prefixed `[unconfirmed]`. `templates/persona-protocol.md`'s FAIL record now ends every block with `refutation: confirmed=<a> refuted=<b> uncertain=<c>` or `refutation: skipped=<mechanical|over-cap|resume|no-subagent>`; the codex and cursor ports write `skipped=no-subagent`. Enabled after the replay gate passed (`eval/refutation-replay/`). New `tests/fail-record-refutation.test.sh` (readers unaffected); prose pins and a route-gate case added. Spec: `docs/plans/2026-10-27-refutation-pass.md`.
~~~
    Replace `VERSION` with the version edit 12 wrote.
14. command: `node bin/cli.js --update`
    expect: 0
15. command: `bash -c 'for t in persona-prose-pins reviewer-route-gate-caller fail-record-refutation; do bash tests/$t.test.sh >/dev/null || echo "red $t"; done; node tests/adapter-fail-tier-pin.test.js >/dev/null || echo "red tier-pin"; node tests/adapter-protocol-parity.test.js >/dev/null || echo "red parity"; echo done'`
    expect: stdout `done` only
16. command: `git add tests/persona-prose-pins.test.sh tests/reviewer-route-gate-caller.test.sh tests/fail-record-refutation.test.sh tests/adapter-fail-tier-pin.test.js tests/validate.sh agents/reviewer.md templates/persona-protocol.md adapters/codex/agents/reviewer.toml adapters/cursor/agents/reviewer.md adapters/codex/agents-md-fragment.md adapters/cursor/rules/persona-protocol.mdc .claude-plugin/plugin.json package.json CHANGELOG.md && git add -u -- .claude ':(exclude).claude/agent-memory' && git commit -m "feat(rfp-u3): the reviewer runs a refutation pass on its judgment defects; FAIL blocks end with a refutation line"`
    expect: 0
    Run `git status --short` first. If a tracked file outside "Affected files" is modified, stop and report it.
    Every later commit of this unit that touches `agents/` or `templates/` (a fix round) repeats edits 12 to 14
    in that same commit and keeps `(rfp-u3)` in its subject. Constitution P3 is checked per commit
    (criterion 7).

## Do NOT touch
- `agents/orchestrator.md`, `agents/explorer.md` (routing does not change; criterion 6)
- `agents/task-master.md`, `agents/milestone-auditor.md` (rfp-u4's; criterion 6)
- `hooks/` and `.claude/hooks/` (the gates already admit the nested spawn; criterion 6)
- `bin/` (`fail-count.sh`, `ladder-tier.sh` and `escalation-card.sh` are unaffected by design, as edit 3 proves; criterion 6)
- `eval/` (the replay is rfp-u2's and Gate G's; criterion 6)
- `CONTEXT.md`, `docs/harness-glossary.md`, `docs/adr/` (rfp-u5's; criterion 6)
- `.claude/` mirrors by hand (only `node bin/cli.js --update` writes them)

## Acceptance criteria
1. run: `bash -c 'out=$(bash tests/persona-prose-pins.test.sh); rc=$?; printf "%s\n" "$out" | grep -c "^FAIL"; echo "rc=$rc"'`
   exit: 0
   stdout: `0` then `rc=0`
   mutation: skip edit 14 (`--update`); the `.claude/agents/reviewer.md` and `.claude/persona-protocol.md` `has` pins fail, so stdout is `10` then `rc=1`.
2. run: `bash -c 'bash tests/fail-record-refutation.test.sh >/dev/null; echo $?'`
   exit: 0
   stdout: `0`
   mutation: revert edit 9; case (e) fails and stdout is `1`. In the fixture, moving a `refutation:` line above its block's first defect fails case (c), because escalation-card prints it as the first defect line.
3. run: `bash -c 'node tests/adapter-fail-tier-pin.test.js | grep -c "^FAIL"; true'`
   exit: 0
   stdout: `0`
   mutation: skip edit 11 for `adapters/cursor/rules/persona-protocol.mdc`; stdout is `1`.
4. run: `bash -c 'out=$(bash tests/reviewer-route-gate-caller.test.sh 2>&1); rc=$?; printf "%s\n" "$out" | grep -c "^OK   (caller-reviewer-target-explorer"; echo "rc=$rc"'`
   exit: 0
   stdout: `2` then `rc=0`
   mutation: in a scratch copy of `hooks/scripts/reviewer-route-gate.sh` and `lib/`, replace `if [ -f "$config" ] && persona_matches_gate "$target_type" reviewer; then` with `if [ -f "$config" ]; then` and run with `GATE_UNDER_TEST`; the no-stamp case fails, stdout is `1` then `rc=1` (spec-master ran it).
5. run: `bash -c 'b=$(git log --format=%H --grep="(rfp-u3)" | tail -1); l=$(git log --format=%H --grep="(rfp-u3)" | head -1); [ -n "$b" ] || { echo no-commits; exit 1; }; git diff --numstat "$b^..$l" -- agents/reviewer.md | awk "{print (\$1<=45 && \$2<=3) ? \"ok\" : \"over \" \$1 \" \" \$2}"'`
   exit: 0
   stdout: `ok`
   mutation: paste the edit 8 bullet twice; stdout is `over 81 3`.
6. run: `bash -c 'b=$(git log --format=%H --grep="(rfp-u3)" | tail -1); l=$(git log --format=%H --grep="(rfp-u3)" | head -1); [ -n "$b" ] || { echo no-commits; exit 1; }; git diff --name-only "$b^..$l" -- agents/orchestrator.md agents/explorer.md agents/task-master.md agents/milestone-auditor.md hooks bin eval CONTEXT.md docs/harness-glossary.md docs/adr | wc -l'`
   exit: 0
   stdout: `0`
   mutation: edit `agents/task-master.md` in an rfp-u3 commit; stdout is at least `1`.
7. run: `bash -c 'b=$(git log --format=%H --grep="(rfp-u3)" | tail -1); l=$(git log --format=%H --grep="(rfp-u3)" | head -1); [ -n "$b" ] || { echo no-commits; exit 1; }; bash hooks/scripts/version-stamp-check.sh "$b^..$l" | cut -d" " -f1-4'`
   exit: 0
   stdout: `version-stamp-check: ok touched: yes`
   mutation: skip edit 12; stdout reads `version-stamp-check: violation touched: yes`.
8. run: `bash -c 'python3 eval/refutation-replay/score.py eval/refutation-replay/report.jsonl --gate | cut -d" " -f1-2; echo "rc=${PIPESTATUS[0]}"'`
   exit: 0
   stdout: `replay-gate: pass` then `rc=0`
   mutation: in a scratch copy of the report and `labels.tsv`, set the `answer` of two `real` rows to `REFUTED` with a non-empty artifact; the scratch copy scores `replay-gate: fail` and `rc=1`. With no report (Gate G not run), stdout is `replay-gate: insufficient` then `rc=2`.
9. run: `bash -c 'bash tests/validate.sh >/dev/null 2>&1; echo $?'` (Bash tool timeout 600000 ms)
   exit: 0
   stdout: `0`
   mutation: put `exit 1` as line 2 of `tests/fail-record-refutation.test.sh`; validate.sh reports it (edit 5) and stdout is `1`.

## Pre-resolved context
- spec-master applied edits 6 to 11 to scratch copies at 958f557e.
  - Every `before:` text occurs exactly once.
  - The reviewer.md diff measured +43/-3.
  - Every pin in edit 1 matches once in the edited copies after `tr -s ' \n' ' '` and never at 958f557e.
  - `may not argue away` and `refuter` are absent.
  - Each of the four ports carries `then a last line \`refutation: skipped=no-subagent\`` once after
    flattening.
- spec-master ran edit 3's test in this repo: cases (a) to (d) pass against the live `bin/fail-count.sh`,
  `bin/ladder-tier.sh`, `bin/escalation-card.sh` and `scripts/unit-outcomes.js` `CLASSES`, and (e) fails
  until edit 9.
- Readers: `bin/escalation-card.sh:25-29` prints the first non-empty line after `tier:`, so the telemetry
  line must be the block's **last** line. `scripts/unit-outcomes.js:11-19` classes are substring matches;
  case (d) reads the live table.
- `tests/adapter-protocol-parity.test.js` probes section headings only. No heading changes here.
- No reviewer prompt pins "On FAIL" or "INSUFFICIENT-CONTEXT" text. `tests/fail-marker-format-parity.test.sh`
  uses hard-coded fixtures and is unaffected.
- The explorer: `agents/explorer.md` sets `maxTurns: 10`, and the `Agent` tool has no per-spawn turn
  parameter, which is why the cap is 3. Spawn by the explicit name `explorer`, never `Explore`.

## Escalation
If Gate G has not printed `replay-gate: pass`, do not start: report it. If a `before:` or anchor text is not
found exactly once, stop and report the current text. If `node bin/cli.js --update` refuses (for example on
the cross-reference assertion), quote its message and stop. If a gate blocks a command, report it and wait.
Anything outside "Affected files" goes in your report as a proposal.
