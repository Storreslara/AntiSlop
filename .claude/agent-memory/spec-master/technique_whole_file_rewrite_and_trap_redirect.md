---
name: technique-whole-file-rewrite-and-trap-redirect
description: A whole-file rewrite in a contract must be before/after hunks (rp-u6's contract-anchors fails `new file` on an existing file); an EXIT trap firing inside a `{ ...; } >/dev/null 2>&1` group writes to /dev/null
metadata:
  type: feedback
---

Two mechanics learned writing rp-u15 (2026-10-22):

1. `anchor: new file` on a file that already exists passes the scratch applier but fails rp-u6's
   `bin/contract-anchors.js` (`new exists`), and it poisons the `--chain` check of every later contract.
   Slice the rewrite into before/after hunks by script and verify that replacing them reproduces the new file
   byte for byte.
   **Why:** the chain check is the anchor-exists proof every queued contract relies on.
   **How to apply:** if you are ever tempted by "replace the whole file", generate hunks instead.

2. A library that runs `exit` while it is sourced inside `{ . lib; } >/dev/null 2>&1` fires the EXIT
   trap with that redirection still in place, so the trap's message vanishes. Save stderr first (`exec 3>&2`)
   and echo to `>&3` in the trap. `exit 2` inside an EXIT trap does set the final status.

Also: re-read `git log -1` right before a chain run. A queued unit (st-u4) landed mid-session and the chain
re-applied it, which looked like anchor failures. See [[technique-prove-contracts-on-a-clone]].
