Unit: qw-u3

## Objective
Shorten two protocol sections that full-tier personas inline, with every live rule kept and pinned.
- "Review markers and gate mechanics (owner-facing)", inlined by orchestrator, reviewer, spec-master,
  task-master and milestone-auditor: paragraph 1 loses its provenance note and becomes rule P1 plus P2;
  paragraph 2 (the two axes) loses the ADR-0028 cause story and keeps both glossary terms (P3).
- "Terminal status line", inlined by every full-tier persona: three asides are cut ("not an exemption",
  the long "Why it exists", the long "Not an alternative to the WIP sentinel"), and so is the closing
  sentence of "Keep that resume cheap". The rules P4 to P7 stay.

Each of those five mirrors shrinks by at least 1200 bytes, and `.claude/agents/lead-programmer.md` by at
least 500. The codex and cursor protocol ports already carry condensed versions of these paragraphs, so
they are not edited. This is spec Step 3 (b-1 ii).

## Retrieval
Fast path, no tracker issue. Spec: `docs/plans/antislop-quick-wins/spec.md`, "Step 3 (qw-u3)" and "Context,
b". This file is the contract of record. Dispatch it only after qw-u2 has reached PASS (it extends qw-u2's
`tests/prompt-diet-pins.test.sh`).

## Affected files
- `templates/persona-protocol.md` (sections "## Review markers and gate mechanics (owner-facing)" and "## Terminal status line (every dispatched turn)")
- `tests/prompt-diet-pins.test.sh` (anchor: line matching `# qw-u3 appends its rows below this line.`)
- `.claude-plugin/plugin.json`, `package.json`, `CHANGELOG.md`
- generated only, by `node bin/cli.js --update`: `.claude/persona-protocol.md`, `.claude/agents/*.md` (the six full-tier mirrors) and the config's `fileHashes`

## Ordered edits
1. file: `tests/prompt-diet-pins.test.sh`
   anchor: line matching `# qw-u3 appends its rows below this line.`
   indent: 0
   before: `# qw-u3 appends its rows below this line.`
   after:
~~~
# qw-u3: protocol narrative trim. Rules P1-P7 stay in the protocol and in every mirror that inlines
# their section; the provenance note, the ADR-0028 cause story and three status-line asides are removed.
for f in templates/persona-protocol.md .claude/persona-protocol.md .claude/agents/orchestrator.md \
         .claude/agents/reviewer.md .claude/agents/spec-master.md .claude/agents/task-master.md \
         .claude/agents/milestone-auditor.md; do
  has "$f" 'Only one unit is ever mid-review'
  has "$f" 'scoped to the stopping reviewer'"'"'s own stamped units'
  has "$f" '**unit-exclusivity axis**'
  has "$f" '**advisory-reviewer axis**'
  has "$f" 'ADR-0016'
  has "$f" 'ADR-0028'
  hasnot "$f" 'Moved here from Review ownership'
  hasnot "$f" 'a test-hygiene defect, not a violation of unit-exclusivity'
done
for f in templates/persona-protocol.md .claude/persona-protocol.md .claude/agents/orchestrator.md \
         .claude/agents/reviewer.md .claude/agents/spec-master.md .claude/agents/task-master.md \
         .claude/agents/milestone-auditor.md .claude/agents/lead-programmer.md; do
  has "$f" '`^STATUS: (complete|incomplete [—-] .+)$`'
  has "$f" 'The main session answering its user directly has no caller, so there is nothing to sign.'
  has "$f" '**zero content blocks**'
  has "$f" 'Do not replace it with a hook.'
  has "$f" '<the same reason you wrote into the sentinel>'
  has "$f" 'reply with a brief one-or-two-sentence confirmation and the status line'
  hasnot "$f" 'stated as fact, so nobody later'
  hasnot "$f" 'defeats the whole point of it being cheap'
done

# qw-u4 appends its rows below this line.
~~~
2. command: `bash tests/prompt-diet-pins.test.sh`
   expect: 1
   The red step: the new rows fail before the protocol edits.
3. file: `templates/persona-protocol.md`
   anchor: line matching `## Review markers and gate mechanics (owner-facing)` (paragraph 1; rules P1 and P2)
   indent: 0
   before:
