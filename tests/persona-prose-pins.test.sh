#!/usr/bin/env bash
# Prose pins for the wave-7 cleanup (ptr-u13b, ptr-u13c): phrases that must, or must not, appear
# in persona sources, their .claude mirrors and the adapter ports. Each file is flattened
# (tr -s ' \n' ' ') first, so a phrase may wrap across lines. Prints ok|FAIL <file> <phrase>.
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

for f in agents/orchestrator.md .claude/agents/orchestrator.md; do
  has "$f" 'except a human-chosen (a)/(b) re-dispatch'
  has "$f" 'the contract of record, never a fix contract'
  has "$f" 'decision=contract-guard sonnet: no-contract'
  has "$f" 'other than a task-master or spec-master checkpoint'
  has "$f" 'is not progress'
  has "$f" '"Review markers and gate mechanics (owner-facing)" section lists'
  hasnot "$f" '"Review ownership" section lists'
done
for f in agents/task-master.md .claude/agents/task-master.md; do
  has "$f" 'Commit the handoff note with'
done
for f in agents/spec-master.md .claude/agents/spec-master.md; do
  has "$f" 'after every 3 contract files'
done
for f in adapters/codex/agents/orchestrator.toml adapters/cursor/agents/orchestrator.md; do
  has "$f" 'is not progress'
done
for p in orchestrator task-master spec-master; do
  for f in "agents/$p.md" ".claude/agents/$p.md"; do
    has "$f" 'STATUS: incomplete — checkpoint:'
  done
done

# ptr-u13c appends its rows below this line.
for f in agents/lead-programmer.md .claude/agents/lead-programmer.md; do
  tl="$(sed -n '1,12p' "$f" | grep -E '^tools:' | head -1)"
  if [ -n "$tl" ] && ! printf '%s' "$tl" | grep -q 'Agent'; then echo "ok   $f tools line has no Agent"; else echo "FAIL $f tools line missing or names Agent"; fail=1; fi
done
for f in agents/lead-programmer.md .claude/agents/lead-programmer.md adapters/codex/agents/lead-programmer.toml adapters/cursor/agents/lead-programmer.md; do
  hasnot "$f" 'Spawn `researcher`'
  hasnot "$f" 'Scribe updates'
  hasnot "$f" 'You CAN spawn foreground'
done
has .claude/agents/lead-programmer.md 'is the exception: it has no'
has .claude/agents/lead-programmer.md 'If your persona has the'
for f in templates/persona-protocol.md .claude/persona-protocol.md .claude/agents/lead-programmer.md .claude/agents/reviewer.md .claude/agents/spec-master.md .claude/agents/task-master.md; do
  hasnot "$f" 'print their complete remediation'
  has "$f" 'the glossary entry its `More:` line names'
done
if [ "$fail" -eq 0 ]; then echo "All persona-prose-pins checks passed."; else echo "persona-prose-pins: FAILED"; fi
exit "$fail"
