Unit: wrd-u3

## Objective
Fix three documentation findings from the cosmetic close-out and add one glossary entry, all in `docs/`: (a) the `dispatch message` entry of `docs/harness-glossary.md` says a path whose name holds "a quote" is marked out, but the gate's case catches only the double quote, so say "a double quote"; and it says the cited contracts' "entries and exclusions can be added", which is false for the gate's fallback (there the cited contract's exclusions replace the message's), so drop that parenthesis and leave the rule to the gate, which the entry already points at; (b) the `multi-part stdout spec` entry gains one sentence for wrd-u1's rule (a spec whose last part is empty fails); (c) the cos-u3 contract says "mode stays 755" and "restore mode 755" for two test files that are 100644, so correct each to 644 with an amended line under it; (d) a new `amended line` entry names the `amended <date> (<unit>):` convention that wrd-u3 itself uses and that cos-u1 used twice. Every claim the entries make is pinned by a criterion below to the line or behaviour it describes; write no other claim.

## Retrieval
Fast path, no tracker issue. Spec: `docs/plans/2026-10-29-wording-followups.md` (Step 3). This file is the contract of record. Dispatch after wrd-u1 has PASSed (criterion 3 runs wrd-u1's test, and edit 3 describes wrd-u1's rule) and after wrd-u2 has PASSed (one unit under review at a time). It touches no `.claude/` file and runs no `--update`. Implementer tier: opus (the `dispatch message` entry FAILed review three times in cos-u5, twice on sonnet and once on opus, each time on a false clause).

## Affected files
- `docs/harness-glossary.md` (anchors: the line after `**dispatch message** (synonym: **dispatch prompt**):`; the line after `**multi-part stdout spec**:`; the last line of the file; mode stays 644)
- `docs/plans/2026-10-29-cosmetic-closeout/contracts/cos-u3.md` (anchors: the two `## Affected files` bullets for `tests/unit-scope-prose.test.sh` and `tests/persona-prose-pins.test.sh`; the `## Escalation` line; mode stays 644)

These are the only paths in scope.

## Ordered edits
Edits 1 to 6 use the Edit tool, never a Bash heredoc. Each `before` text occurs exactly once in its file. spec-master applied these edits to a scratch clone of f566aeef (with wrd-u1 and wrd-u2 applied) and ran every criterion and mutation below there.

1. file: `docs/harness-glossary.md`
   anchor: the line after `**dispatch message** (synonym: **dispatch prompt**):`
   replace: `the contract files the message cites (their entries and exclusions can be added) and the` with `the contract files the message cites and the`

2. file: `docs/harness-glossary.md`
   anchor: the same line as edit 1
   replace: `a changed path whose name holds a quote, backslash or control character is marked out` with `a changed path whose name holds a double quote, backslash or control character is marked out`

3. file: `docs/harness-glossary.md`
   anchor: the line after `**multi-part stdout spec**:`
   replace: `so a missing line, an extra line and an extra blank line all fail. ` with `so a missing line, an extra line and an extra blank line all fail. A spec whose last part is empty (nothing between its last two backticks) fails whatever the output, with ` followed by a backticked `fail stdout spec ends in an empty part`, then `; an empty part before the last stands for a blank line (wrd-u1). ` (the trailing space is kept, so the next sentence, `Any run of spaces`, follows as before)
   The resulting text between `all fail.` and `Any run of spaces` is exactly:
~~~
 A spec whose last part is empty (nothing between its last two backticks) fails whatever the output, with `fail stdout spec ends in an empty part`; an empty part before the last stands for a blank line (wrd-u1). 
~~~

4. file: `docs/harness-glossary.md`
   anchor: the last line of the file, which ends in a newline. At f566aeef it is the `**judge**:` entry's text line; the parallel plan `docs/plans/2026-10-29-scope-gate-baseline-hardening.md` also appends an entry (`dispatch baseline`), so if it has landed first, the last line is that entry's, and the new entry goes after it all the same
   append, after that line's newline (so one blank line separates the entries, as everywhere above):
~~~

