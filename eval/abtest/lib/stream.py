#!/usr/bin/env python3
"""Summarise one headless run's stream-json capture.

Usage:
  stream.py summarize STREAM_FILE [--exit-code N] [--stderr FILE] [--escalated N]

Prints one JSON object. completion_status is decided in this order:
  usage-limit  a subscription usage or rate limit stopped the run (never a failure)
  timeout      the wall-clock cap fired (exit code 124)
  turn-cap     the result subtype is error_max_turns
  stalled-human  an AskUserQuestion attempt, a permission denial or an
               escalation marker (--escalated) means the run needed a human
  error        no result object, an error result, or a non-zero exit with no clean result
  complete     everything else
"""
import argparse
import json
import re
import sys

LIMIT_RE = re.compile(
    r"usage limit|limit reached|rate[ _-]?limit|quota|too many requests|\b429\b",
    re.IGNORECASE,
)
SUBAGENT_TOOLS = ("Agent", "Task")
_WHO = r"(?:claude(?: ai)? |opus |sonnet |haiku )"
_KIND = r"(?:usage |weekly |5-hour |session )"
_SEP = r"[\u00b7\u2219\u2013\u2014|.,-]"
_DAY = r"(?:monday|tuesday|wednesday|thursday|friday|saturday|sunday|mon|tue|wed|thu|fri|sat|sun)"
_MONTH = (r"(?:january|february|march|april|may|june|july|august|september|october|november|december"
          r"|jan|feb|mar|apr|jun|jul|aug|sep|oct|nov|dec)")
_ZONE = r"(?:utc|gmt|pst|pdt|mst|mdt|cst|cdt|est|edt|cet|cest|bst)"
_WHEN = (r"(?:\d{1,2}(?::\d{2})?\s?(?:am|pm)?|\d{4}|" + _DAY + "|" + _MONTH + "|" + _ZONE +
         r"|today|tomorrow|midnight|noon|at|on|in|hours?|minutes?|days?|\(\w+(?:/[\w+-]+)*\))")
_RESET = r"(?:your (?:\w+ )?limit )?(?:will )?resets?(?:[\s,]+" + _WHEN + r"){1,8}"
_ADMIN = (r"(?:contact your admin(?: to increase it)?|add funds to continue|ask your admin for a higher limit"
          r"|(?:ask your admin to )?raise it at \S+|run \S+ to (?:raise it, or visit \S+|ask your admin for a higher limit)"
          r"|visit \S+ to raise it|an org owner or channel manager can raise it in the channel's claude settings)")
_PART = r"(?:" + _RESET + r"|progress saved|" + _ADMIN + r")"
_SWITCH = (r"(?:Switch to another model(?:, or manage usage credits at \S+,)? to continue\.|/model to switch models\."
           r"|Run /usage-credits to (?:raise it and keep using|keep using|manage your limit and keep using) [^\n]{1,60} or (?:/model to switch models|switch models to continue this chat)\."
           r"|Run /usage-credits to continue or switch models with /model\.)")
_TAIL = (r"(?:[.!]?(?:\s+" + _SWITCH + r")?$"
         r"|\|\d{9,13}$"
         r"|\s*(?:" + _SEP + r"\s*)?\(?" + _PART + r"(?:\)?\s*\u00b7\s*" + _PART + r")*\)?[.!]?$)")
_NAME = (r"(?:(?:usage |weekly |5-hour |session |opus |sonnet |fable |fast )?limit|team's shared budget"
         r"|(?:channel's monthly|individual|org's monthly) (?:spend|usage) limit|monthly spend limit)")
LIMIT_TEXT_RE = re.compile(
    r"(?:(?:api )?error:\s*)?(?:"
    r"(?:" + _WHO + _KIND + r"?|" + _KIND + r"|rate )limit reached"
    r"|you(?:'ve|\u2019ve| have) (?:hit|reached) your " + _NAME +
    r"|(?:you(?:'re|\u2019re| are) )?out of (?:extra usage|usage credits)"
    r"|your org is out of usage"
    r"|your seat type doesn't include (?:extra )?usage(?: credits)?"
    r"|your usage allocation has been disabled by your admin"
    r"|your group's usage limit is set to \$0"
    r"|(?:fable|haiku|mythos|opus|sonnet)(?: [^\u00b7\n]{1,40})? requires usage credits\."
    r")" + _TAIL +
    r'|(?:api )?error:\s*429 \{[^\n]*"type":"rate_limit_error"',
    re.IGNORECASE,
)
INVISIBLE = "\ufeff\u200b\u200c\u200d\u2060"


def clean(text):
    """Strip whitespace and invisible characters from both ends of a text."""
    return str(text).strip(" \t\r\n\f\v" + INVISIBLE)


