#!/usr/bin/env python3
"""Prototype MCP server: serves persona-protocol rules on demand instead of
loading all of them into every persona's context via CLAUDE.md.

Each rule lives as its own file in rules/ with YAML-ish frontmatter:
    ---
    id: explorer-routing
    title: Structural questions go to the explorer
    applies_to: [lead-programmer, planner, reviewer, repo-historian, orchestrator]
    ---
    <body>

Run standalone for a manual smoke test:
    python3 server.py --persona lead-programmer

Run as an actual MCP stdio server (what Claude Code would launch):
    python3 server.py
"""
from __future__ import annotations

import sys
from pathlib import Path

from mcp.server.fastmcp import FastMCP

RULES_DIR = Path(__file__).parent / "rules"

mcp = FastMCP("protocol-rules")


def _parse_rule(path: Path) -> dict:
    text = path.read_text()
    _, frontmatter, body = text.split("---", 2)
    meta: dict = {}
    for line in frontmatter.strip().splitlines():
        key, _, value = line.partition(":")
        key, value = key.strip(), value.strip()
        if value.startswith("[") and value.endswith("]"):
            meta[key] = [v.strip() for v in value[1:-1].split(",") if v.strip()]
        else:
            meta[key] = value
    meta["body"] = body.strip()
    return meta


def _load_rules() -> list[dict]:
    return [_parse_rule(p) for p in sorted(RULES_DIR.glob("*.md"))]


@mcp.tool()
def get_protocol_rules(persona: str) -> str:
    """Return only the shared-protocol rules that apply to the given persona
    name (e.g. "lead-programmer", "explorer"), instead of the full protocol
    doc. Call this once at startup in place of reading persona-protocol.md."""
    rules = _load_rules()
    matched = [r for r in rules if persona in r.get("applies_to", [])]
    if not matched:
        return f"No protocol rules tagged for persona '{persona}'."
    sections = [f"## {r['title']}\n\n{r['body']}" for r in matched]
    return "\n\n".join(sections)


@mcp.tool()
def list_personas() -> str:
    """List every persona name referenced across all rule files, so a caller
    can discover valid values for get_protocol_rules()."""
    rules = _load_rules()
    personas = sorted({p for r in rules for p in r.get("applies_to", [])})
    return ", ".join(personas)


if __name__ == "__main__":
    if len(sys.argv) > 1 and sys.argv[1] == "--persona":
        print(get_protocol_rules(sys.argv[2]))
    else:
        mcp.run()
