#!/usr/bin/env python3
"""Smoke test: drive server.py as a real MCP stdio server (full JSON-RPC
handshake + tool call), not just the --persona CLI shortcut. Proves the
prototype is an actual MCP integration, not just a Python function.
"""
import asyncio
import sys
from pathlib import Path

from mcp import ClientSession, StdioServerParameters
from mcp.client.stdio import stdio_client

SERVER = str(Path(__file__).parent / "server.py")


async def main(persona: str) -> None:
    params = StdioServerParameters(command=sys.executable, args=[SERVER])
    async with stdio_client(params) as (read, write):
        async with ClientSession(read, write) as session:
            await session.initialize()
            tools = await session.list_tools()
            print("tools exposed:", [t.name for t in tools.tools])
            result = await session.call_tool("get_protocol_rules", {"persona": persona})
            text = "".join(c.text for c in result.content if hasattr(c, "text"))
            print(f"\n--- rules for '{persona}' ({len(text)} chars) ---")
            print(text)


if __name__ == "__main__":
    asyncio.run(main(sys.argv[1] if len(sys.argv) > 1 else "reviewer"))
