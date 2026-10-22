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

# qw-u4: the ESCALATE-TO-HUMAN procedure moves verbatim into the protocol's Fourth verdict section; the
# orchestrator keeps a stub that names the subsection and carries the five invariants.
for f in agents/orchestrator.md .claude/agents/orchestrator.md; do
  has "$f" 'subsection of the `## Fourth verdict: escalate-to-human` section in `.claude/persona-protocol.md`'
  has "$f" 'Your job is **surfacing, not deciding**.'
  has "$f" 'print the marker'"'"'s card verbatim, never a summary'
  has "$f" 'never run `run.sh` or `view.sh` yourself'
  has "$f" 'relay the human'"'"'s answer verbatim'
  has "$f" '**prompt-confirmed decision write**, from this session'"'"'s answer and never on your own initiative'
  has "$f" 'afresh with `subagent_type: reviewer` set explicitly'
  has "$f" 'do not relay the decision in the prompt'
  hasnot "$f" 'Make **one** `AskUserQuestion` call'
  hasnot "$f" 'Twice a `general-purpose` agent dispatched this way'
done
for f in templates/persona-protocol.md .claude/persona-protocol.md; do
  has "$f" '### Orchestrator steps on an ESCALATE-TO-HUMAN verdict'
  has "$f" 'Print the marker'"'"'s lines 1 through the `---` fold line in chat **verbatim**'
  has "$f" 'Read `CHANGES.md` in that packet directory **(if present)**'
  has "$f" 'Read `EXAMPLES.md` in that packet directory **(if present)**'
  has "$f" '**Never run `run.sh` or `view.sh` yourself and never pre-digest a result**'
  has "$f" 'Make **one** `AskUserQuestion` call'
  has "$f" 'Make the **prompt-confirmed decision write**'
  has "$f" '**with `subagent_type: reviewer` set explicitly**'
  has "$f" '**never dispatch review-adjacent work to an untyped or generic agent.**'
done

# Later units append their rows below this line.

# rp-u5: the scribe still runs for the passed units when a plan stops early, and knowledgeWrites apply
# leaves only the no-issue condition to skip it.
for f in agents/orchestrator.md .claude/agents/orchestrator.md; do
  has "$f" 'If the plan stops before its last unit passes (ladder exhaustion, a human stop, an abandoned unit), dispatch the scribe once for the units that already reached PASS before you surface the stop'
  has "$f" 'under `knowledgeWrites: apply` the knowledge files are always in scope, so only the first condition can skip it.'
  has "$f" 'Skip the scribe dispatch entirely when no unit has a tracker issue to close'
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
  has "$f" 'ask through one `AskUserQuestion` call'
  has "$f" 'If that section cannot be read, print the whole marker verbatim, write nothing, and tell the human to resolve the escalation from their terminal or the Microworld dashboard.'
done
for f in templates/persona-protocol.md .claude/persona-protocol.md; do
  has "$f" 'never retry or rephrase the write'
  has "$f" 'Write only from this session'"'"'s answer'
  has "$f" 'never pick one for them'
  has "$f" 'Do not relay the decision in the prompt'
done
for f in agents/orchestrator.md adapters/codex/agents/orchestrator.toml adapters/cursor/agents/orchestrator.md; do
  has "$f" 'When you dispatch scribe, quote each unit'"'"'s reviewer PASS verdict line verbatim in that dispatch; scribe closes an issue only on its own quoted line.'
  hasnot "$f" 'When you dispatch scribe for a unit'
done
for f in templates/persona-protocol.md .claude/persona-protocol.md .claude/agents/orchestrator.md \
         .claude/agents/reviewer.md .claude/agents/spec-master.md .claude/agents/task-master.md \
         .claude/agents/milestone-auditor.md .claude/agents/lead-programmer.md; do
  hasnot "$f" 'not an exemption'
  hasnot "$f" 'Not an alternative to the WIP sentinel'
  hasnot "$f" 'a complementary safety layer'
done

if [ "$fail" -eq 0 ]; then echo "All prompt-diet-pins checks passed."; else echo "prompt-diet-pins: FAILED"; fi
exit "$fail"
