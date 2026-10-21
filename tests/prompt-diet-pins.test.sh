#!/usr/bin/env bash
# Prompt-diet pins (qw-u2, extended by qw-u3 and qw-u4): every live rule a diet unit moved or shortened is
# present where the spec's rule map says it survives, and the moved narrative is gone from the prompt.
# Each file is flattened (tr -s ' \n' ' ') first, so a phrase may wrap. Prints ok|FAIL <file> <phrase>.
set -u
cd "$(dirname "$0")/.."
fail=0
flat() { tr -s ' \n' ' ' < "$1"; }
has() { # <file> <phrase>
  if [ -f "$1" ] && flat "$1" | grep -qF -- "$2"; then echo "ok   $1 $2"; else echo "FAIL $1 $2"; fail=1; fi
}
hasnot() { # <file> <phrase>
  if [ -f "$1" ] && ! flat "$1" | grep -qF -- "$2"; then echo "ok   $1 (absent) $2"; else echo "FAIL $1 (present or missing) $2"; fail=1; fi
}

# qw-u2: orchestrator narrative trim. Rules O1-O3, O5, O6 stay; O4 moves to the teams command;
# narratives N1-N5 move to docs/orchestrator-rationale.md.
for f in agents/orchestrator.md .claude/agents/orchestrator.md; do
  has "$f" 'dispatch the `reviewer` with no `name:` parameter'
  has "$f" 'it must be exactly `reviewer`'
  has "$f" '**Check the roster before resuming one by name**'
  has "$f" 'Only a fresh `Agent` dispatch whose first non-blank line is `Unit: <id>` writes the per-unit review-join stamp'
  has "$f" 'a persona that spawns its own subagent must collect the result explicitly'
  has "$f" 'defaults `CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS` to `"0"`'
  hasnot "$f" 'The actual, unobserved residual is different'
  hasnot "$f" 'two different mechanisms'
  hasnot "$f" 'produced gh-304'
  hasnot "$f" 'This project has observed: three unnamed subagents'
  hasnot "$f" 'Quoting the docs directly'
  hasnot "$f" '### A missing roster row is not proof a teammate is dead'
done
has commands/start-feature-team.md '**A missing roster row is not proof a teammate is dead.**'
has commands/start-feature-team.md '`SendMessage` it by name first'
has commands/start-feature-team.md 'still lists that member as active'
for n in 'The actual, unobserved residual is different' 'two different mechanisms' 'produced gh-304' \
         'This project has observed: three unnamed subagents' 'Quoting the docs directly'; do
  has docs/orchestrator-rationale.md "$n"
done

# qw-u3 appends its rows below this line.

if [ "$fail" -eq 0 ]; then echo "All prompt-diet-pins checks passed."; else echo "prompt-diet-pins: FAILED"; fi
exit "$fail"
