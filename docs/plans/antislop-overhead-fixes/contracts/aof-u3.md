Unit: aof-u3

## Objective
Every lead-programmer dispatch carries a binding unit scope, and the reviewer checks the diff against it.
- The orchestrator writes `## Affected files` into any lead-programmer dispatch that has no contract, deriving
  it from the paths the request names, their tests and the explorer's blast radius.
- lead-programmer edits only those files, plus `.claude/` and `docs/plans/` bookkeeping, and reports any
  other change as a proposal.
- The reviewer FAILs a diff that touches a file outside the scope, unless an acceptance criterion requires
  that file.

This is spec Step 3 (P3, alt 3A).

## Retrieval
Fast path, no tracker issue. Spec: `docs/plans/antislop-overhead-fixes/spec.md`, "Step 3 (aof-u3)" and
"Context, P3". This file is the contract of record.

## Affected files
- `agents/orchestrator.md`: the paragraph that ends "and paste its distilled answer under `## Pre-resolved context` in the dispatch before routing it." (currently lines 110-113)
- `agents/lead-programmer.md`: insert a new bullet directly after the `- **Coding discipline**:` bullet (currently line 66)
- `agents/reviewer.md`: the `- **Materiality filter**:` bullet (currently lines 28-33)
- `adapters/codex/agents/lead-programmer.toml` (after its `- **Coding discipline**:` bullet, line 65) and
  `adapters/codex/agents/reviewer.toml` (its Materiality filter bullet, line 46)
- `adapters/cursor/agents/lead-programmer.md` (after its `- **Coding discipline**:` bullet, line 64) and
  `adapters/cursor/agents/reviewer.md` (its Materiality filter bullet, line 43)
- `.claude/agents/orchestrator.md`, `.claude/agents/lead-programmer.md`, `.claude/agents/reviewer.md` and
  `fileHashes`: **generated only** by `node bin/cli.js --update`
- `.claude-plugin/plugin.json` and `CHANGELOG.md`, in the same commit
- `tests/unit-scope-prose.test.sh` (new)
- `tests/validate.sh` (registration)

## Ordered edits
1. In `agents/orchestrator.md`, append these sentences to the end of the paragraph above, as one new
   paragraph:
   "**Unit scope.** Every lead-programmer dispatch carries `## Affected files`. For a dispatch with no
   dispatch contract, write that section yourself from the paths the request names, those paths' test files
   or test directory, and the explorer's blast radius, and never leave it empty. A file the user names in the
   request is in scope; a file outside the list is not, however related it looks."
2. In `agents/lead-programmer.md`, insert this bullet after the Coding discipline bullet:
   "- **Unit scope**: edit only the files listed under your dispatch's `## Affected files`, plus
   `docs/plans/` and `.claude/` bookkeeping. Any other change you believe is needed (a glossary entry, a
   README line, an ADR, a caller outside the list) goes in your report under
   `Proposed out-of-scope changes:` and is not applied."
3. In `agents/reviewer.md`, append this to the Materiality filter bullet, before its closing sentence about
   non-blocking notes if the bullet's structure requires it:
   "A changed file outside the unit's scope is also a FAIL reason: list
   `git diff --name-only <baseline>..HEAD -- . ':(exclude).claude' ':(exclude)docs/plans'` and FAIL on any
   path not listed under the dispatch's `## Affected files`, unless an acceptance criterion of the unit
   requires that file."
   Then replace "Only correctness, security, and unmet-acceptance-criteria defects are FAIL reasons" with
   "Only correctness, security, unmet-acceptance-criteria and out-of-scope-file defects are FAIL reasons".
4. Hand-sync the sentences from edits 2 and 3 into the four adapter ports at the anchors listed, keeping each
   file's own format (TOML multi-line string, Markdown). In the reviewer ports, make the same change to the
   "Only correctness, security, and unmet-acceptance-criteria defects" sentence wherever it appears.