**amended line**:
(plan 2026-10-29-wording-followups, unit wrd-u3) — an indented line beginning `amended <date> (<unit>):` that a later unit adds to a committed [[contract file]] next to the text it corrected (after the `stdout:` line, for an acceptance criterion); it records the correction and names that unit. Under an acceptance criterion, `bin/review-precheck.sh` reads only the criterion's numbered `run:` line and its indented `exit:` and `stdout:` lines, so an amended line changes no check. The script reads a contract as the baseline commit holds it and fails with `contract: changed-since-baseline` when HEAD holds a different copy.
~~~
   The file must end in exactly one newline after the new text line.

5. file: `docs/plans/2026-10-29-cosmetic-closeout/contracts/cos-u3.md`
   anchor: the two `## Affected files` bullets that end in `mode stays 755)` (for `tests/unit-scope-prose.test.sh` and for `tests/persona-prose-pins.test.sh`)
   In each of the two bullets replace `mode stays 755)` with `mode stays 644)`, and insert directly under the bullet this line (two leading spaces, no backticks, so the gate and the precheck never read a path from it):
~~~
  amended 2026-10-29 (wrd-u3): this said mode stays 755; the file is 100644 at the cos-u3 baseline 1a987d32 and after cos-u3.
~~~

6. file: `docs/plans/2026-10-29-cosmetic-closeout/contracts/cos-u3.md`
   anchor: the `## Escalation` line holding `and restore mode 755 on the two test files.`
   replace: `and restore mode 755 on the two test files.` with `and restore mode 644 on the two test files.`, and insert directly under that line:
~~~
  amended 2026-10-29 (wrd-u3): this said restore mode 755; both test files are 100644.
~~~

7. command: `git add docs/harness-glossary.md docs/plans/2026-10-29-cosmetic-closeout/contracts/cos-u3.md && git commit -m "docs(wrd-u3): glossary dispatch message and multi-part stdout spec wording, amended line entry; cos-u3 test file modes"`
   expect: 0
   Run `git status --short` first. If a tracked file outside "Affected files" is modified, stop and report it.

## Do NOT touch
- `hooks/` (`hooks/scripts/writer-scope-gate.sh` above all: a separate hardening plan owns it), `bin/`, `.claude/`, `eval/`, `tests/`, `CONTEXT.md`
- every other entry of `docs/harness-glossary.md`, and every other sentence of the `dispatch message` and `multi-part stdout spec` entries
- every other contract under `docs/plans/` (cos-u1.md and tg-u2.md keep their amended lines as they are)

## Acceptance criteria
1. run: `bash -c 'g=hooks/scripts/writer-scope-gate.sh; h=docs/harness-glossary.md; e=$(grep -A1 -F "**dispatch message** (synonym" $h | tail -n1); echo "gate=$(grep -cFf <(printf "  case \x22\x24p\x22 in *\x27\x22\x27*|*\x27\x5c\x27*|*[[:cntrl:]]*) viol+=(\x22\x24p\x22); continue ;; esac\n") $g) dq=$(grep -cF "holds a double quote, backslash or control character is marked out" <<< "$e") added=$(grep -cF "can be added" <<< "$e") cites=$(grep -cF "the contract files the message cites and the" <<< "$e")"'`
   exit: 0
   stdout: `gate=1 dq=1 added=0 cites=1`
   mutation: skipping edits 1 and 2 prints `gate=1 dq=0 added=1 cites=0`. `gate=1` pins the gate line the double-quote claim comes from (`case "$p" in *'"'*|*'\'*|*[[:cntrl:]]*) ...`, a double quote, a backslash, a control character, no apostrophe); a gate whose case also caught the apostrophe prints `gate=0`, and then stop and report: the hardening plan has changed the gate and the wording needs a new decision.
2. run: `bash -c 'h=docs/harness-glossary.md; echo "gloss=$(grep -cF "fail stdout spec ends in an empty part" $h) script=$(grep -cF "fail stdout spec ends in an empty part" bin/review-precheck.sh) last=$(grep -cF "A spec whose last part is empty (nothing between its last two backticks) fails whatever the output, with " $h) mid=$(grep -cF "an empty part before the last stands for a blank line (wrd-u1). Any run of spaces" $h)"'`
   exit: 0
   stdout: `gloss=1 script=1 last=1 mid=1`
   mutation: skipping edit 3 prints `gloss=0 script=1 last=0 mid=0`; `script=1` ties the quoted message to the line wrd-u1 added to the script.
