---
name: technique-adr-amend-vs-edit-when-pinned
description: some ADRs are pinned byte-for-byte by an unrelated test's closure check — amend via a new file, never edit in place, without first checking
metadata:
  type: project
---

`tests/harness-integrity-gate.test.sh`'s C4.1c check (`git diff --quiet <sha> -- <file>`)
pins specific "Cat 3" doc files — including ADR-0034 — byte-for-byte against a
named commit, as part of an unrelated earlier unit's sweep-closure invariant. A
task whose plan says "amend ADR-XXXX (or a new superseding ADR)" is offering that
choice for exactly this reason: some ADRs cannot be edited in place even though
nothing in the current unit's own Do-Not-Touch list says so.

**Why:** discovered on item16-2 (docs-only unit) — `bash tests/validate.sh` FAILed
after adding an addendum section to ADR-0034 directly (`[C4.1c] ADR-0034 was
modified by this unit - Cat 3 must carry no note`), even though the current
unit's own Do-Not-Touch list only forbade the gate script and its test file. The
constraint on ADR-0034 was inherited from a wholly different, earlier unit
(gh425/hcb) and is invisible unless you grep the test suite for the file's path.

**How to apply:** before editing ANY existing ADR in place, grep
`tests/*.test.sh` for that ADR's filename first. If a `git diff --quiet <sha> --
<file>` pin exists, author a new ADR that states `amends ADR-XXXX (does not
supersede it)` instead — this repo already has a well-established convention
for this (see ADR-0006/0009/0026 amending ADR-0004/0006/0010 in separate files).
`git checkout -- <file>` cleanly reverts an in-place edit if you discover the pin
only after editing, as long as no other agent has touched the same file
concurrently.
