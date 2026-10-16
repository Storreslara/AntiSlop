# ADR 0042: The contract of record lives in a per-unit contract file

Date: 2026-10-16
Status: Accepted
Related: ADR-0040

## Context

Implementers and reviewers read 50-170 KB plan docs to find one `Unit:` block. The contract of record was a block inside a plan file or issue body, and a plan revision between two dispatches could silently replace it (CONTEXT.md "contract of record").

## Decision

Every dispatch contract is written to `docs/plans/<plan-slug>/contracts/<unit-id>.md`, whose line 1 is `Unit: <unit-id>`. The plan doc and the tracker issue link to it and hold no copy, and the dispatch's Retrieval line cites the file. Units sliced before the change keep the plan-file and issue-body forms as a legacy fallback.

## Consequences

- One source of truth (no plan/contract drift by construction), a 2-6 KB read instead of 50-170 KB, and the contract-score guard scores the file.
- A contract revision is a visible commit to one file.
- Open follow-ups from the landing (ptr-u3b): a unit with both a lead and a scribe contract maps both to the same file name; `scripts/unit-outcomes.js` still reads only the issue-body block.

## Alternatives rejected

- Keep the contracts embedded and grep them out: drift stays possible and every implementer must know the grep.
- Issue-body-only: the fast path has no issue.

## Why the three ADR tests hold

- Hard to reverse: it touches every persona's dispatch path.
- Surprising without context: a reader would expect the contract in the plan or the issue.
- A real trade-off: the alternatives above were weighed against a second file per unit.