3. run: `bash -c 'out=$(bash tests/review-precheck.test.sh 2>&1); echo "$(printf "%s\n" "$out" | grep -cxF "OK   (m) an empty last part fails") $(printf "%s\n" "$out" | grep -cxF "OK   (m) an empty middle part is a blank line")"'`
   exit: 0
   stdout: `1 1`
   mutation: none in this unit (it pins the behaviour edit 3 describes: with `bin/review-precheck.sh` as at f566aeef the first count is `0`).
4. run: `bash -c 'h=docs/harness-glossary.md; n=$(grep -cxF "**amended line**:" $h); e=$(grep -A1 -xF "**amended line**:" $h | tail -n1); echo "n=$n prov=$(grep -cF "(plan 2026-10-29-wording-followups, unit wrd-u3) — an indented line beginning " <<< "$e") reads=$(grep -cF "reads only the criterion" <<< "$e") base=$(grep -cF "changed-since-baseline" <<< "$e") end=$(tail -c 2 $h | od -An -c | tr -d " ")"; node tests/context-glossary-links.test.js >/dev/null 2>&1 && echo links=ok'`
   exit: 0
   stdout: `n=1 prov=1 reads=1 base=1 end=.\n` then `links=ok`
   mutation: skipping edit 4 prints `n=0 prov=0 reads=0 base=0`; writing the link as `[[contract-file]]` makes the links test fail, and the command exits 1 (`criterion 4: fail exit=1 want=0`, spec-master ran it; item03-2-link-integrity-guard's recorded `vacuous` class is why this mutation was run).
5. run: `bash -c 'R="$PWD"; T=$(mktemp -d); cd "$T" && git init -q && mkdir -p docs/plans/p/contracts && printf "Unit: u1\n\n## Acceptance criteria\n1. run: \x60echo 1\x60\n   exit: 0\n   stdout: \x601\x60\n   amended 2026-10-29 (u2): stdout: \x602\x60\n   mutation: none\n" > docs/plans/p/contracts/u1.md && git add -A && git -c user.email=t@t -c user.name=t commit -qm c && bash "$R/bin/review-precheck.sh" u1 HEAD --contract docs/plans/p/contracts/u1.md --criterion 1 && printf "   amended 2026-10-30 (u3): x\n" >> docs/plans/p/contracts/u1.md && git -c user.email=t@t -c user.name=t commit -qam d && bash "$R/bin/review-precheck.sh" u1 HEAD~1 --contract docs/plans/p/contracts/u1.md | grep -cxF "contract: changed-since-baseline docs/plans/p/contracts/u1.md"'`
   exit: 0
   stdout: `criterion 1: pass exit=0` then `1`
   mutation: none in this unit (it pins edit 4's two claims about the script: an amended line holding `stdout:` text does not change criterion 1, and a contract changed after the baseline is a `changed-since-baseline` failure line). A `crit_items` whose stdout pattern were not anchored at the line start would read the amended line as the stdout spec and print `criterion 1: fail ...` (spec-master ran it). Each run uses its own `mktemp -d` repository.
6. run: `python3 -B -c "import glob, re; P = re.compile(r'\s+amended \d{4}-\d\d-\d\d \([A-Za-z0-9._-]+\): '); S = re.compile(r'\s+stdout: '); r = [(L[i - 1] if i else '') for f in sorted(glob.glob('docs/plans/**/*.md', recursive=True)) if not f.startswith('docs/plans/2026-10-29-wording-followups') for L in [open(f, encoding='utf-8').read().split(chr(10))] for i, l in enumerate(L) if P.match(l)]; print('amended=%d after-stdout=%d' % (len(r), sum(1 for p in r if S.match(p))))"`
   exit: 0
   stdout: `amended=7 after-stdout=4`
   mutation: skipping edits 5 and 6 prints `amended=4 after-stdout=4`. This pins edit 4's placement claim: the four amended lines under acceptance criteria (two in tg-u2.md, their copies in cos-u1.md) all follow a `stdout:` line, and every amended line has the `amended <date> (<unit>): ` form. This plan's own files are left out, because their edit texts quote amended lines.
7. run: `bash -c 'k=docs/plans/2026-10-29-cosmetic-closeout/contracts/cos-u3.md; t=$(grep -v "^  amended " $k); echo "s755=$(grep -cF "mode stays 755" <<< "$t") s644=$(grep -cF "mode stays 644)" <<< "$t") r755=$(grep -cF "restore mode 755" <<< "$t") r644=$(grep -cF "restore mode 644 on the two test files." <<< "$t") am=$(grep -cE "^  amended 2026-10-29 \(wrd-u3\): " $k) modes=$(for c in 1a987d32 ecc8104e HEAD; do git ls-tree $c tests/unit-scope-prose.test.sh tests/persona-prose-pins.test.sh | cut -c1-6; done | sort -u | tr -d "\n")"'`
   exit: 0
   stdout: `s755=0 s644=2 r755=0 r644=1 am=3 modes=100644`
   mutation: skipping edit 5 prints `s755=2 s644=0` and `am=1`; skipping edit 6 prints `r755=1 r644=0` and `am=2`. The counts leave the amended lines out, because they quote the old text. `modes=100644` pins the corrected value at the cos-u3 baseline, at cos-u3's commit and now.
8. run: `bash -c 'cs=$(git log --format="%H %s" | grep -E "^[0-9a-f]+ [a-z]+\(wrd-u3\): " | cut -d" " -f1); [ -n "$cs" ] || { echo no-commits; exit 1; }; o=$(for c in $cs; do git show --name-only --format= "$c"; done | sort -u | grep -vxE "docs/harness-glossary\.md|docs/plans/2026-10-29-cosmetic-closeout/contracts/cos-u3\.md" | wc -l | tr -d " "); echo "out=$o"'`
   exit: 0
   stdout: `out=0`
   mutation: committing an edit to `hooks/scripts/writer-scope-gate.sh` under a `(wrd-u3): ` subject prints `out=1`.
9. run: `bash -c 'ANTISLOP_VALIDATE_LANES=4 bash tests/validate.sh >/dev/null 2>&1; echo $?'` (Bash tool timeout 600000 ms; about 480 s)
   exit: 0
   stdout: `0`
   mutation: writing the edit-4 link as `[[contract-file]]` makes the `[[link]] integrity` lane fail inside validate.sh and stdout is `1`. Run this after the commit, with no other unit's edits uncommitted in the tree. Lane C4.1a is known to flake: if it is the only failure, re-run validate once and report both runs.

## Pre-resolved context
- tdd: no (wording only); criteria 1, 2, 4, 6 and 7 are red before the edits and green after, as their mutation lines state.
- Gate facts (read 2026-10-29 at f566aeef): `hooks/scripts/writer-scope-gate.sh:238` is `case "$p" in *'"'*|*'\'*|*[[:cntrl:]]*) viol+=("$p"); continue ;; esac`; `:175` appends the unit's own cited contract's entries and exclusions (`>>`); `:181`, the fallback for a message that lists nothing, overwrites both lists with another cited contract's (`>`), so the message's own exclusions are dropped there. Edit 1 removes the clause rather than describing `:181`, because the hardening plan may change that code and the entry already says the full scope rules are in the gate.
- Why the new entry is load-bearing: the form is in two contracts today (four lines) and this unit adds three more; a contract reader needs to know an indented free-text line under a criterion is not part of its stdout. It goes in `docs/harness-glossary.md`, not `CONTEXT.md`, because it is harness mechanics. `[[contract file]]` resolves to the `CONTEXT.md` entry; cross-file links pass `tests/context-glossary-links.test.js` (the `dispatch message` entry already uses one).
- In criterion 4, `end=.\n` is `od`'s rendering of a file that ends in `.` and one newline.
- commit-message: docs(wrd-u3): glossary dispatch message and multi-part stdout spec wording, amended line entry; cos-u3 test file modes
- Measured in a scratch clone of f566aeef with wrd-u1, wrd-u2 and these edits applied, committed: criteria 1 to 8 as stated; full validate exit 0, OK=3442 FAIL=0 WARN=2 in 476 s.
- Gate: if `writer-scope-gate.sh` blocks the stop naming a path listed above, it is a false positive. Report the block verbatim and wait; do not run the `git checkout` it suggests.

## Escalation
If any instruction cannot be followed exactly as written, STOP and report a spec gap; do not improvise. If a `before` or `replace` text is not found exactly once, stop and report the current text. If criterion 1 prints `gate=0`, stop and report (see its mutation line). If the Edit tool is unavailable (`exists but is not enabled in this context`), use a `python3 -B` heredoc that asserts the old text occurs exactly once before replacing it. Never edit a test or `tests/validate.sh` to make a criterion pass.
