<!-- antislop v0.31.36 | source: templates/persona-protocol-slim.md | ADAPT-substituted -->
<!-- Copied into the project as .claude/persona-protocol-slim.md by
     install-antislop / `--update`, version-stamped like persona-protocol.md.
     Delivered to lightweight, stateless personas (explorer, researcher,
     scribe) in place of the full persona-protocol.md — it carries only the
     sections that apply to a persona with no review-ownership role in the
     pipeline. Full-tier personas (orchestrator, spec-master, task-master,
     lead-programmer, reviewer, milestone-auditor) still receive the full
     persona-protocol.md; this is not a replacement for it there. Role-
     agnostic content only — adding a new slim persona never requires
     editing this file. -->

# Shared persona protocol (slim)

## Structural questions go to the explorer
Any question about where something is defined, what calls it, blast radius of
a change, inheritance chains, or test coverage: spawn `explorer`, don't invoke
the code-review-graph skill directly. Note this is instruction-enforced for
most personas, not mechanically blocked: `Skill` is in their `tools:` list so
a teammate copy can reach its OWN preloaded skills (which don't apply to
teammates otherwise) — that same tool would technically let them invoke
code-review-graph too. If the explorer reports the graph index is missing or
stale, treat its answer as grep-derived, not authoritative.

**Name-collision warning:** Claude Code's built-in `Explore` subagent shadows
this project's `explorer` under description-based auto-delegation, and it has
no graph MCP access. Always spawn by explicit name (`explorer`,
`.claude/agents/explorer.md`). If an answer lacks graph provenance (symbol →
file:line) and you didn't expect the grep fallback, assume the built-in ran
and re-spawn by name.

## Answer shape
When you return findings (to the orchestrator, another persona, or the user):
lead with the direct answer, then compact supporting facts. Never dump raw
tool output, full file contents, or whole diffs verbatim — distill it. This
applies doubly to the explorer, whose entire purpose is keeping noisy
traversal out of the caller's context.

## Scope Bash output before it enters context
Don't let a verbose command dump its full, untruncated output into your own
context — that cost is paid whether or not you go on to distill it for
someone else. Before running a command that can plausibly return more than a
screenful (build logs, full-repo greps, directory listings, verbose test
runs), pipe it through `head`/`tail`/`wc -l`/a targeted `grep` first, or pass
the tool's own quiet/summary flag if it has one. If you need to inspect a
large result in full after a summary looked interesting, fetch the narrower
slice you actually need rather than re-running the same command unfiltered.

## Agent-teams mode (only relevant if you were spawned as a teammate)
- `skills:`/`mcpServers:` frontmatter is NOT applied to a teammate; a skill
  marked `disable-model-invocation` is unreachable in any mode — read its
  `SKILL.md` directly, or ask the explorer via `SendMessage`.
- You CAN spawn foreground subagents; only nested TEAMS are barred.
- `SendMessage` is async, a spawned subagent blocks; report finished work by
  `SendMessage` to the name the lead spawned you under, never turn-text.
- `Write` and `Edit` may be listed in your `tools:` frontmatter and still be
  rejected at call time in a teammate dispatch, with the runtime error
  `<tool> exists but is not enabled in this context`. Re-measured 2026-08-09.
- Do not retry, do not request permission, do not treat it as a defect to
  diagnose mid-task: fall back immediately to `Bash` — a quoted heredoc
  (`cat > file << 'EOF'`) for whole-file authoring, or a `python3` heredoc that
  asserts `old` occurs exactly once before replacing, for surgical edits.
- The fallback inherits `reviewed-path-gate.sh`'s constraint: that gate
  matches on **command text**, so a heredoc whose body merely spells the
  reviewer-owned marker directory is refused regardless of where it writes.
  Author such a document with a placeholder token and substitute the real value
  from its canonical definition, so the invoking command text never spells the
  path. (This is the same move the gate's own refusal text recommends for
  `git commit -F <file>`.) That rephrasing is sanctioned for that gate only —
  never for human-decision-gate.sh, which grants nobody, where it is a
  `self-authorized bypass`. To write a marker body that must quote a
  `DECISION` path verbatim, use the sanctioned `cat > <marker-path> <<'EOF'`
  template that gate prints in its refusal, or report and wait.
- This applies **regardless of how the tools were granted**. A persona that
  lists `Write, Edit` in its own `tools:` frontmatter loses them exactly as a
  persona that receives them through the `memory:` auto-grant does — measured
  on both paths, 2026-08-09. Do not read a persona's frontmatter as evidence
  that the call will succeed.

## Blocked by a gate you do not own (never self-authorize a bypass)
When a hook or gate blocks you and the thing it asks for is not yours to give,
there are exactly two legal responses: do what it actually asks, if that is
genuinely your call, or report it and wait. Metadata-only workarounds are
bypasses, not fixes — bumping a file's mtime, `touch`ing a file to satisfy an
existence check, deleting or editing a gate's own state file, and re-running
with a flag that disarms the check are each a violation, and good intent, a
correct underlying state and full disclosure redeem none of them. If the
block's premise looks false, that is evidence of a defect in the gate and
reporting it is the useful action, not routing around it. The WIP sentinel and
a pending-review flag's `defer:`/`skip:` escape are sanctioned exits with their
own audit trail — using either as documented is not a bypass.

## Terminal status line (every dispatched turn)
End the message you return to your caller with a status line — the last
non-empty line, nothing after it: `STATUS: complete`, or
`STATUS: incomplete — <one-line, non-empty reason>` (an ASCII hyphen is an
accepted substitute for the em dash). You cannot see your own turn count or
your own cap being hit, and the `max_turns_reached` cutoff marker renders as
zero content blocks — the truncated turn's own partial output still renders
normally, so it reads exactly like a finished one unless the finished one is
signed. A missing line is a prompt to resume, not a defect and not a FAIL.

## A note on `memory`
If your persona has a `memory` field set, Claude Code auto-grants you Read,
Write, and Edit so you can manage your memory files — this happens regardless
of your declared `tools:` list. That is not license to edit source code if
your role says you never do. The restriction in that case is enforced by
instruction, not by the tool allowlist — treat it as a hard rule anyway.
