# Re-syncing vendored mattpocock/skills content

`skills/` vendors 12 skills from
[mattpocock/skills](https://github.com/mattpocock/skills) (MIT licensed —
see `skills/THIRD-PARTY-NOTICES.md`), pinned at a single upstream commit
SHA recorded in that same NOTICES file. This doc is the runbook for
checking whether the pin has drifted from upstream `main`, and for
deciding whether/how to re-pin.

## What's vendored

| skill | upstream path | shape |
|---|---|---|
| `grill-me` | `skills/productivity/grill-me` | verbatim |
| `grilling` | `skills/productivity/grilling` | verbatim |
| `handoff` | `skills/productivity/handoff` | verbatim |
| `tdd` (+ `tests.md`, `mocking.md`) | `skills/engineering/tdd` | verbatim |
| `diagnosing-bugs` (+ `scripts/hitl-loop.template.sh`) | `skills/engineering/diagnosing-bugs` | verbatim |
| `improve-codebase-architecture` (+ `HTML-REPORT.md`) | `skills/engineering/improve-codebase-architecture` | verbatim |
| `codebase-design` (+ `DEEPENING.md`, `DESIGN-IT-TWICE.md`) | `skills/engineering/codebase-design` | verbatim |
| `domain-modeling` (+ `ADR-FORMAT.md`, `CONTEXT-FORMAT.md`) | `skills/engineering/domain-modeling` | verbatim |
| `implement` | `skills/engineering/implement` | verbatim |
| `to-spec` | `skills/engineering/to-spec` | **repointed** (see below) |
| `to-tickets` | `skills/engineering/to-tickets` | **repointed** (see below) |
| `code-review` | `skills/engineering/code-review` | **repointed** (see below) |

The first 9 are byte-verbatim aside from their provenance header. The last
3 (`to-spec`, `to-tickets`, `code-review`) have their
`/setup-matt-pocock-skills` references repointed to antislop's native setup
flow (`install-antislop` + `persona-config.json` `issueTracker` + the
retrieval contract) — everything else in those 3 files is verbatim. Full
table with exact upstream paths: `skills/THIRD-PARTY-NOTICES.md`.

The pinned SHA lives in `skills/THIRD-PARTY-NOTICES.md`, in the sentence
"pinned at upstream commit `<sha>`". That file is the single source of
truth — `scripts/resync-vendored-skills.sh` reads the SHA from it rather
than hardcoding a second copy.

## Vendored file shapes (must match to diff correctly)

Every vendored file carries a provenance header comment pointing back to
`skills/THIRD-PARTY-NOTICES.md`. Where that header sits, and how much
blank-line bookkeeping surrounds it, differs by file shape — get this
wrong and a diff against upstream reports spurious drift on every file:

1. **`SKILL.md` files (frontmatter).** The header sits *after* the closing
   `---` of the YAML frontmatter block, followed by the blank line that
   already separates upstream's frontmatter from its body:
   `---\nname: ...\n---\n<!-- header -->\n\n<body>`. To reconstruct "what
   this file should contain": take the upstream file as-is and insert the
   header line immediately after its closing `---` line — the blank line
   and body that already follow in upstream need no further edits.
2. **Markdown companions with no frontmatter** (`tests.md`, `mocking.md`,
   `HTML-REPORT.md`, `DEEPENING.md`, `DESIGN-IT-TWICE.md`, `ADR-FORMAT.md`,
   `CONTEXT-FORMAT.md`). The header sits at literal line 1, followed by one
   blank line, then the upstream body starting at what was upstream's own
   line 1 (upstream files of this shape have no leading blank line of
   their own). Reconstruction: `<header>\n\n` + the full upstream file.
3. **`skills/diagnosing-bugs/scripts/hitl-loop.template.sh` has no header
   at all** — its `#!/usr/bin/env bash` shebang stays on line 1 so the
   script remains directly runnable. Reconstruction: the upstream file,
   unchanged.

