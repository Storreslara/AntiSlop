---
name: protocol-template-derivation-model
description: What `templates/persona-protocol.md` actually renders into, and which personas trim which sections — dispatches routinely assume agents/*.md and adapter fragments are generated from it (they are not)
metadata:
  type: project
---

A template-only edit to `templates/persona-protocol.md` renders into `.claude/persona-protocol.md` (live mirror) + a `.claude/persona-config.json` hash — NOT into `agents/*.md` or the adapter fragments. Plain `--update` says "already current" after a template-only edit; `--update --force-render` is the sanctioned re-render (`--check` is a deprecated alias).

**Why:** `agents/*.md` are SOURCE personas; the protocol block is inlined into the scaffolded `.claude/agents/*.md` copies per `PROTOCOL_SECTIONS_BY_PERSONA` (bin/cli.js ~698). The adapter ports (`adapters/codex/agents-md-fragment.md`, `adapters/cursor/rules/persona-protocol.mdc`) are hand-adapted condensed variants copied verbatim — the parity test's header says so explicitly. Unit reviewer-changes-examples-lean-1 (2026-09-23) was dispatched on the wrong model and had to report it.

**How to apply:** before editing a protocol section "for persona X", check X's `include`/`drop` entry — e.g. `reviewer` DROPS `Fourth verdict: escalate-to-human`, so its operative CHANGES.md/EXAMPLES.md instructions are the second-person copy in `agents/reviewer.md` (~260-310), not the template. If a dispatch names `agents/*.md` or the adapter fragments as "generated derivatives", flag the premise rather than hand-editing them; commit the mirror + config hash via a bare `git add -A` on a tree that holds only your files (see [[harness-integrity-gate-persona-config-commit]]).
