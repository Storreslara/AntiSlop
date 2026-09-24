---
name: claude-code-hook-and-effort-primitives
description: Measured Claude Code 2.1.281 facts — PostToolUse cannot rewrite tool output, PreToolUse updatedInput can but masks exit status, bashOutputMaxChars already caps Bash output, and `effort:` IS a valid agent frontmatter key with no per-dispatch equivalent.
metadata:
  type: project
---

All measured against Claude Code **2.1.281** (binary at
`~/.local/share/claude/versions/2.1.281`, `strings`-probed) while writing
`docs/plans/2026-09-23-cost-governance-output-cap-and-effort-tiers.md`
(issue #476). Re-probe the binary before trusting these on a newer version.

## Hook output shaping

- **`PostToolUse` cannot rewrite/replace a tool result.** `updatedOutput`:
  **0** occurrences (vs. `updatedInput` 119, `hookSpecificOutput` 49). It can
  only `additionalContext` (adds), `systemMessage`, `terminalSequence`. The
  result is committed to context before the hook fires. Do not design around
  output filtering.
- **`PreToolUse` CAN rewrite tool input** via `{hookSpecificOutput:
  {permissionDecision:"allow", updatedInput:{command:"..."}}}`. This is
  Anthropic's documented cost pattern (code.claude.com/docs/en/costs,
  "Offload processing to hooks and skills"), whose example matches
  `^(npm test|pytest|go test)`.
- **Why that pattern is REJECTED in this repo:** appending a pipe destroys exit
  status. Measured in this repo's own Bash tool: `bash -c 'exit 7' | head -5`
  → `0`, and `pipefail` is NOT set. Every acceptance-criteria command here is
  graded on its exit code, so a rewriting hook would turn a failing
  `bash tests/validate.sh` into exit 0. Anthropic's example targets exactly
  the command class this repo must never rewrite.
- **A mechanical cap already exists:** `bashOutputMaxChars` — *"How many
  characters of a successful Bash or PowerShell command's output Claude
  receives inline (default 30000; values clamp to 4000-128000). Output past
  this is saved to a file and Claude receives a short preview plus the path."*
  `BASH_MAX_OUTPUT_LENGTH` on its own only sizes the read-back window. Never
  claim this repo "relies entirely on an instruction" for output scoping.
- **No hook here reads `.tool_response`** (measured: zero). All read
  `.tool_input` or top-level fields. An output-inspecting hook would be a
  first.

## Reasoning effort

- **`effort:` IS a valid agent frontmatter key**, sibling to
  `model`/`tools`/`memory` in the same schema object: *"Thinking effort:
  `low`, `medium`, `high`, `max`, or an integer."* Accepted set pinned in the
  binary as `ad = ["low","medium","high","xhigh","max"]`, or an integer.
- The **plugin** agent-file loader validates it and warns *"Plugin agent file
  … has invalid effort '<v>'"* — loud, not silent. Note the same loader
  **rejects** `permissionMode`, `hooks`, `mcpServers` in plugin agent files;
  `effort` is not in that rejected set.
- **There is NO per-dispatch effort parameter.** The `Agent` tool exposes only
  `description`, `prompt`, `subagent_type`, `model`, `isolation`. The harness
  says so itself: *"Each agent type's model, reasoning effort, and tools come
  from its definition (`.claude/agents/*.md` frontmatter or SDK `agents`)."*
  So an effort floor is enforced **by construction** — unlike `model`, there
  is no dispatch-time knob to weaken. Stronger than the model-tier precedent.
- Session-level controls DO exist (`/effort`, `--effort <level>`,
  `settings.json` `modelSettings.<model>.effortLevel`, plus a per-model
  `maxEffortLevel` **ceiling** — there is no floor primitive). With no
  frontmatter `effort:`, personas inherit session effort, so `/effort low`
  silently lowers the **reviewer**. Declaring `effort:` closes that.
- **Deferred intent already in-repo:** `adapters/codex/agents/reviewer.toml:23-24`
  ("judgment tier (e.g. `high`) once the project's tier-mapping decision …
  is made") and `explorer.toml:17-18` (cheap tier, `low`). Any effort spec
  should resolve both, not leave the ports disagreeing.

## Terminology trap (bit me once)

`agents/orchestrator.md` defines **"downgrade"** as `sonnet` → `opus` — toward
**MORE** capability — and forbids "upgrade" (`opus` → `sonnet`). So the
invariant is *judgment may only move toward more capability, never less*.
Applied to effort: judgment may **raise** effort, never lower it. A request
phrased as "judgment can lower a tier but never raise one past a floor" is
inverted relative to this repo; carry the repo's direction.

Related: [[verify-own-criteria-nonvacuous]],
[[protocol-amendments-do-not-propagate]],
[[cli-update-never-reaches-settings-fragment]].
