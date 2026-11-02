Unit: rs-docs

## Objective
Plan unit 6 (records D2); exact text: plan unit 6. ADR-0045 :28 (`--skip-worktree`) notes: closed by ADR-0046 except the submodule case, closed by rs-check. Wiki "Retired (0.32.0)": the human-decision gate is a registered stub, not gone. ADR-0046: the :11, :18, :19 rewordings; each closed residual names its unit (rs-stamp, rs-check, rs-prose, rs-corelib, rs-tokens); D2 (a)-(d), one single-line bullet each, ending "Accepted (2026-11-03 residuals plan)." (that phrase nowhere else). Line cites (wiki changelog, `CONTEXT.md`, harness glossary). Glossary entries **advisory dispatch**, **advisory review-join stamp**. One `[Unreleased]` CHANGELOG bullet naming `rs-docs`.

## Retrieval
No tracker issue; plan unit 6 in `docs/plans/2026-11-03-residuals.md`.

## Affected files
- `docs/adr/0045-reviewer-by-lane.md`
- `docs/adr/0046-lean-pipeline-2.md`
- `.claude/wiki/architecture.md`
- `.claude/wiki/changelog.md`
- `CONTEXT.md`
- `docs/harness-glossary.md`
- `CHANGELOG.md`

## Do NOT touch
- `agents/`, `hooks/`, `bin/`, `tests/`, `adapters/`

## Acceptance criteria
1. run: `a=.claude/wiki/architecture.md; echo $(grep -F 'closed by ADR-0046' docs/adr/0045-reviewer-by-lane.md | grep -c submodule) $(grep -cF 'human-decision gate are gone' $a) $(grep -F 'Retired (0.32.0)' $a | grep -c stub)`
   exit: 0
   stdout: `1 0 1`
   mutation: no ADR-0045 note → `0 0 1` (baseline `0 1 0`).
2. run: `f=docs/adr/0046-lean-pipeline-2.md; n=0; for u in rs-stamp rs-check rs-tokens rs-corelib rs-prose; do grep -q "$u" $f && n=$((n+1)); done; echo $(grep -c 'deletes a non-empty sentinel' $f) $(grep -c 'one-line or one-row edit' $f) $(grep -c 'small, test-pinned edit' $f) $(grep -c 'uses the umask' $f) $(grep -c 'Accepted (2026-11-03 residuals plan)\.' $f) $n`
   exit: 0
   stdout: `0 0 1 1 4 5`
   mutation: one D2 item missing → fifth `3`; rs-tokens unrecorded → last `4` (baseline `1 1 0 0 0 0`).
3. run: `w=.claude/wiki/changelog.md; g="CONTEXT.md docs/harness-glossary.md"; echo $(grep -c 'review-precheck.sh:192-198\|unit-scope.sh:19-35' $w) $(grep -c 'review-precheck.sh:193-199' $w) $(grep -c 'unit-scope.sh:19-40' $w) $(cat $g | grep -c 'reviewed-path-gate.sh:36`') $(cat $g | grep -c 'reviewed-path-gate.sh:36-37`')`
   exit: 0
   stdout: `0 1 1 0 2`
   mutation: a glossary cite unchanged → `0 1 1 1 1` (baseline `2 0 0 2 0`).
4. run: `t=$(tr -s ' \n' ' ' < docs/harness-glossary.md); echo $(grep -cF 'machine-readable form `reviewer-route-gate-core.sh` reads' <<<"$t") $(grep -oF 'no hook reads it; the reviewer writes no marker for it' <<<"$t" | wc -l) $(grep -oF 'Retired (lp-joinstamp): no hook writes it.' <<<"$t" | wc -l)`
   exit: 0
   stdout: `0 1 1`
   mutation: entry unchanged → `1 0 1`.
5. run: `sed -n '/^## \[Unreleased\]/,/^## \[0\.34\.0\]/p' CHANGELOG.md | grep -c 'rs-docs'`
   exit: 0
   stdout: `1`
   mutation: no bullet → `0`, exit 1.
6. run: `bash tests/validate.sh >/dev/null 2>&1` (timeout 600000 ms; after the final commit)
   exit: 0
   stdout: empty
   mutation: any suite failure → exit 1.
