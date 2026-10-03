---
name: bash-glob-bytewise-fallback-locale
description: bash [[ == ]] byte patterns already match bytewise under C.UTF-8, so a `local LC_ALL=C` mutant is unkillable with C/POSIX/C.UTF-8; LOCPATH+localedef GB18030 shows the difference
metadata:
  type: project
---

Measured esf-gate-bytes (2026-10-03, bash 5.2.21): a pattern holding an
invalid-UTF-8 fragment (`*$'\xc2'[$'\x80'-$'\x9f']*`) makes bash fall back to
bytewise matching, and in UTF-8 `[[:cntrl:]]` is a superset of C1/U+2028/9, so
removing `local LC_ALL=C` from human-decision-gate.sh forbidden_bytes() changed
0 of 21888 fuzzed byte sequences under C and C.UTF-8. UTF-8 is
self-synchronising, so bytewise == charwise for valid patterns anyway.
Only a non-UTF-8 multibyte locale differs: `localedef -i zh_CN -f GB18030
<dir>/zh_CN.GB18030` then `LOCPATH=<dir> LC_ALL=zh_CN.GB18030` -> 53 diffs
(e.g. bytes a2 a1 + `via` lead-in). `local LC_ALL=C` does take effect inside a
function and is restored on return.

**Why:** the plan's locale mutation criterion assumed C.UTF-8 would kill it.
**How to apply:** a locale-mutant criterion needs a non-UTF-8 multibyte locale
to be non-vacuous; report rather than force it. See [[mutation-proof-needs-a-sole-denier]].
