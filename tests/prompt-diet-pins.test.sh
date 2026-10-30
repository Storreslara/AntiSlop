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

# qw-u3: protocol narrative trim. Rules P1-P7 stay in the protocol and in every mirror that inlines
# their section; the provenance note, the ADR-0028 cause story and three status-line asides are removed.
for f in templates/persona-protocol.md .claude/persona-protocol.md .claude/agents/orchestrator.md \
         .claude/agents/reviewer.md .claude/agents/spec-master.md \
         .claude/agents/milestone-auditor.md; do
  has "$f" 'Only one unit is ever mid-review'
  has "$f" 'A reviewer'"'"'s stop clears every flag whatever the verdict'
  has "$f" '**unit-exclusivity axis**'
  has "$f" '**advisory-reviewer axis**'
  has "$f" 'ADR-0016'
  hasnot "$f" 'Moved here from Review ownership'
  hasnot "$f" 'a test-hygiene defect, not a violation of unit-exclusivity'
done
for f in templates/persona-protocol.md .claude/persona-protocol.md .claude/agents/orchestrator.md \
         .claude/agents/reviewer.md .claude/agents/spec-master.md \
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

# Later units append their rows below this line.

# rp-u5 (fix 1): one decision table decides the scribe dispatch, early-stop and end-of-plan alike: it runs
# when a covered unit has a tracker issue to close, or when none has but a covered digest reports a changed
# API or new convention in scope (under knowledgeWrites apply every knowledge file is in scope); otherwise it
# is skipped. The early-stop dispatch comes before the human is asked at ladder exhaustion or the plan ends
# early, a parked unit is not passed, and the end-of-plan dispatch skips units already sent.
for f in agents/orchestrator.md .claude/agents/orchestrator.md; do
  has "$f" 'dispatch the scribe once for the units that already reached PASS, before you ask the human at ladder exhaustion or before you end the plan early'
  has "$f" 'A parked unit is not passed, and under review gating off ladder exhaustion is not a stop.'
  has "$f" 'dispatch after the last unit covers only the units not already sent to the scribe by an early-stop dispatch'
  has "$f" 'Skip the scribe dispatch entirely when no unit has a tracker issue to close and no unit'"'"'s digest reports a changed API or new convention whose knowledge file is in unit scope'
  has "$f" 'under `knowledgeWrites: apply` every knowledge file is in scope, so the dispatch is skipped only when no unit has a tracker issue to close and no digest reports a changed API or new convention'
  has "$f" 'it runs when a covered unit has a tracker issue to close, in either mode'
  has "$f" 'it runs when no covered unit has one but a covered digest reports a changed API or new convention whose knowledge file is in unit scope'
  has "$f" 'it is skipped when neither holds'
  hasnot "$f" 'so only the first condition can skip it'
  hasnot "$f" 'an abandoned unit'
done

# rp-u3: the reviewer's pointer to the moved residual, the orchestrator's teams-command pointer, qw-u4's
# safety phrases, the ported scribe sentence, and three more narratives qw-u3 removed. Current files only.
for f in agents/reviewer.md .claude/agents/reviewer.md; do
  has "$f" '(see `docs/orchestrator-rationale.md`, "N1: reviewer dispatch naming, the unobserved residual")'
  hasnot "$f" '`agents/orchestrator.md`'"'"'s "Dispatch naming" section'
done
has docs/orchestrator-rationale.md '## N1: reviewer dispatch naming, the unobserved residual'
for f in agents/orchestrator.md .claude/agents/orchestrator.md; do
  has "$f" 'If the `start-feature-team` command is running, its rules govern instead of the routing/review-ownership rules above'
done
for f in agents/orchestrator.md adapters/codex/agents/orchestrator.toml adapters/cursor/agents/orchestrator.md; do
  has "$f" 'When you dispatch scribe, quote each unit'"'"'s reviewer PASS verdict line verbatim in that dispatch; scribe closes an issue only on its own quoted line.'
  hasnot "$f" 'When you dispatch scribe for a unit'
done
for f in templates/persona-protocol.md .claude/persona-protocol.md .claude/agents/orchestrator.md \
         .claude/agents/reviewer.md .claude/agents/spec-master.md \
         .claude/agents/milestone-auditor.md .claude/agents/lead-programmer.md; do
  hasnot "$f" 'not an exemption'
  hasnot "$f" 'Not an alternative to the WIP sentinel'
  hasnot "$f" 'a complementary safety layer'
done

if [ "$fail" -eq 0 ]; then echo "All prompt-diet-pins checks passed."; else echo "prompt-diet-pins: FAILED"; fi
exit "$fail"
