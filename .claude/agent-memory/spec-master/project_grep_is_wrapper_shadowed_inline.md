---
name: grep-is-wrapper-shadowed-inline
description: In this harness `grep` is a bash FUNCTION wrapping ugrep --ignore-files, but only when typed inline in the Bash tool — inside `bash script.sh` it is real GNU grep. Same text, two counts. Never write a criterion around bare grep.
metadata:
  type: project
---

Any acceptance criterion whose result is a **count** must name a tool that is
not shadowed. Bare `grep` is shadowed in this harness; `git`, `command grep`
and `rg` are not.

**The mechanism.** In an agent Bash-tool shell, `grep` resolves to a bash
*function* that re-execs the Claude binary as
`ugrep -G --ignore-files --hidden -I --exclude-dir=.git --exclude-dir=.svn …`.
`--ignore-files` makes it honour `.gitignore`, so it silently skips ignored
paths. Verified 2026-08-14 with `type grep` (ugrep 7.5.0; real binary is GNU
grep 3.11).

**The trap that actually bites.** A bash function is *not exported*, so it is
out of scope inside a script invoked as `bash script.sh` — there `grep` is the
real GNU binary again. `type -t grep` returns `function` when typed inline and
`file` inside a script. So one agent gets **two different answers from
identical command text** depending only on how it phrased the invocation:

    repo-wide count of a gitignored-dir literal, at one commit:
      typed inline in the Bash tool (ugrep wrapper) -> 124
      same text inside `bash probe.sh` (GNU grep)   -> 190
      a human's normal shell (GNU grep)             -> 190

This cost unit `gh288-2` its 2-FAIL cap. The reviewer's FAIL record diagnosed
it as a "human vs. agent" divergence; it is really **inline vs. script**, which
is worse, because a single agent can produce both numbers in one session and
have no reason to suspect either.

**A second, unrelated GNU-grep trap in the same incident:**
`--exclude-dir` matches a directory's **basename** only, never a
slash-containing path. `--exclude-dir=a/b` is a silent no-op; `--exclude-dir=b`
works. A fix commit shipped the slash form and excluded nothing.

**How to apply:** when authoring or reviewing a counting criterion —
1. Prefer `git grep -l … <commit> | wc -l`. It is unshadowed, tracked-files-only
   (so gitignored noise and untracked scratch trees can never perturb it), and
   commit-pinnable — see [[baselines-expire]] for why the pin matters.
2. If a live-tree count is genuinely required, write `command grep` explicitly,
   never bare `grep`, and state which you meant.
3. Never trust a count another agent reported without knowing how it was
   invoked. Re-run it yourself, in the form the artifact actually quotes.
