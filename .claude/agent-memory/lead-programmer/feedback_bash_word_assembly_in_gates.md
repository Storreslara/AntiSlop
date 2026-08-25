---
name: bash-word-assembly-in-gates
description: Any gate scanning command text for a path must JOIN adjacent quoted/unquoted fragments; quotes are not word terminators in bash
metadata:
  type: feedback
---

When a hook scans raw Bash command text for a path, never treat `'` or `"` as a
run terminator. Bash concatenates adjacent quoted and unquoted fragments into
ONE word, so `'.claude/x/'"FILE"`, `"a""b"` and `a'b'c` all name the same path a
bare spelling does. Delete the quote characters and join; keep whitespace as a
terminator (a bash word may contain a space, a protected filename generally
cannot — that is what stops prose from reading as a path).

Two places need it, not one: the run scan AND any cheap substring early-exit
ahead of it. A split falling INSIDE a token (`human-rev'iew'`, `"DEC"'IS'"ION"`)
means the raw text spells neither token, so an early-exit on raw text returns
before the scan ever runs. Quote-deletion can only ADD occurrences, never
remove one, so joining before the early-exit strictly subsumes the raw test.

**Why:** hdg-prose-2 FAILed review on exactly this — a fail-open that let
`printf x > '.claude/human-review/u1/''DECISION'` really create the protected
file. Root cause framing from the roast: the change had replaced a *syntactic*
invariant ("this command cannot redirect at all") with a *semantic* one ("its
redirect target cannot be my file"), and the semantic one requires modelling
bash's word-assembly rules correctly.

**How to apply:** whenever touching `human-decision-gate.sh` or
`reviewed-path-gate.sh`, or writing any new recognizer over command text. Also
measure, don't assume, the sibling expansions: an unquoted variable holding the
whole path IS a live write, but brace expansion yielding two words is an
"ambiguous redirect" that writes nothing, and `{FILE}` alone is not expanded at
all. See [[mutation-proof-needs-a-sole-denier]] — prove each new condition with
a case only it denies.