5. Bump `.claude-plugin/plugin.json` (patch) and add a `CHANGELOG.md` entry naming aof-u3, which says that
   reviewers now FAIL out-of-scope files.
6. Run `node bin/cli.js --update` to regenerate the `.claude/agents/` mirrors and `fileHashes`.
7. Write `tests/unit-scope-prose.test.sh`. For each (file, fixed string) pair, it asserts `grep -qF`:
   - `Every lead-programmer dispatch carries \`## Affected files\`` in `agents/orchestrator.md` and
     `.claude/agents/orchestrator.md`;
   - `edit only the files listed under your dispatch's \`## Affected files\`` in `agents/lead-programmer.md`,
     `.claude/agents/lead-programmer.md`, `adapters/codex/agents/lead-programmer.toml` and
     `adapters/cursor/agents/lead-programmer.md`;
   - `A changed file outside the unit's scope is also a FAIL reason` in `agents/reviewer.md`,
     `.claude/agents/reviewer.md`, `adapters/codex/agents/reviewer.toml` and `adapters/cursor/agents/reviewer.md`;
   - `out-of-scope-file defects are FAIL reasons` in the same four reviewer files.

   On any miss it prints the pair and exits 1. Register it in `tests/validate.sh` so that a FAIL makes
   validate.sh exit non-zero.
8. Commit with the subject `feat(aof-u3): unit scope is binding for lead-programmer and checked by the reviewer`.

## Do NOT touch
- `templates/persona-protocol*.md` and `.claude/protocol-digest.md`: the rule lives in the three personas.
- `agents/task-master.md`, `skills/pathfinder/`: contracts already carry `## Affected files`.
- `agents/scribe.md`, `agents/spec-master.md`, and the Scribe dispatch convention in orchestrator.md: those
  are aof-u4.
- `eval/` (scope.sh, allowed paths, prompts): pre-registered scoring is unchanged.
- Hooks: there is no new path gate (alternative 3C was rejected).
- `.claude/` mirrors by hand.

## Acceptance criteria
- AC3.1 run: `bash tests/unit-scope-prose.test.sh` (exit 0). mutation: deleting any one sentence from any of
  the listed files fails it.
- AC3.2 run: `bash tests/validate.sh` (exit 0). mutation: `exit 1` as line 2 of the new test makes
  validate.sh exit non-zero.
- AC3.3 run: `git show --name-only --format= HEAD | grep -qx '.claude-plugin/plugin.json' && git show --name-only --format= HEAD | grep -qx CHANGELOG.md`.

## Pre-resolved context
- Evidence from pilot 4: in E3 B, lead-programmer edited `CONTEXT.md`, which no task named. Arm A did the
  same in E3. The other B leaks came from scribe and spec-master, which aof-u4 covers.
- The orchestrator's direct single-unit dispatches (E1 to E4 in pilot 4) had no contract, so they had no
  `## Affected files` at all. That is why rule 1 exists.
- agents/orchestrator.md:110-113 already requires spawning the explorer first for a contract-less
  lead-programmer dispatch, so the blast radius is available at that point.
- The adapter ports are hand-synced, not generated (see the four-copy sync precedent for reviewer.md).
  `tests/validate.sh` iterates over `adapters/cursor/agents/*.md` (around line 327) and
  `adapters/codex/agents/*.toml` (around line 819) for format checks, so keep each port's syntax valid.
- Earlier `vacuous`-class units on agents/orchestrator.md: gh307, gh310 and gh348-14. Prove that each grep
  can fail.

## Escalation
If a reviewer port does not contain the "Only correctness, security, and unmet-acceptance-criteria" sentence
in that exact form, add the new sentence only and report the difference. If `--update` reports a diverged
mirror it will not regenerate, quote its message and stop. If a gate blocks a write, report it and wait.
Changes outside "Affected files" go to the report as proposals; this unit follows its own rule.