def read_records(path):
    """Return (JSON objects, text of the lines that were not JSON)."""
    records = []
    noise = []
    with open(path, errors="replace") as f:
        for line in f:
            line = line.strip()
            if not line:
                continue
            try:
                obj = json.loads(line)
            except json.JSONDecodeError:
                noise.append(line)
                continue
            if isinstance(obj, dict):
                records.append(obj)
    return records, "\n".join(noise)


def hook_name(rec):
    for key in ("hook_event", "hookEvent", "hook_name", "hookName"):
        if rec.get(key):
            return str(rec[key])
    return ""


def is_hook_record(rec):
    kind = str(rec.get("type", ""))
    sub = str(rec.get("subtype", ""))
    return kind.startswith("hook") or (kind == "system" and sub.startswith("hook"))


def tool_uses(rec):
    if rec.get("type") != "assistant":
        return []
    content = (rec.get("message") or {}).get("content") or []
    return [b for b in content if isinstance(b, dict) and b.get("type") == "tool_use"]


def limit_event(rec):
    if rec.get("type") != "rate_limit_event":
        return False
    info = rec.get("rate_limit_info") or {}
    return str(info.get("status", "")).lower() in ("rejected", "blocked", "exceeded")


def summarize(path, exit_code, stderr_text, escalated):
    records, noise = read_records(path)
    result = None
    for rec in records:
        if rec.get("type") == "result":
            result = rec
    hooks = [r for r in records if is_hook_record(r)]
    hook_names = [hook_name(r) for r in hooks]
    tools = [b for r in records for b in tool_uses(r)]
    spawns = sum(1 for b in tools if b.get("name") in SUBAGENT_TOOLS)
    asks = sum(1 for b in tools if b.get("name") == "AskUserQuestion")
    denials = len((result or {}).get("permission_denials") or [])

    usage = (result or {}).get("usage") or {}
    tok_in = int(usage.get("input_tokens") or 0)
    tok_out = int(usage.get("output_tokens") or 0)
    tok_cw = int(usage.get("cache_creation_input_tokens") or 0)
    tok_cr = int(usage.get("cache_read_input_tokens") or 0)

    limited = any(limit_event(r) for r in records)
    if exit_code != 0 and LIMIT_RE.search(stderr_text):
        limited = True
    if result is None or result.get("is_error"):
        # Only the CLI's own limit phrasing at the start of a text counts; a result that merely
        # mentions 429 or rate limits (an eval about rate limiting) is an ordinary error.
        texts = [clean((result or {}).get("result", ""))] + [clean(n) for n in noise.split("\n")]
        if any(LIMIT_TEXT_RE.match(t) for t in texts):
            limited = True

    subtype = (result or {}).get("subtype")
    if limited:
        status = "usage-limit"
    elif exit_code == 124:
        status = "timeout"
    elif subtype == "error_max_turns":
        status = "turn-cap"
    elif asks > 0 or denials > 0 or escalated > 0:
        status = "stalled-human"
    elif result is None or result.get("is_error") or exit_code != 0:
        status = "error"
    else:
        status = "complete"

    return {
        "completion_status": status,
        "result_subtype": subtype,
        "result_text": (result or {}).get("result"),
        "num_turns": (result or {}).get("num_turns"),
        "duration_api_ms": (result or {}).get("duration_api_ms"),
        "total_cost_usd": (result or {}).get("total_cost_usd"),
        "tokens_in": tok_in,
        "tokens_out": tok_out,
        "tokens_cache_write": tok_cw,
        "tokens_cache_read": tok_cr,
        "tokens_total": tok_in + tok_out + tok_cw,
        "model_usage": (result or {}).get("modelUsage") or {},
        "hook_events": len(hooks),
        "session_start_events": sum(1 for n in hook_names if n.startswith("SessionStart")),
        "subagent_spawns": spawns,
        "tool_calls": len(tools),
        "ask_user_attempts": asks,
        "permission_denials": denials,
        "escalated_markers": escalated,
        "human_interventions_required": asks + denials + escalated,
    }


def main(argv):
    ap = argparse.ArgumentParser(prog="stream.py")
    sub = ap.add_subparsers(dest="cmd", required=True)
    sm = sub.add_parser("summarize")
    sm.add_argument("stream")
    sm.add_argument("--exit-code", type=int, default=0)
    sm.add_argument("--stderr", default="")
    sm.add_argument("--escalated", type=int, default=0)
    args = ap.parse_args(argv)
    stderr_text = ""
    if args.stderr:
        with open(args.stderr, errors="replace") as f:
            stderr_text = f.read()
    out = summarize(args.stream, args.exit_code, stderr_text, args.escalated)
    json.dump(out, sys.stdout, sort_keys=True)
    sys.stdout.write("\n")
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
