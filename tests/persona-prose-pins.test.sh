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
  has "$f" 'other than a spec-master checkpoint'
  has "$f" 'is not progress'
  has "$f" '"Review markers and gate mechanics (owner-facing)" section lists'
  hasnot "$f" '"Review ownership" section lists'
done
for f in agents/spec-master.md .claude/agents/spec-master.md; do
  has "$f" 'after every 3 contract files'
done
for f in adapters/codex/agents/orchestrator.toml adapters/cursor/agents/orchestrator.md; do
  has "$f" 'is not progress'
done
for p in orchestrator spec-master; do
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
for f in agents/reviewer.md .claude/agents/reviewer.md; do
  has "$f" 'Refutation pass (before any FAIL verdict)'
  has "$f" 'bash .claude/bin/refutation-brief.sh <baseline>'
  has "$f" '`model: sonnet`, in the foreground and with no `name:`'
  has "$f" 'confirm that the guard stops this defect on this defect'
  has "$f" 'You may keep a defect standing with a stated reason'
  has "$f" 'each UNCERTAIN one prefixed `[unconfirmed]`'
  has "$f" 'FAIL a defect you now reproduce yourself'
  has "$f" 'That PASS writes the same marker, stamp and flag state as any other PASS'
  has "$f" 'found no defect that survived the refutation pass'
  hasnot "$f" 'may not argue away'
  hasnot "$f" 'refuter'
done
for f in templates/persona-protocol.md .claude/persona-protocol.md; do
  has "$f" 'reproduce it before fixing it, and report one that does not reproduce'
done
for f in agents/milestone-auditor.md .claude/agents/milestone-auditor.md; do
  has "$f" 'Re-verify the first 3 of them (all, if fewer)'
  has "$f" 'decide whether the artifact defeats the claim on the defect'
  has "$f" 'When `eligible` is 20 or more and `p` is under a tenth of it'
done
for f in agents/reviewer.md .claude/agents/reviewer.md; do
  has "$f" '(file:line + how to trigger), then the `refutation:` line the Refutation pass below defines, and nothing more in the FAIL block'
  hasnot "$f" '(file:line + how to trigger) and nothing more'
  has "$f" 'Each "nothing else" or "nothing more" above bounds the verdict block itself: these advisory sections and the'
  has "$f" 'your final message is ONLY the verdict block, followed by nothing but the advisory sections and the terminal STATUS line this bullet allows after it.'
  hasnot "$f" 'message is ONLY the verdict. PASS'
  has "$f" 'The marker carries no REFUTED defect: when the refutation pass led to this verdict, its REFUTED defects and your reasons live only in the returned message'"'"'s `refutation` advisory section.'
  has "$f" 'If none stands and one or more is UNCERTAIN, return INSUFFICIENT-CONTEXT, its `missing:` naming the evidence that would settle each, and the REFUTED ones and your reasons go in the `refutation` advisory section, as in a FAIL;'
done
for f in agents/milestone-auditor.md .claude/agents/milestone-auditor.md; do
  has "$f" 'one you cannot decide counts toward `sampled`, never toward `held`'
done
if [ "$fail" -eq 0 ]; then echo "All persona-prose-pins checks passed."; else echo "persona-prose-pins: FAILED"; fi
exit "$fail"