~~~
Moved here from Review ownership; the implementer-facing text stays there. In
full, the invariant reads:
only one unit is ever mid-review — which is also what the `.blocked` marker's
flag-keeping heuristic depends on (an INSUFFICIENT-CONTEXT verdict leaves the
pending-review flag standing rather than clearing it): the route-gate already
blocks the next gated dispatch while any pending-review flag stands, so there
is never a second unit's flag to confuse with the blocked one. The marker check
is scoped to the stopping reviewer's own stamped units (falling back to a
directory-wide check when scoping information is unavailable) so that a stray
or orphaned `.blocked` marker from an unrelated unit cannot jam unrelated
reviewers' operations — this scoped-relevance mechanism (see ADR-0028,
`docs/adr/0028-scoped-marker-relevance-leaked-stamp-asymmetry.md`) is
a complementary safety layer that works alongside the one-unit-at-a-time invariant.
~~~
   after:
~~~
Only one unit is ever mid-review. The `.blocked` marker's flag-keeping heuristic depends on that (an
INSUFFICIENT-CONTEXT verdict leaves the pending-review flag standing rather than clearing it): the
route-gate already blocks the next gated dispatch while any pending-review flag stands, so there is never a
second unit's flag to confuse with the blocked one. The marker check is scoped to the stopping reviewer's
own stamped units (falling back to a directory-wide check when scoping information is unavailable), so a
stray or orphaned `.blocked` marker from an unrelated unit cannot jam unrelated reviewers' operations
(ADR-0028, `docs/adr/0028-scoped-marker-relevance-leaked-stamp-asymmetry.md`).
~~~
4. file: `templates/persona-protocol.md`
   anchor: line matching `These are two different axes, stated explicitly so neither is misread as` (paragraph 2; rule P3)
   indent: 0
   before:
~~~
These are two different axes, stated explicitly so neither is misread as
contradicting the other. The **unit-exclusivity axis** is the one-unit-at-a-
time invariant just stated: at most one unit is ever mid-review. The
**advisory-reviewer axis** is orthogonal: the same single unit may still
carry a second, advisory reviewer (a Roast-style pass, if present, that owns
no verdict and writes no marker — otherwise the unit has exactly one
reviewer). ADR-0016 (`docs/adr/0016-per-unit-review-join.md`) names this
second axis's liveness trap for that advisory second reviewer directly.
Neither axis's rule changes here: ADR-0028's
scoped-relevance fix was caused by `tests/marker-write.test.sh` leaking
fixture markers into the real marker directory — a test-hygiene defect, not
a violation of unit-exclusivity or a concurrent-reviewer scenario.
~~~
   after:
~~~
Two orthogonal axes: the **unit-exclusivity axis** is the invariant just stated (at most one unit is
ever mid-review); the **advisory-reviewer axis** lets that same unit also carry a second, advisory reviewer
(a Roast-style pass, if present) that owns no verdict and writes no marker; otherwise the unit has exactly
one reviewer. ADR-0016 (`docs/adr/0016-per-unit-review-join.md`) names that second reviewer's liveness
trap.
~~~
5. file: `templates/persona-protocol.md`
   anchor: line matching `**When it applies:** every turn-end where control returns to a caller` (rule P4)
   indent: 0
   before:
~~~
**When it applies:** every turn-end where control returns to a caller — a
dispatched subagent's returned result, and a teammate's `SendMessage` report to
the lead in agent-teams mode. The main session answering its user directly has
no caller, so there is nothing to sign. That is a trigger condition, **not an
exemption** — the rule lives in the one shared section every persona carries,
so a persona that gains a turn cap later is covered automatically.
~~~
   after:
~~~
**When it applies:** every turn-end where control returns to a caller — a
dispatched subagent's returned result, and a teammate's `SendMessage` report to
the lead in agent-teams mode. The main session answering its user directly has
no caller, so there is nothing to sign.
~~~
6. file: `templates/persona-protocol.md`
   anchor: line matching `**Why it exists** (stated as fact` (rule P5)
   indent: 0
   before:
~~~
**Why it exists** (stated as fact, so nobody later "fixes" it with a hook): you
cannot see your own turn count, you cannot see your own cap being hit, and the
harness renders the `max_turns_reached` attachment as **zero content blocks**.
A turn truncated mid-work is therefore indistinguishable from a finished one —
unless a finished one carries a signature. This line is that signature, and its
absence is the only available evidence of a cutoff.
~~~
   after:
