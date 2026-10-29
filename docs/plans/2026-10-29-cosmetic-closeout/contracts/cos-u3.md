Unit: cos-u3

## Objective
Three wording fixes in the reviewer persona, with no behaviour change: (a) say "FAIL ground", the glossary's canonical term (`CONTEXT.md:1093-1101` lists "FAIL reason" under `_Avoid_`), instead of "FAIL reason" in `agents/reviewer.md` (4 uses) and its codex and cursor ports (3 each); (b) the Verdict bullet opens "your final message is ONLY the verdict block, followed by nothing but the advisory sections and the terminal STATUS line this bullet allows after it", where it said "ONLY the verdict"; (c) the On INSUFFICIENT-CONTEXT bullet says the `.blocked` marker carries no REFUTED defect: those live only in the returned message's `refutation` advisory section. Update the prose pins, bump the plugin version with a CHANGELOG line in the same commit (constitution P3), and regenerate the `.claude/` mirrors with `node bin/cli.js --update`.

## Retrieval
Fast path, no tracker issue. Spec: `docs/plans/2026-10-29-cosmetic-closeout.md` (Step 3, Context rows 1e, 2a, 2b, Open Question 3). This file is the contract of record. Dispatch after cos-u2 has PASSed, never in parallel with it (both regenerate the persona-selection config). It is the only unit of this plan that bumps the version.

