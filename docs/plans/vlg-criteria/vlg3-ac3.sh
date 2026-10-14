#!/usr/bin/env bash
# vlg3-ac3.sh: CONTRIBUTING.md carries the lane-runner bullet VERBATIM,
# directly after the `bash tests/validate.sh` bullet, and says the serial run
# stays the merge gate. Claim-anchored: the exact text below is the claim.
# Prints nothing and exits 0 on success.
. "$(cd "$(dirname "$0")" && pwd)/lib.sh"
python3 - <<'PY'
import sys
s = open('CONTRIBUTING.md').read()
anchor = "  marketplace.json/plugin.json consistency.\n"
bullet = (
    "- `bash tests/validate-lanes.sh` is an opt-in parallel run of the same\n"
    "  sections (default 3 lanes, `--lanes N` for 1-8). Each lane works in a\n"
    "  private copy of the checkout, and any section that changes the lane's\n"
    "  `.claude/reviewed/` FAILs, including a write relative to the repository\n"
    "  root, which the serial leak guard cannot see. It skips the leak guard's\n"
    "  nested run, so `bash tests/validate.sh` stays the merge gate.\n"
)
if s.count(anchor) != 1:
    print(f"anchor line occurs {s.count(anchor)} times, want 1"); sys.exit(1)
if s.count(bullet) != 1:
    print("lane-runner bullet not present verbatim exactly once"); sys.exit(1)
if s.index(anchor) + len(anchor) != s.index(bullet):
    print("lane-runner bullet does not follow the validate.sh bullet directly"); sys.exit(1)
PY
