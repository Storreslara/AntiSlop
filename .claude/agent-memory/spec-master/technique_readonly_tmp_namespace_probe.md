---
name: technique-readonly-tmp-namespace-probe
description: Fixed /tmp scratch names only flip validate.sh's exit code when /tmp is unwritable, never under same-uid concurrency; prove a mktemp fix with an `unshare -rm` read-only-/tmp probe instead.
metadata:
  type: feedback
---

A "concurrency" fix for fixed `/tmp/<name>` files cannot be proven with a concurrency probe
when the exit code comes from the command (`if python3 ... 2>/tmp/x; then`) and the file only
feeds a FAIL message. Measured on 2026-10-14: 30/30 green at HEAD under six-way concurrency.
The real flip is an UNWRITABLE fixed path (another uid's stale file, or a sandbox), where the
sections FAIL with an empty reason. An advisory section silently printed OK.

**Why:** the vtmp-1 brief assumed the fixed names caused watch item j. They cannot, so j stays open.

**How to apply:** for a red-at-HEAD behavioural check, run
`unshare -rm` + `mount -t tmpfs -o ro none /tmp`, with TMPDIR on a private tmpfs at
`/var/tmp`, and bind the checkout there first, because a scratch worktree under /tmp gets
hidden. `mount -o remount,ro` fails in a userns. Filter the cleanup check to `tmp.*`, since
node leaves `node-compile-cache`. Note that `vsec`/`vrun` skip validate.sh's prelude, so a
global temp var is unbound there; use per-section mktemp. See [[verify-own-criteria-nonvacuous]].