`scripts/resync-vendored-skills.sh` implements exactly this per-shape
reconstruction (`fm` / `doc` / `raw` in its `FILES` table) and diffs the
reconstruction against the actual local file, rather than trying to strip
the local file down to a "body" — reconstructing forward from upstream is
less error-prone than guessing how many lines to strip backward.

## Running the drift check

```bash
bash scripts/resync-vendored-skills.sh          # prints a per-skill report
bash scripts/resync-vendored-skills.sh --check   # same report; see exit
                                                  # codes below
```

The script fetches each vendored file's upstream counterpart at the pinned
SHA from `raw.githubusercontent.com`, reconstructs the expected local
content per the shape rules above, and diffs it against what's actually
checked into `skills/`. The 3 repointed skills are listed for awareness
(vendored or still pending Step A.3) but are never diffed by `--check` —
their repoint edits mean a byte diff against raw upstream is expected to
show a difference, so they need a human read of the diff around the
`/setup-matt-pocock-skills` reference rather than a mechanical check.

### Per-skill status and `--check` exit codes

| status | meaning |
|---|---|
| `[OK]` | local content byte-matches the pinned upstream SHA |
| `[DRIFTED]` | local content differs from upstream (genuine content drift) |
| `[MISSING]` | a file the `FILES` table expects doesn't exist locally |
| `[ERROR]` | the upstream fetch for this skill failed (network/curl error) |

| `--check` exit code | meaning |
|---|---|
| `0` | all 9 verbatim skills `[OK]` |
| `1` | `DRIFT DETECTED` — genuine content drift or a missing file, and all fetches succeeded |
| `2` | `FETCH ERRORS` (drift status unknown because an upstream fetch failed), an unrecognized argument, or another script error (e.g. missing pinned SHA) |

Exit 2 is deliberately distinct from exit 1: a transient network blip
fetching upstream must never be mistaken for genuine drift in already-
vendored content.

If `--check` reports drift on one of the 9 verbatim skills where nobody
has edited `skills/` locally, that means the previously-vendored content
does not actually match what's claimed at the pinned SHA — a content
defect in whichever step vendored it, not something to silence in the
script.

## Deciding whether to re-sync, and applying it

1. Run `bash scripts/resync-vendored-skills.sh` (without `--check`) and
   read the per-skill report. `[OK]` means byte-identical to the pin;
   `[DRIFTED]` lists the files that differ.
2. For each drifted file, fetch the current upstream `main` version and
   read the diff against what's vendored
   (`curl -sS https://raw.githubusercontent.com/mattpocock/skills/main/<upstream-path>`).
   Decide whether the upstream change is worth pulling in (bug fix,
   clarity improvement) or worth skipping (upstream scope drift this repo
   doesn't want).
3. To apply an update to a given file: replace its body with the new
   upstream content, keeping the provenance header in the same position
   documented above (and keeping the repoint edit, if it's one of the 3
   repointed skills — re-apply the `/setup-matt-pocock-skills` →
   antislop-native substitution on top of the new upstream text).
4. Once all desired files are updated, re-pin: fetch upstream's current
   commit SHA for `main`
   (`git ls-remote https://github.com/mattpocock/skills main`) and update
   the SHA in `skills/THIRD-PARTY-NOTICES.md` (both the prose sentence and
   every per-file provenance header comment across all 12 skills — a
   project-wide find/replace of the old SHA for the new one).
5. Run `bash scripts/resync-vendored-skills.sh --check` again — it should
   report `[OK]` for all 9 verbatim skills against the new pin.
6. Run `bash tests/validate.sh` and commit the update with a message
   noting the old and new SHA.

## Cadence

No fixed schedule is enforced by tooling. Run the check (step 1 above)
periodically (e.g. before a plugin version bump) or when a consumer
reports that upstream has fixed something this repo's vendored copy still
has.
