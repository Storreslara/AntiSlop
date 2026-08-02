# adapters/

Self-contained ports of the same three-layer shape (personas / hooks /
ADAPT) to other coding agents. Each mirrors the Claude Code layout in its
own idiom rather than sharing files.

## adapters/cursor/
Cursor port: `.cursor-plugin/` (plugin manifest), `agents/*.md`,
`hooks/{hooks.json,scripts}`, `rules/persona-protocol.mdc` (a
project-wide, always-apply rule carrying the **full, untrimmed** protocol).
Claude Code does not deliver its protocol via an `@include` either —
`bin/cli.js` physically inlines a per-persona trimmed excerpt into each
`.claude/agents/*.md` mirror (see
[protocol-delivery-tiers.md](../protocol-delivery-tiers.md)). Cursor's
`.mdc` has no per-persona seam, so it is a hand-adapted condensed rewrite
that must keep carrying the union for every persona — this is what bounds
the Claude-Code-only trimming mechanism's blast radius. `bin/cli.js
--target=cursor` scaffolds this into a project's `.cursor/`, merging
rather than clobbering an existing `.cursor/hooks.json`.

## adapters/codex/
Codex port: `.codex-plugin/`, `agents/*.toml` (TOML, not markdown — Codex's
native agent format), `hooks/{hooks.json,scripts}`,
`agents-md-fragment.md` (inlined into the project's `AGENTS.md` as a single
shared document, rather than kept as a separate protocol file — Codex has
no per-persona seam either, so like Cursor's rule file it carries the full
union, never a trimmed excerpt). Not every persona is ported — see
`docs/codex-port-notes.md` for which ones and why. MCP wiring for Codex
uses TOML-specific placeholder handling (`applyMcpTomlPlaceholder`,
`renderMcpTomlBlock` in `bin/cli.js`) since `.mcp.json`-style JSON doesn't
apply there.

## Porting notes
`docs/cursor-port-notes.md` and `docs/codex-port-notes.md` document the
per-platform gaps and decisions (e.g. which personas didn't port, which
Claude-Code-specific mechanisms have no equivalent). Read those before
assuming an adapter has full parity with the Claude Code plugin — it
doesn't, by design; see each notes file for the specific deltas.

## Behavioural parity guard: `tests/adapter-stop-gate-parity.test.sh` (issue #202)

The `stop-gate.sh` ports (`adapters/codex/hooks/scripts/stop-gate.sh`,
`adapters/cursor/hooks/scripts/stop-gate.sh`) each carry a header claiming
their ordered decision logic is identical to the main hook
(`hooks/scripts/stop-gate.sh`), differing only in payload field extraction
and the loop guard. Until this test existed, nothing checked that claim —
the ports diverged silently (the `defer:` dedupe was ported to neither),
and no merge-gate test could see it. This is a third, distinct kind of
parity check in this repo, alongside:

- **Byte-parity** (`tests/validate.sh`'s "shared hook libs" section) — the
  three copies of `hooks/scripts/lib/agent-identity.sh` must be
  byte-identical, because that file derives its behaviour from its own
  on-disk location rather than any per-platform input.
- **Document/section-presence parity** (`tests/adapter-protocol-parity.test.js`,
  see [protocol-delivery-tiers.md](../protocol-delivery-tiers.md)) — checks
  that every canonical protocol *section* is accounted for in the Codex and
  Cursor doc ports, not that any script *behaves* a particular way.
- **Behavioural parity** (this section) — drives all three stop-gate
  scripts through the same `defer:`-dedupe scenarios (via each port's own
  payload shape: `Stop`/`CLAUDE_PROJECT_DIR` for claude,
  `Stop`/`.cwd` for codex, `stop`/`.workspace_roots[0] // .cwd` for cursor)
  and asserts the same observable outcome from each — audit-log record
  count and exit code, not source text.

**What the guard covers:** exactly the defer-dedupe scenario, parameterized
across all three stop-gate scripts — a single-line `defer:` write surviving
three `Stop` events as one audit record, the same for a multi-line reason,
and a changed reason (`defer: A` → Stop → `defer: B` → Stop) yielding two
records. A mutation control (reverting the dedupe in one port only) proves
the guard actually fails when a port drifts, rather than passing vacuously
against an unported script.

**What it does not cover:** this is not a general behavioural-parity
guarantee for every hook or every code path in `stop-gate.sh` — only the
one scenario the fixture drives. A divergence in, say, the WIP-sentinel
handling or the loop-guard threshold in a port would not be caught by this
test. Registered in `tests/validate.sh` (the merge gate) alongside the
byte-parity and document-parity checks above — see [hooks.md](hooks.md)'s
"stop-gate.sh: adapter-port behavioural parity" section for the
merge-gate framing.
