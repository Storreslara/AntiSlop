---
name: bash-lexer-gate-traps
description: Two silent traps when editing reviewed-path-gate.sh's matcher - local assignment chaining, and mutation-control copies losing their lib/ sibling
metadata:
  type: project
---

Both bit me on issue #182 attempt 3 and both fail *silently* — the code runs,
the suite is green, and the thing you think you tested was never tested.

**1. `local a=x b="$a"` does NOT chain.** Every operand of `local` is expanded
before the builtin runs, so `local meta=$' \t\n' fd="[$meta]"` yields
`fd="[]"` — an empty bracket expression, a regex that matches nothing, and a
wide-open gate. Split it into two `local` statements. There is a comment at the
site saying so; don't "tidy" it back into one line.

**Why:** this is the exact shape of the two fail-opens that got #182 escalated —
a matcher that looks right, passes the existing fixtures, and is inert. It cost
a third attempt.

**How to apply:** any time you build a regex or glob from a variable in the same
declaration that defines the variable, in any hook script here.

**2. A scratch copy of a hook for mutation testing must bring `lib/` with it.**
`reviewed-path-gate.sh` does
`source "$(dirname "${BASH_SOURCE[0]}")/lib/agent-identity.sh"`. Copy it alone
into a `mktemp -d` and it dies at startup: every case "fails" with **rc=1**, the
FAIL count sails past any `>= N FAIL lines` threshold, and you have proved only
that a missing file is missing. A real kill shows **rc=0** on a case that
expected a block (the gate allowed something). Always `cp -r hooks/scripts/lib`
next to the mutant, and read the rc on the FAIL lines before believing them.

**How to apply:** whenever a spec asks for a "mutation control" on a hook here.
`tests/reviewed-path-gate.test.sh` honours `$GATE_UNDER_TEST` so the suite can
be pointed at the mutant without editing the gate in place.

**3. An exit code is not an effect — verify the spec's own measurements.** On
issue #184 the finalized spec asserted, as a measured fact, that
`git diff --output=F` outside a git repo "writes nothing (measured: rc
128/129)", and built an acceptance criterion on it (case 28 needs no real-bash
half). The rc was real; the inference was wrong. git parses `--output` and
**opens — hence truncates — the target to 0 bytes before** it discovers there is
no repository. (`git log --output=F` really does write nothing, so it is
per-subcommand.) Trusting it would have shipped exactly the vacuous differential
test the spec existed to prevent.

**Why:** spec docs here carry "Measured this session" tables that read as
authoritative, and mostly are — but a measurement of the *wrong observable*
(exit code instead of filesystem state) is invisible in the table. The same spec
also enumerated two bypass mechanisms where there were three.

**How to apply:** when a criterion turns on "X has no observable effect", re-run
it yourself against a seeded sentinel and diff the *state*, not the return code —
before writing the test that depends on it. Cheap; it changed two acceptance
criteria on #184.

**4. The session-start `gitStatus` snapshot goes stale — resolve the mutation
control's baseline with `git rev-parse HEAD`, not from the prompt.** On #186 the
prompt's "Recent commits" listed `273c7b1` as tip; real HEAD was `aff5b35`, four
commits later. `git show 273c7b1:hooks/scripts/reviewed-path-gate.sh` cheerfully
returned a months-old gate, and the control read **26 FAIL** instead of the
expected 8 — every extra one a case that the old gate simply predated. That
looks exactly like "my reconciliation broke the suite" and is really "I pointed
the control at the wrong baseline". The tell is FAIL lines in cases your change
never touched.

**How to apply:** before writing any `git show <ref>:file` into a test comment
as "the commit before the fix", run `git rev-parse HEAD` and `git log --oneline
-3 -- <file>` and use that. Then keep the *literal* hash in the comment, so the
reviewer re-runs the same control you did.

**5. `{ head; cat; tail; } > new && mv new file` drops the executable bit.**
Splicing a block out of a `.test.sh` this way silently commits a `100755 =>
100644` mode change. `git commit` prints it; `chmod 755` + `--amend` fixes it.

Related: [[live-plugin-probe]], [[marker-gate-blocks-own-commits]].
