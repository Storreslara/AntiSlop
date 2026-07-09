#!/usr/bin/env python3
"""Compare token cost: today's setup (whole persona-protocol.md loaded into
every persona via CLAUDE.md @-include) vs the MCP prototype (persona calls
get_protocol_rules(persona) and gets only its own tagged rules).

Token counts are approximated as chars/4 (no tiktoken available in this
environment) - good enough to compare relative, not absolute, cost.
"""
from pathlib import Path
import sys

sys.path.insert(0, str(Path(__file__).parent))
from server import _load_rules  # noqa: E402

FULL_PROTOCOL = Path(__file__).parent.parent.parent / "templates" / "persona-protocol.md"

# Rough MCP fixed overhead per persona session: the tool's name+description
# (~40 words) plus the JSON-RPC envelope for one initialize + one call_tool
# round trip. This is a deliberately generous estimate, not a measured one.
MCP_TOOL_DEF_CHARS = 420
MCP_CALL_ENVELOPE_CHARS = 180


def toks(chars: int) -> int:
    return round(chars / 4)


def main() -> None:
    full_chars = len(FULL_PROTOCOL.read_text())
    rules = _load_rules()
    personas = sorted({p for r in rules for p in r.get("applies_to", [])})

    print(f"Baseline: full persona-protocol.md = {full_chars} chars (~{toks(full_chars)} tokens)")
    print("Loaded into EVERY persona's context on every session, via the CLAUDE.md @-include.\n")

    print(f"{'persona':<16} {'subset chars':>12} {'subset tok':>10} {'+MCP overhead tok':>18} {'vs baseline':>12}")
    total_baseline = 0
    total_mcp = 0
    for p in personas:
        matched = [r for r in rules if p in r.get("applies_to", [])]
        subset_chars = sum(len(r["body"]) + len(r["title"]) + 4 for r in matched)
        mcp_chars = subset_chars + MCP_TOOL_DEF_CHARS + MCP_CALL_ENVELOPE_CHARS
        pct = 100 * mcp_chars / full_chars
        print(f"{p:<16} {subset_chars:>12} {toks(subset_chars):>10} {toks(mcp_chars):>18} {pct:>11.0f}%")
        total_baseline += full_chars
        total_mcp += mcp_chars

    print()
    print(f"Summed across {len(personas)} personas, one session each:")
    print(f"  today (full doc x{len(personas)}):  ~{toks(total_baseline)} tokens")
    print(f"  MCP prototype (per-persona subset + overhead): ~{toks(total_mcp)} tokens")
    print(f"  reduction: {100 * (1 - total_mcp/total_baseline):.0f}%")


if __name__ == "__main__":
    main()