## Affected files
- `agents/reviewer.md` (anchors: the four `FAIL reason` lines 54, 55, 64, 71; line matching `- **Verdict — terse, verdict-first, advisory sections (plural)**: your final`; line matching `  constraint/doc is missing, and where you looked for it. Write neither`)
- `adapters/codex/agents/reviewer.toml` (the three `FAIL reason` lines 49, 50, 59)
- `adapters/cursor/agents/reviewer.md` (the three `FAIL reason` lines 46, 47, 56)
- `tests/unit-scope-prose.test.sh` (anchors: line matching `  has "$f" "A changed file outside the unit's scope is also a FAIL reason"`; line matching `hasnot() { # <file> <phrase>`; mode stays 755)
- `tests/persona-prose-pins.test.sh` (anchor: line matching `  has "$f" 'Each "nothing else" or "nothing more" above bounds the verdict block itself: these advisory sections and the'`; mode stays 755)
- `.claude-plugin/plugin.json`, `package.json`, `CHANGELOG.md`
- generated only, by `node bin/cli.js --update`: `.claude/agents/*.md` (the reviewer body and every mirror's stamp line, 10 files), `.claude/persona-protocol.md`, `.claude/persona-protocol-slim.md`, `.claude/protocol-digest.md`, and the persona-selection config's `fileHashes` and `pluginVersion` (never named in a Bash command; staged only by the `git add -u -- .claude` form of edit 11)

These are the only paths in scope.

## Ordered edits
Edits 1 to 7 and 9 use the Edit tool, never a Bash heredoc. spec-master applied an equivalent of every edit to a scratch clone of ab174935, committed it, and ran every criterion and mutation below there; full validate exited 0 (OK=3442 FAIL=0).

1. file: `agents/reviewer.md`, `adapters/codex/agents/reviewer.toml`, `adapters/cursor/agents/reviewer.md`
   Replace every occurrence of `FAIL reason` with `FAIL ground` (Edit tool, `replace_all: true`). Expected occurrences before: 4, 3 and 3; after: 0 in each. The plural follows (`FAIL reasons.` becomes `FAIL grounds.`). Nothing else in those lines changes.

2. file: `agents/reviewer.md`
   anchor: line matching `- **Verdict — terse, verdict-first, advisory sections (plural)**: your final`
   indent: 0
   before:
~~~
- **Verdict — terse, verdict-first, advisory sections (plural)**: your final
  message is ONLY the verdict. PASS: one line naming which acceptance
~~~
   after:
~~~
- **Verdict — terse, verdict-first, advisory sections (plural)**: your final
  message is ONLY the verdict block, followed by nothing but the advisory
  sections and the terminal STATUS line this bullet allows after it. PASS: one line naming which acceptance
~~~

3. file: `agents/reviewer.md`
   anchor: line matching `  constraint/doc is missing, and where you looked for it. Write neither`
   indent: 2
   before:
~~~
  followed by specifics: which criterion could not be verified, what
  constraint/doc is missing, and where you looked for it. Write neither
~~~
   after:
~~~
  followed by specifics: which criterion could not be verified, what
  constraint/doc is missing, and where you looked for it. The marker carries
  no REFUTED defect: when the refutation pass led to this verdict, its REFUTED
  defects and your reasons live only in the returned message's `refutation`
  advisory section. Write neither
~~~

4. file: `tests/unit-scope-prose.test.sh`
   before:
~~~
  has "$f" "A changed file outside the unit's scope is also a FAIL reason"
  has "$f" 'out-of-scope-file defects are FAIL reasons'
~~~
   after:
~~~
  has "$f" "A changed file outside the unit's scope is also a FAIL ground"
  has "$f" 'out-of-scope-file defects are FAIL grounds'
~~~

5. file: `tests/unit-scope-prose.test.sh`
   anchor: line matching `hasnot() { # <file> <phrase>`
   insert-after the function's closing `}` line (the line right after the `if [ -f "$1" ] && ! tr -s` line):
~~~
# cos-u3: the reviewer and its ports say FAIL ground, the glossary's term (CONTEXT.md lists FAIL reason under _Avoid_)
for f in agents/reviewer.md .claude/agents/reviewer.md adapters/codex/agents/reviewer.toml adapters/cursor/agents/reviewer.md; do
  hasnot "$f" 'FAIL reason'
done
~~~

6. file: `tests/persona-prose-pins.test.sh`
   anchor: line matching `  has "$f" 'Each "nothing else" or "nothing more" above bounds the verdict block itself: these advisory sections and the'`
   insert-after:
~~~
  has "$f" 'your final message is ONLY the verdict block, followed by nothing but the advisory sections and the terminal STATUS line this bullet allows after it.'
  hasnot "$f" 'message is ONLY the verdict. PASS'
  has "$f" 'The marker carries no REFUTED defect: when the refutation pass led to this verdict, its REFUTED defects and your reasons live only in the returned message'"'"'s `refutation` advisory section.'
~~~
   (This loop runs over `agents/reviewer.md` and `.claude/agents/reviewer.md` only; the ports have no advisory sections, no STATUS line and no refutation pass, so items (b) and (c) do not apply to them.)

7. command: `bash -c 'bash tests/persona-prose-pins.test.sh | grep -c "^FAIL"'`
   expect: stdout `3`. Before edit 10 the reviewer mirror still has the old text, so its three new pins fail and the source's pass. This is the red step.

8. command: `perl -0pi -e 's/("version": "\d+\.\d+\.)(\d+)"/$1.($2+1)."\""/e' .claude-plugin/plugin.json package.json`
   expect: 0 (+1 on whatever is current at dispatch; it is 0.31.225 at ab174935, so 0.31.226)

9. file: `CHANGELOG.md`
   anchor: line matching `## [Unreleased]`
   indent: 0
   insert-after:
~~~

**The reviewer says FAIL ground, bounds its final message by the verdict block, and says what the `.blocked` marker leaves out (cos-u3, VERSION).** `agents/reviewer.md` and its codex and cursor ports now say "FAIL ground", the glossary's term, where they said "FAIL reason" (`CONTEXT.md` lists FAIL reason under `_Avoid_`). The reviewer's Verdict bullet now opens "your final message is ONLY the verdict block, followed by nothing but the advisory sections and the terminal STATUS line this bullet allows after it", where it said "ONLY the verdict". The On INSUFFICIENT-CONTEXT bullet now says the `.blocked` marker carries no REFUTED defect: those and the reasons live only in the returned message's `refutation` advisory section (behaviour unchanged). `tests/unit-scope-prose.test.sh` and `tests/persona-prose-pins.test.sh` pin the new text. Spec: `docs/plans/2026-10-29-cosmetic-closeout.md` (Step 3).
~~~
   Replace `VERSION` with the version edit 8 wrote.

10. command: `node bin/cli.js --update`
    expect: 0

11. command: `bash -c 'git status --porcelain --untracked-files=no -- .claude ":(exclude).claude/agent-memory" | wc -l | tr -d " "'`
    expect: 0, stdout `14` (10 agent mirrors, 3 protocol files, the config). If it prints anything else, stop and report the listed paths.

12. command: `git add agents/reviewer.md adapters/codex/agents/reviewer.toml adapters/cursor/agents/reviewer.md tests/unit-scope-prose.test.sh tests/persona-prose-pins.test.sh .claude-plugin/plugin.json package.json CHANGELOG.md && git add -u -- .claude ':(exclude).claude/agent-memory' && git commit -m "fix(cos-u3): reviewer says FAIL ground, ONLY the verdict block, and what the .blocked marker leaves out"`
    expect: 0
    Run `git status --short` first. If a tracked file outside "Affected files" is modified, stop and report it. Every later commit of this unit (a fix round) that touches `agents/` repeats edits 8 to 10 in that same commit, adds its own CHANGELOG line naming its own version, and keeps `(cos-u3): ` in its subject.

## Do NOT touch
- `templates/` (no shared protocol text changes; the `.blocked` marker definition in `templates/persona-protocol.md` stays), and `agents/` other than `agents/reviewer.md`
- `adapters/` other than the two reviewer ports; in the ports, every line except the `FAIL reason` ones (the ports keep "ONLY the verdict")
- `hooks/`, `bin/`, `scripts/`, `eval/`, every gate script, `tests/validate.sh`, `tests/cli-backfill.test.js`
- `CONTEXT.md`, `docs/harness-glossary.md` (cos-u5 owns them), `docs/adr/`, `docs/plans/`
- `.claude/` by hand (only edit 10 writes the mirrors); the reviewed-markers directory never

## Acceptance criteria
1. run: `bash -c 'out=$(bash tests/persona-prose-pins.test.sh); rc=$?; echo "fails=$(printf "%s\n" "$out" | grep -c "^FAIL") rc=$rc"'`
   exit: 0
   stdout: `fails=0 rc=0`
   mutation: skip edit 10 (`--update`); the reviewer mirror's three new pins fail: `fails=3 rc=1`. With the `agents/reviewer.md` of ab174935 and the new test, the source fails the same three: `fails=3 rc=1` (spec-master ran both).
2. run: `bash -c 'out=$(bash tests/unit-scope-prose.test.sh); rc=$?; echo "fails=$(printf "%s\n" "$out" | grep -c "^FAIL") rc=$rc"'`
   exit: 0
   stdout: `fails=0 rc=0`
   mutation: leave `adapters/cursor/agents/reviewer.md` as at ab174935; its two `has` pins and the new `hasnot` fail: `fails=3 rc=1`. Skipping edit 10 fails the same three for `.claude/agents/reviewer.md` (spec-master ran both).
3. run: `bash -c 'git grep -n "FAIL reason" -- agents adapters .claude/agents | wc -l | tr -d " "'`
   exit: 0
   stdout: `0`
   mutation: at ab174935 it prints `14` (4 + 3 + 3 + the mirror's 4).
4. run: `bash -c 'cs=$(git log --format="%H %s" | grep -E "^[0-9a-f]+ [a-z]+\(cos-u3\): " | cut -d" " -f1); [ -n "$cs" ] || { echo no-commits; exit 1; }; o=$(for c in $cs; do git show --name-only --format= "$c" -- . ":(exclude).claude"; done | sort -u | grep -vxE "agents/reviewer\.md|adapters/(codex/agents/reviewer\.toml|cursor/agents/reviewer\.md)|tests/(unit-scope-prose|persona-prose-pins)\.test\.sh|\.claude-plugin/plugin\.json|package\.json|CHANGELOG\.md" | wc -l | tr -d " "); x=$(for c in $cs; do git show --name-only --format= "$c" -- .claude; done | sort -u | grep -vxE "\.claude/agents/[a-z-]+\.md|\.claude/(persona-protocol|persona-protocol-slim|protocol-digest)\.md" | wc -l | tr -d " "); echo "out=$o dot-claude-other=$x"'`
   exit: 0
   stdout: `out=0 dot-claude-other=1`
   mutation: committing a `templates/persona-protocol.md` edit under a `(cos-u3): ` subject prints `out=1`; a hand edit to `.claude/bin/review-precheck.sh` prints `dot-claude-other=2`. The one other `.claude/` path is the persona-selection config.
5. run: `bash -c 'cs=$(git log --format="%H %s" | grep -E "^[0-9a-f]+ [a-z]+\(cos-u3\): " | cut -d" " -f1); [ -n "$cs" ] || { echo no-commits; exit 1; }; bad=0; t=no; for c in $cs; do o=$(bash hooks/scripts/version-stamp-check.sh "$c^..$c"); case "$o" in "version-stamp-check: ok touched: yes"*) t=yes ;; "version-stamp-check: ok "*) ;; *) bad=$((bad+1)) ;; esac; done; echo "bad=$bad touched=$t"'`
   exit: 0
   stdout: `bad=0 touched=yes`
   mutation: a fix-round commit `fix(cos-u3): …` that edits `agents/reviewer.md` without edit 8 prints `bad=1 touched=yes`. spec-master's scratch commit printed `version-stamp-check: ok touched: yes old: 0.31.225 new: 0.31.226 offenders: -`.
6. run: `bash -c 'node tests/cli-backfill.test.js >/dev/null 2>&1; echo $?'`
   exit: 0
   stdout: `0`
   mutation: skipping edit 10 leaves the config `fileHashes` and `pluginVersion` stale; stdout is `1`.
7. run: `bash -c 'git status --porcelain --untracked-files=no -- agents/reviewer.md adapters tests/unit-scope-prose.test.sh tests/persona-prose-pins.test.sh .claude-plugin/plugin.json package.json CHANGELOG.md .claude ":!.claude/agent-memory" | wc -l | tr -d " "'`
   exit: 0
   stdout: `0`
   mutation: leaving `.claude/agents/reviewer.md` unstaged after edit 10 prints `1`.
8. run: `bash -c 'ANTISLOP_VALIDATE_LANES=4 bash tests/validate.sh >/dev/null 2>&1; echo $?'` (Bash tool timeout 600000 ms; about 280 s)
   exit: 0
   stdout: `0`
   mutation: put `exit 1` as line 2 of `tests/unit-scope-prose.test.sh`; validate.sh reports it as FAIL and stdout is `1`. Run this after the commit, with no other unit's edits uncommitted in the tree (uncommitted, `tests/abtest-arms.test.sh` fails on its pruned-copy comparison).

## Pre-resolved context
- tdd: yes. Edits 4 to 6 before edits 1 to 3 make criteria 1 and 2 red; edit 7 is the recorded red step for the mirror.
- blast-radius: "FAIL reason" occurs in tracked files outside `docs/` only in the three reviewer copies, their `.claude/` mirror and `tests/unit-scope-prose.test.sh:16-17` (`git grep` at ab174935); `docs/specs/2026-07-14-speckit-ports.md:90` is a historical spec and stays. The new Verdict and INSUFFICIENT-CONTEXT sentences are pinned by `tests/persona-prose-pins.test.sh` only. The ports have no STATUS line (`grep -c "STATUS: "` is 0 in both) and no refutation pass (they always write `skipped=no-subagent`).
- commit-message: fix(cos-u3): reviewer says FAIL ground, ONLY the verdict block, and what the .blocked marker leaves out
- Measured in a scratch clone of ab174935: `--update` changed exactly the 14 generated `.claude/` paths (as rfp-u7b's 557b3af2 did); criteria 1-6 behave as stated; full validate exit 0.
- The `.blocked` sentence documents current behaviour (rfp-u7b.pass NOTE[code]); no marker format, gate or hook changes.
- Gate: if `writer-scope-gate.sh` blocks the stop naming a path listed above, it is a false positive. Report the block verbatim and wait; do not run the `git checkout` it suggests.

## Escalation
If any instruction cannot be followed exactly as written, STOP and report a spec gap; do not improvise. If edit 1 finds other than 4, 3 and 3 occurrences, or a `before` block is not found exactly once, stop and report the current text. If the Edit tool is unavailable (`exists but is not enabled in this context`), use a `python3` heredoc that asserts the old text occurs exactly once before replacing it, and restore mode 755 on the two test files. If edit 11 prints anything but `14`, stop and report the paths. Never edit `tests/validate.sh` or `tests/cli-backfill.test.js` to make a criterion pass.
