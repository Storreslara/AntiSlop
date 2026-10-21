#!/usr/bin/env bash
# Pins the unit-scope sentences (aof-u3) in personas, .claude mirrors and adapter ports.
set -u
cd "$(dirname "$0")/.."
fail=0
has() { # <file> <phrase>
  if [ -f "$1" ] && tr -s ' \n' ' ' < "$1" | grep -qF -- "$2"; then echo "ok   $1 $2"; else echo "FAIL $1 $2"; fail=1; fi
}
for f in agents/orchestrator.md .claude/agents/orchestrator.md; do
  has "$f" 'Every lead-programmer dispatch carries `## Affected files`'
done
for f in agents/lead-programmer.md .claude/agents/lead-programmer.md adapters/codex/agents/lead-programmer.toml adapters/cursor/agents/lead-programmer.md; do
  has "$f" 'edit only the files listed under your dispatch'"'"'s `## Affected files`'
done
for f in agents/reviewer.md .claude/agents/reviewer.md adapters/codex/agents/reviewer.toml adapters/cursor/agents/reviewer.md; do
  has "$f" "A changed file outside the unit's scope is also a FAIL reason"
  has "$f" 'out-of-scope-file defects are FAIL reasons'
done
# aof-u3b: standing scope exceptions in both rules, the reviewer's judgement clause gone, and the
# orchestrator ports state the sending half of the rule their reviewer ports already enforce.
hasnot() { # <file> <phrase>
  if [ -f "$1" ] && ! tr -s ' \n' ' ' < "$1" | grep -qF -- "$2"; then echo "ok   $1 (absent) $2"; else echo "FAIL $1 (present or missing) $2"; fail=1; fi
}
for f in agents/lead-programmer.md .claude/agents/lead-programmer.md adapters/codex/agents/lead-programmer.toml adapters/cursor/agents/lead-programmer.md \
         agents/reviewer.md .claude/agents/reviewer.md adapters/codex/agents/reviewer.toml adapters/cursor/agents/reviewer.md; do
  has "$f" 'the version-stamp files that the project'"'"'s constitution or merge gate requires every such commit to change'
  has "$f" '(in this plugin'"'"'s own repo: `.claude-plugin/plugin.json`, `package.json` and `CHANGELOG.md`)'
  has "$f" 'a path that one of the unit'"'"'s acceptance-criteria commands names literally'
  has "$f" 'a path named in a defect of the unit'"'"'s `.fail` record or listed under its fix contract'"'"'s `## Affected files`'
  hasnot "$f" 'unless an acceptance criterion of the unit requires that file'
done
for f in adapters/codex/agents/orchestrator.toml adapters/cursor/agents/orchestrator.md; do
  has "$f" 'Every lead-programmer dispatch carries `## Affected files`'
  has "$f" 'that no standing exception covers'
done
exit "$fail"
