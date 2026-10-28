Unit: rfp-u2

## Objective
Record the vocabulary and the design decision of rfp-u1's refutation pass. Add three `CONTEXT.md` glossary
entries: **refutation pass**, **judgment defect** and **refutation outcome**. Land the plan's ADR draft as
the next free `docs/adr/` number, named `<NNNN>-refutation-pass-inside-reviewer-turn.md`. Dispatch only
after rfp-u1 has a reviewer PASS, and quote that PASS line in the dispatch. Neither file is version-stamped,
so there is no bump. The prose must match the shipped `agents/reviewer.md` bullet "Refutation pass (before
any FAIL verdict)". Where they disagree, the bullet wins.

## Retrieval
Fast path, no tracker issue. Spec: `docs/plans/2026-10-27-refutation-pass.md` ("Step 2", the "ADR-draft"
blockquote in Context, the Clarifications terminology line). This file is the contract of record.

## Affected files
- `CONTEXT.md` (anchor: immediately after the entry that begins `**FAIL-block count**:` and its `_Avoid_:` line)
- `docs/adr/<NNNN>-refutation-pass-inside-reviewer-turn.md` (new; `<NNNN>` is one more than the highest existing number, 0043 at 1073743d)

## Ordered edits
1. file: `CONTEXT.md`
   anchor: the `_Avoid_: FAIL count (when the record is meant)` line that closes `**FAIL-block count**:`
   insert-after (one blank line before each entry, matching the file; replace `<date>` with the landing date):
~~~

**refutation pass**:
(unit rfp-u1, <date>) — the reviewer's challenge of its own [[judgment defect]]s
  before a FAIL verdict: one fresh-context `explorer` subagent tries to disprove
  each against the whole file, its callers and the baseline, and only defects
  that survive reach the [[FAIL record]]. It owns no verdict and writes no
  marker; a FAIL it prevents writes no [[FAIL block]], so the [[FAIL-block count]]
  is unchanged. Distinct from the reviewer's "Refute, don't rubber-stamp" stance,
  which attacks the change, not the reviewer's own findings.
_Avoid_: refuter (it is not a persona), verifier, second gate

**judgment defect**:
(unit rfp-u1, <date>) — a FAIL defect the reviewer found by reading code, as
  opposed to a mechanical FAIL ground: a `review-precheck.sh` failure line, an
  uncommitted tree, an out-of-scope path, or a command whose output shows the
  failure. Only judgment defects enter the [[refutation pass]].

**refutation outcome**:
(unit rfp-u1, <date>) — the per-defect answer of the [[refutation pass]]:
  REFUTED, CONFIRMED or UNCERTAIN. REFUTED and CONFIRMED each need an artifact
  (a command and its output, or a quoted `file:line`) that the reviewer
  re-checks; an answer without one is UNCERTAIN. When nothing stands and an
  UNCERTAIN remains, the verdict is INSUFFICIENT-CONTEXT, never FAIL.