~~~
**Why it exists:** you cannot see your own turn count or cap, and the harness renders the
`max_turns_reached` attachment as **zero content blocks**, so a truncated turn looks finished unless a
finished turn carries this signature. Do not replace it with a hook.
~~~
7. file: `templates/persona-protocol.md`
   anchor: line matching `**Not an alternative to the WIP sentinel**` (rule P6)
   indent: 0
   before:
~~~
**Not an alternative to the WIP sentinel** (the file at
`.claude/wip-handoff.<agent-id>`) — the two are different mechanisms and they
co-occur. The sentinel is a *file* written with a non-empty reason before a
voluntary pause; the status line is a *report line* emitted at every
turn-end. A sentinel turn-end therefore ends with `STATUS: incomplete — <the
same reason you wrote into the sentinel>`.
~~~
   after:
~~~
It co-occurs with the WIP sentinel (the file at `.claude/wip-handoff.<agent-id>`): a sentinel turn-end
ends with `STATUS: incomplete — <the same reason you wrote into the sentinel>`.
~~~
8. file: `templates/persona-protocol.md`
   anchor: line matching `**Keep that resume cheap.**` (rule P7; the payload is the paragraph's last two lines)
   indent: 0
   before:
~~~
accurate. A confirmation resume that turns into a full re-run defeats the
whole point of it being cheap.
~~~
   after: `accurate.`
9. command: `perl -0pi -e 's/("version": "\d+\.\d+\.)(\d+)"/$1.($2+1)."\""/e' .claude-plugin/plugin.json package.json`
   expect: 0
   This adds one to the patch version in both files (expected 0.31.189 to 0.31.190).
10. file: `CHANGELOG.md`
   anchor: line matching `## [Unreleased]`
   indent: 0
   insert-after:
~~~

**Protocol narrative trim (qw-u3, VERSION).** templates/persona-protocol.md: "Review markers and gate mechanics (owner-facing)" drops its provenance note and the ADR-0028 cause story and keeps both axis terms; "Terminal status line" drops three asides and keeps every rule. Every full-tier persona prompt is smaller (about 1361 bytes for the five that inline "Review markers", 687 for lead-programmer). New rows in tests/prompt-diet-pins.test.sh pin each kept rule.
~~~
   Replace `VERSION` with the version that edit 9 wrote.
11. command: `node bin/cli.js --update`
   expect: 0
12. command: `bash tests/prompt-diet-pins.test.sh`
   expect: 0
13. command: `git add -u && git commit -m "feat(qw-u3): trim protocol narratives; every rule kept and pinned"`
   expect: 0
   Run `git status --short` first: if a tracked file outside "Affected files" is modified, stop and report it.

## Do NOT touch
- `adapters/codex/agents-md-fragment.md` and `adapters/cursor/rules/persona-protocol.mdc` (their condensed paragraphs need no trim; criterion 3)
- `templates/persona-protocol-slim.md` (the slim tier has its own short status-line text)
- `bin/cli.js` (no matrix change; section headings are unchanged, so `tests/protocol-doc-drift.test.js` counts stay valid)
- `CONTEXT.md` (it defines the two axis terms, which the new text keeps)
- `.claude/persona-protocol.md` and `.claude/agents/` by hand (only `node bin/cli.js --update` writes them)

## Acceptance criteria
1. run: `bash -c 'bash tests/prompt-diet-pins.test.sh >/dev/null; echo $?'`
   exit: 0
   stdout: `0`
   mutation: skip edit 4; the template still holds `a test-hygiene defect, not a violation of unit-exclusivity`, that hasnot row fails and stdout is `1`.
2. run: `bash -c 'b=$(git log --format=%H --grep="(qw-u3)" | tail -1); for p in orchestrator reviewer spec-master task-master milestone-auditor lead-programmer; do f=.claude/agents/$p.md; old=$(git show "$b^:$f" | wc -c); new=$(wc -c < "$f"); need=1200; [ $p = lead-programmer ] && need=500; [ $(( old - new )) -ge $need ] || echo "$p saved $(( old - new )) < $need"; done'`
   exit: 0
   stdout: empty
   mutation: skip edits 3 and 4; the five Review-markers mirrors shrink by only about 687 bytes and each prints a `saved ... <` line.
3. run: `bash -c 'b=$(git log --format=%H --grep="(qw-u3)" | tail -1); git diff --name-only "$b^..HEAD" -- adapters bin hooks | wc -l'`
   exit: 0
   stdout: `0`
   mutation: edit `adapters/codex/agents-md-fragment.md` in a qw-u3 commit; stdout is at least `1`.
4. run: `bash -c 'node tests/adapter-protocol-parity.test.js >/dev/null && node tests/protocol-doc-drift.test.js >/dev/null && node tests/protocol-cross-references.test.js >/dev/null && bash tests/persona-prose-pins.test.sh >/dev/null; echo $?'`
   exit: 0
   stdout: `0`
   mutation: add a line starting `## ` inside the trimmed section; protocol-doc-drift's section count no longer matches and stdout is `1`.
5. run: `bash -c 'b=$(git log --format=%H --grep="(qw-u3)" | tail -1); bash hooks/scripts/version-stamp-check.sh "$b^..HEAD" | cut -d" " -f1-4'`
   exit: 0
   stdout: `version-stamp-check: ok touched: yes`
   mutation: skip the version-bump edit; stdout reads `version-stamp-check: violation touched: yes`.
6. run: `bash -c 'bash tests/validate.sh >/dev/null 2>&1; echo $?'` (Bash tool timeout 600000 ms)
   exit: 0
   stdout: `0`
   mutation: put `exit 1` as line 2 of tests/prompt-diet-pins.test.sh; validate.sh exits 1 and stdout is `1`.

## Pre-resolved context
tdd: yes the new pins rows (edit 1) fail first (edit 2); spec-master applied edits 3 to 8 to a copy of the template and every before payload matched exactly once.
blast-radius: templates/persona-protocol.md:238 (Review markers, paragraphs 1 and 2), templates/persona-protocol.md:148 (Terminal status line), bin/cli.js:790 (PROTOCOL_SECTIONS_BY_PERSONA decides which mirrors inline which section). Line numbers are at bce2ded2.
rule-map: P1 one unit mid-review; `.blocked` keeps the flag -> kept (edit 3). P2 marker check scoped to the stopping reviewer's stamped units, ADR-0028 -> kept (edit 3). P3 the two axes with their glossary terms, ADR-0016 -> kept (edit 4). P4 when the status line applies; the main session signs nothing -> kept (edit 5). P5 why it exists; no hook replacement -> kept (edit 6). P6 co-occurs with the WIP sentinel, same reason -> kept (edit 7). P7 a confirmation-only resume stays cheap -> kept (edit 8 removes only the closing sentence).
measured: Review markers -674 bytes, Terminal status line -687 bytes (template, measured by spec-master on the current text). The targets (1200 and 500) leave about 150 bytes of slack for rewrapping.
four-copy: `grep -F` for each removed phrase in `adapters/codex/agents-md-fragment.md` and `adapters/cursor/rules/persona-protocol.mdc` finds none of them; those ports already use one-sentence versions.
prior-fail: item10-1-name-the-two-axes added paragraph 2; its terms are glossary entries in CONTEXT.md, so edit 4 keeps both bold terms and the pins check them.
version: .claude-plugin/plugin.json and package.json read 0.31.189 after qw-u2 if no fix round bumped; edit 9 adds one (expected 0.31.190).
mirrors: `.claude/` copies change only through `node bin/cli.js --update` (constitution P2).
commit-message: feat(qw-u3): trim protocol narratives; every rule kept and pinned
diagnosis: none
review-packet:
~~~
unit: qw-u3
changed files: <FILL: changed files>
commit: <FILL: commit SHA>
criterion 1: <FILL: exit and stdout>
criterion 2: <FILL: exit and stdout>
criterion 3: <FILL: exit and stdout>
criterion 4: <FILL: exit and stdout>
criterion 5: <FILL: exit and stdout>
criterion 6: <FILL: exit and stdout>
~~~

## Escalation
If a `before:` payload is not found verbatim (an earlier unit may have changed the template), stop and
report the current text. If `node bin/cli.js --update` refuses (for example a cross-reference assertion in
`bin/cli.js`), quote its message and stop. If a gate blocks a command, report it and wait. Anything outside
"Affected files" goes to your report as a proposal.
