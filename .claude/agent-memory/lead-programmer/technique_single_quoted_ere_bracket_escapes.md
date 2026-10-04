---
name: single-quoted-ere-bracket-escapes
description: in a bash `[[ =~ ]]` ERE built in single quotes, `\t`/`\n` inside a bracket expression are literal backslash, t, n — a tab never matches and the letters t and n get excluded (qp-1 FAIL #1)
metadata:
  type: feedback
---

`re='...[ \t]+-[^ \t\n;&|]*...'` looks right but POSIX ERE has no escapes inside brackets:
`[ \t]` is space/backslash/t, `[^ \t\n]` forbids the letters t and n. The qp-1 rule silently
missed tab separators and every option word holding n or t (--login, --norc, -n); my family
table only ever used `-e`, so no row varied that character dimension.

**Why:** reviewer FAILed qp-1 on it (hdg-prose-2 failure mode: a predicate dimension the
frozen table never varied).

**How to apply:** use POSIX classes under `LC_ALL=C` (`[[:blank:]]`, `[^[:space:];&|]`) or
build the set with `$'...'`. For any new regex predicate, list each character class/separator
and add a row varying it (tab, letters the class might exclude, `+` options, case), each with
its own single-branch mutant. Factor a repeated class into a local so one mutant covers it.
