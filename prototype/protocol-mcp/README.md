# Prototype: protocol rules as a graph, served over MCP

Question this answers: would splitting `persona-protocol.md` into individual
rule "nodes" and serving them on-demand over MCP (instead of loading the
whole file into every persona via the CLAUDE.md `@`-include) actually save
tokens?

## What's here

- `rules/*.md` — the 9 sections of `templates/persona-protocol.md`, split
  into one file each. Frontmatter tags each rule with `applies_to: [...]`,
  the personas it's relevant to.
- `server.py` — a real MCP server (stdio transport, official `mcp` Python
  SDK). Exposes `get_protocol_rules(persona)`, which reads the rule files and
  returns only the ones tagged for that persona. `list_personas()` is a
  discovery helper.
- `test_client.py` — drives `server.py` through a full MCP handshake
  (`initialize` → `list_tools` → `call_tool`) to prove it works as an actual
  MCP integration, not just a Python function. Run: `python3 test_client.py
  <persona>`.
- `measure.py` — compares token cost of today's approach (full doc x N
  personas) against the MCP approach (per-persona subset + MCP overhead).
  Token counts are chars/4 (no `tiktoken` in this environment — treat as
  relative, not absolute).

## Result

```
persona          subset chars subset tok  +MCP overhead tok  vs baseline
explorer                 1278        320                470          29%
lead-programmer          6029       1507               1657         101%
orchestrator             3085        771                921          56%
planner                  4045       1011               1161          71%
repo-historian           2487        622                772          47%
reviewer                 4355       1089               1239          75%

Summed, one session each: today ~9876 tok, MCP prototype ~6220 tok (-37%)
```

**The win is real but uneven, and it inverts for one persona.** Explorer and
repo-historian (light protocol needs) drop to ~30-50% of baseline — a
genuine win. But `lead-programmer` needs almost every rule already, so
selective retrieval buys it nothing, and it pays a strict *penalty*
(101% of baseline) for the MCP round-trip on top of reading nearly the same
content it would've gotten for free from CLAUDE.md.

This confirms the caveat from the original discussion: this only nets a win
when a persona's real rule-subset is small relative to the whole doc. Applied
here, it would help `explorer`/`repo-historian`/`orchestrator` and hurt
`lead-programmer`/`reviewer`/`planner` — and lead-programmer is the
highest-frequency persona in the system, so a blanket switch would likely be
a net loss in practice, not a win.

## If this were adopted for real (not done here)

- Split by persona, not blanket: keep `lead-programmer` et al. on the direct
  CLAUDE.md include (cheap, no round-trip), and only move genuinely
  narrow-scope personas (`explorer`, `repo-historian`) to the MCP tool.
  That's a per-persona `mcpServers` field, same pattern already used for
  `researcher.md.tmpl`'s arXiv MCP — inline, project-scoped, connects only
  when that persona starts.
- The "living document" part (adding a rule = adding a file, no rebuild)
  works regardless of whether MCP is used — that's just the file-per-rule
  layout, and it's a reasonable improvement to `persona-protocol.md`'s
  maintainability on its own, independent of the token question.
- None of the shipped plugin files were touched — this lives entirely under
  `prototype/` so it doesn't affect `setup-personas`, the real
  `persona-protocol.md`, or any agent file.
