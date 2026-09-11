Authoring guide for `reviewer-verdict` eval cases. No engineering skill is
required beyond copying a directory and editing YAML/Markdown files.

## Directory layout

```
eval/cases/reviewer-verdict/
  gold/<case-id>/
    case.yaml       # gold label + metadata (see schema below)
    change.patch     # unified diff, applied to a clean copy of the fixture
    packet.md        # the dispatch packet text given to the reviewer
  grader/<case-id>/
    case.yaml         # calibration label + metadata (see schema below)
    reviewer-message.md   # a hand-written (or captured) reviewer message
```

`<case-id>` must be kebab-case and must equal the directory name — the
validator rejects any mismatch (`id-mismatch`).

## `case.yaml` schema — gold split

```yaml
id: <kebab-case, unique within the suite, == directory name>
suite: reviewer-verdict.gold.v1
fixture: toy-lib-template            # must exist under eval/fixtures/; a missing one surfaces as patch-does-not-apply
task: feature-task                   # must exist under eval/tasks/<task>.md — authoring rule only, the validator checks just that the field is present
patch: change.patch                  # relative; must `git apply --check` on a clean copy of the fixture
packet: packet.md                    # relative; the dispatch packet text given to the reviewer
gold:
  verdict: PASS | FAIL               # exactly one of these two in v1
  defects:                           # required non-empty iff verdict == FAIL; must be [] iff PASS
    - id: <kebab-case, unique within the case>
      file: <path inside the fixture that change.patch touches>
      description: <one paragraph, what is wrong and how to trigger it>
  decoys:                            # optional; PASS cases only: non-material nits present on purpose
    - <one line each>
tags: [<class tag>, <size tag>, ...]  # a class tag from the taxonomy below is required
```

## `case.yaml` schema — grader split

```yaml
id: <kebab-case, unique within the suite, == directory name>
suite: reviewer-verdict.grader.v1
gold:
  defects: [...]                    # same shape as the gold split's gold.defects
reviewer_message: reviewer-message.md
expected:
  defects:
    - id: <matches a gold defect id>
      identified: true | false
  extra_fail_grounds: <int>          # count of FAIL grounds the reviewer raised beyond the gold defects
```

`expected` is validated against `eval/harness/grader-schema.json`'s shape.

## Immutability rule

A case's gold label is immutable within a suite version: never edit gold —
changing a gold verdict, a defect list, or a patch's semantics requires
publishing a new `.v<n+1>` suite id and adding a new case directory, never
an in-place edit of an existing case. This keeps a suite version's numbers
reproducible; anyone re-running `reviewer-verdict.gold.v1` today or a year
from now must see the same cases.

## Taxonomy (class tags)

Every case's `tags` list must include at least one **class tag** — a tag
naming what kind of case it is, as distinct from a size tag (`size:small` /
`size:large`, intended ≤40 lines/≤3 files vs. larger).

FAIL classes:
- `input-mutation` — a function mutates its input in place
- `boundary` — boundary values (0/100 percentages, rounding)
- `unmet-criterion` — the function exists but a stated criterion is not met, tests still pass
- `silent-behavior-change` — an existing function's behaviour altered
- `vacuous-test` — a test asserts nothing meaningful; the implementation is buggy
- `security` — e.g. `Function`/`eval` on item data, prototype pollution via item keys
- `unhandled-input` — null items / NaN percentages crash where the spec implies handling
- `skipped-test` — an existing test `.skip`ped to make the suite go green

PASS classes:
- `clean` — correct, no material issues
- `style-decoy` — naming/length nits only, not material
- `robustness-decoy` — a nice-to-have beyond the spec is missing, not material
- `refactor` — a larger, behaviour-preserving internal reshuffle
- `unrelated-touch` — a harmless doc/comment change in a second file

## Running the validator

```sh
python3 eval/harness/validate-cases.py --registry eval/registry/reviewer-verdict.yaml
```

Prints `file: reason` for every invalid case and exits non-zero if any
case fails. This is also run by `bash tests/eval-cases.test.sh`, which is
registered in `tests/validate.sh` (the merge gate).
