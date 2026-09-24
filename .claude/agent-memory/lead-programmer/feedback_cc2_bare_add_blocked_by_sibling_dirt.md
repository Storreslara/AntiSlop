---
name: feedback_cc2_bare_add_blocked_by_sibling_dirt
description: gh441 (recurred orchestrator-effort-policy-prose-fix) - a CC2-mandated 'git add -A' commit route has no way to exclude an unrelated concurrent agent's dirty files; when git status --short shows any, stop and report rather than improvise a workaround
metadata:
  type: feedback
---

CC1/CC2's mirror-sync commit route (`node bin/cli.js --update --force-render`
then `git add -A` + plain `git commit -m`, never `git commit -- <paths>`) is
mandatory specifically because a Set A literal like
`.claude/persona-config.json` cannot be named in a commit pathspec, and a
hand-picked `git add <path>` list naming it is denied the same way. That
means the route has **no way to exclude** an unrelated file that happens to
be dirty at the same moment — there is no selective-add escape hatch once
CC1/CC2 apply.

**Why:** on gh441 (Step 2 of the fable-gate-audit-remediation plan), a
concurrently-running scribe agent had modified its own memory `MEMORY.md`
and added a new memory file (timestamped ~2 minutes old) for a sibling unit
(gh440, Step 1) while I was mid-implementation on Step 2. `git status
--short` showed this alongside my own changes. A bare `git add -A` would
have swept the scribe's in-flight, unrelated work into my commit.

**How to apply:** before the CC2 commit, always run `git status --short`
yourself first (the dispatch packet may explicitly ask for this). If
anything unrelated to your own unit is dirty, do not improvise — do not
stash it, do not hand-pick a pathspec around the Set A literal (blocked by
the harness-integrity-gate anyway), and do not wait-and-poll. Write the WIP
sentinel (`.claude/wip-handoff.<agent-id>`, non-empty reason) naming exactly
what's dirty and why it isn't yours, and report the blocker up the chain.
This mirrors [[project_concurrent_agent_persona_config_race]]'s "don't
resolve shared-state ambiguity yourself" principle, but for the commit step
specifically rather than a config-field delta.

Separately: when writing the sentinel/report prose itself, avoid spelling
Set A literals like `.claude/persona-config.json` verbatim even in an
explanatory sentence — `harness-integrity-gate.sh` scans Bash command TEXT
generically, not just write targets, so an `echo`/`printf` merely mentioning
the literal in prose is denied the same as an edit would be. Paraphrase
("the harness config file") instead; the literal string adds no information
the reader doesn't already have from context. See
[[project_decision_gate_blocks_approve_marker]] for the same pattern with a
different gate.

**Recurrence (orchestrator-effort-policy-prose-fix, 2026-09-24):** same
shape, different sibling — a concurrent agent's WIP touched
`tests/rollout-preflight.test.sh` and two `install-antislop` SKILL.md/command
copies while I had my own `--update`-regenerated mirror diff (including the
config-surface file) staged only in the working tree. Confirmed via a
`ps`/`stat` cross-check that a sibling subagent's background
`bash tests/validate.sh` had started ~80s prior and its dirty files'
mtimes matched — evidence worth gathering before assuming it's stale WIP
from an abandoned session. Wrote the sentinel and handed back without
committing, exactly per this memory's prior guidance; no new technique
needed, just confirms the pattern recurs under ordinary (non-agent-teams)
concurrent dispatch too, not just gh441's original scenario.
