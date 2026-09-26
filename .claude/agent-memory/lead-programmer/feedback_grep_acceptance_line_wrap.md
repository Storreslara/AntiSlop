---
name: feedback_grep_acceptance_line_wrap
description: Multi-word grep -q acceptance anchors in hand-wrapped persona .md prose must not span a line wrap, and must match literally (hyphen vs space)
metadata:
  type: feedback
---

When an acceptance criterion is `grep -q "some multi-word phrase"` against a
hand-wrapped markdown file (persona files like `agents/orchestrator.md` wrap
prose at ~78 cols), `grep -q` only matches within a single line — a phrase
split across a line-wrap boundary silently fails with no error, it just
doesn't print.

**Why:** Self-caught while implementing issue #95 (Step 6 of
[[project_threefold_update]]'s sibling plan,
`docs/plans/2026-07-21-subagent-background-self-wake-protocol.md`): wrote
"still genuinely\nrunning" split across two wrapped lines, and separately
wrote `WIP-sentinel` (hyphenated) when the acceptance grep required `WIP
sentinel` (space) — both compiled/read fine as prose but failed their
literal-string check silently until I ran the exact acceptance command
myself instead of eyeballing the diff.

**How to apply:** After any prose edit whose acceptance criteria are
literal-string greps, always run the exact grep commands from the
plan/issue verbatim (not a paraphrase) before reporting ready-for-review,
and re-check every multi-word anchor phrase stays on one line post-edit —
don't trust that "the words are all in there somewhere" is equivalent to
"the exact substring matches."

**Corollary — a `grep -c ... -> N` criterion constrains YOUR OWN comments in
the same file.** On issue #131 the criterion was `grep -c 'human-review'
.gitignore` → exactly 1, and the explanatory comment I wrote directly above
the `.claude/human-review/` entry ("...+ human-review escalation packets...")
made it 2. The file's own prose/comments count toward a bare-substring
`grep -c`, so when a criterion pins an exact count, word any nearby comment to
avoid the anchor string entirely rather than assuming only the data lines are
counted.

**Same failure mode inside a JS test's `String.prototype.includes()` probe,
not just `grep`.** On unit `examples-2`
(`docs/plans/2026-08-20-quiz-to-worked-examples.md`), porting protocol prose
into `adapters/codex/agents-md-fragment.md` /
`adapters/cursor/rules/persona-protocol.mdc` wrapped the literal phrase
`never graded by the reviewer` across a line break, silently failing
`tests/adapter-protocol-parity.test.js`'s `portText.includes(probe)` check
with no diagnostic beyond "expected present but missing" — same root cause as
the `grep -q` case, different tool. Also hit the negative-corollary: a stale
descriptive comment in the test file itself (`gh300 (QUIZ.md)`) tripped the
unit's own `git grep -ci quiz` acceptance criterion. Both apply to any literal
substring check, not just `grep`.

**Same failure mode inside a `cat >&2 <<'EOF'` denial-message heredoc.** On
gh419 (refusal-message disclosure hygiene), the new prohibition sentence
"...self-authorized bypass whether or not this gate blocks it" wrapped across
two heredoc lines in `human-decision-gate.sh`'s `deny()`, so
`tests/refusal-disclosure.test.sh`'s `grep -cF` against the gate's real
runtime stderr returned 0 until reworded onto one line. The sibling gate's
same sentence sat inside a single long `echo "..."` string (never wrapped) and
passed first try — wrapping risk is specific to hand-wrapped multi-line
heredocs/prose, not long single-line strings.

**Recurred writing NEW prose, not just porting it.** On item12-3, a freshly
authored sentence for `templates/persona-protocol.md` § "FAIL record"
("appends a block per FAIL verdict rather than overwriting the previous one,
so the FAIL count is readable across sessions") wrapped its own key phrases
across the paragraph's existing ~78-col hard-wrap the first time I wrote it —
a wrap-tolerant (`tr '\n' ' ' | grep`) self-check caught the meaning was
present but a plain single-line `grep` would still fail. Deliberately chose
the wrap point (put a full short line before the break) rather than trusting
prose flow, then re-verified with a plain `grep -c` after re-render. Apply
this on every net-new sentence added to a hard-wrapped file, not just when
porting an existing one.