~~~
2. file: `docs/adr/<NNNN>-refutation-pass-inside-reviewer-turn.md` (new)
   Write it in the house format (`# ADR <NNNN>: <title>`, `Date:`, `Status: Accepted`, `Related:`, then
   `## Context`, `## Decision`, `## Consequences`) from the plan's ADR-draft blockquote. Keep the three
   rejected alternatives: (C) an orchestrator-dispatched refuter after the FAIL, a nested `Mode: advisory`
   reviewer, and a new `refuter` persona. Each must keep its reason. The title is "The refutation pass runs
   inside the reviewer's turn". Use the exact phrases `inside the reviewer's turn`, `a FAIL it prevents
   writes no FAIL block` and `caller allowlist`.
3. command: `git add CONTEXT.md docs/adr/ && git commit -m "docs(rfp-u2): glossary entries and ADR for the reviewer's refutation pass (rfp-u2)"`
   expect: 0
   Run `git status --short` first. If a tracked file outside "Affected files" is modified, stop and report it.

## Do NOT touch
- `agents/`, `templates/`, `hooks/`, `adapters/`, `bin/`, `.claude/` (rfp-u1 shipped the behaviour; criterion 4)
- Every existing `CONTEXT.md` entry, including the reviewer's "Refute" stance wording (criterion 4 guards the scope; the reviewer judges the diff)

## Acceptance criteria
1. run: `bash -c 'for t in "refutation pass" "judgment defect" "refutation outcome"; do grep -c "^\*\*$t\*\*:$" CONTEXT.md; done | tr "\n" " "'`
   exit: 0
   stdout: `1 1 1 `
   mutation: delete the `**judgment defect**:` entry; stdout is `1 0 1 `.
2. run: `bash -c 'tr -s " \n" " " < CONTEXT.md > /tmp/rfp-u2.flat; for p in "It owns no verdict and writes no marker" "which attacks the change, not the reviewer" "an answer without one is UNCERTAIN" "Only judgment defects enter the [[refutation pass]]" "the verdict is INSUFFICIENT-CONTEXT, never FAIL"; do grep -cF -- "$p" /tmp/rfp-u2.flat; done | tr "\n" " "'`
   exit: 0
   stdout: `1 1 1 1 1 `
   mutation: change "INSUFFICIENT-CONTEXT, never FAIL" to "ESCALATE-TO-HUMAN"; the fifth count is `0`.
3. run: `bash -c 'tr -s " \n" " " < CONTEXT.md | grep -ciE "the refuter|refuter persona|refutation pass writes (a|the) (marker|\.fail)"; true'`
   exit: 0
   stdout: `0`
   mutation: write "the refuter persona" into the first entry; stdout is `1`.
4. run: `bash -c 'b=$(git log --format=%H --grep="(rfp-u2)" | tail -1); l=$(git log --format=%H --grep="(rfp-u2)" | head -1); [ -n "$b" ] || { echo no-commits; exit 1; }; git diff --name-only "$b^..$l" | grep -v -e "^CONTEXT\.md$" -e "^docs/adr/[0-9]\{4\}-refutation-pass-inside-reviewer-turn\.md$" | wc -l'`
   exit: 0
   stdout: `0`
   mutation: touch `agents/reviewer.md` in the rfp-u2 commit; stdout is `1`.
5. run: `bash -c 'f=$(ls docs/adr/[0-9][0-9][0-9][0-9]-refutation-pass-inside-reviewer-turn.md 2>/dev/null); [ "$(printf "%s\n" $f | grep -c .)" = 1 ] || { echo "adr-count-not-1"; exit 1; }; tr -s " \n" " " < "$f" > /tmp/rfp-u2.adr; for p in "Status: Accepted" "inside the reviewer" "a FAIL it prevents writes no FAIL block" "caller allowlist" "## Consequences"; do grep -cF -- "$p" /tmp/rfp-u2.adr; done | tr "\n" " "; bash tests/validate.sh >/dev/null 2>&1; echo "validate=$?"'` (Bash tool timeout 600000 ms)
   exit: 0
   stdout: `1 1 1 1 1 validate=0`
   mutation: drop the rejected-alternative paragraph that names the caller allowlist; the fourth count is `0`.

## Pre-resolved context
- Glossary entry shape: `**term**:` on its own line, a `(unit <id>, <date>) — ...` body indented two spaces
  on continuation lines, and an optional `_Avoid_:` line (see `**FAIL-block count**:` and
  `**advisory verdict**:` in `CONTEXT.md`). `[[...]]` cross-links resolve to existing entry names:
  `FAIL record`, `FAIL block`, `FAIL-block count`.
- The ADR house format is `docs/adr/0042-contract-of-record-lives-in-a-per-unit-contract-file.md`. The
  highest number at 1073743d is 0042.
- `knowledgeWrites` is `apply` in `.claude/persona-config.json`, so the scribe writes `CONTEXT.md` directly.
- The meaning of "Refute" at `agents/reviewer.md:46` (attack the change) is deliberately kept distinct from
  the new term. Do not edit that line.

## Escalation
If the shipped `agents/reviewer.md` bullet contradicts any entry text above, follow the bullet and quote the
contradiction in your report. If the anchor entry is missing, stop and report. If a gate blocks a write,
report it and wait.
