Unit: abt-u13g

## Objective
`eval/abtest/arms/common.sh` passes `--allowedTools Bash` (all of Bash) to both arms, drops the 16 find and sort deny rules, keeps the four OD-16 deny rules for the harness root (and each ABTEST_DENY_PATHS path) and puts `--disallowedTools` ahead of `--allowedTools`; `tests/abtest-arms.test.sh` pins that (81 rows); operator-decisions.md holds OD-19 (supersedes OD-17(a)-(c), verified vs unverified, the enlarged OD-16(d) residual), the pre-registration and the README carry the dated amendment and the re-run checklist. `eval/abtest/lib/stream.py` is untouched.

## Retrieval
GitHub issues: `gh issue view 624 --repo Storreslara/AntiSlop`. Siblings: `gh issue list --repo Storreslara/AntiSlop --label plan/antislop-vs-fable-evals`. Spec: `docs/plans/antislop-vs-fable-evals.md`; operator overrides (win on conflict): `docs/plans/antislop-vs-fable-evals/operator-decisions.md`.

## Affected files
- `eval/abtest/arms/common.sh` (anchor: line matching `    --allowedTools 'Bash(npm test)' 'Bash(npm run *)' 'Bash(git *)' \`)
- `tests/abtest-arms.test.sh` (anchor: line matching `# --- shared read-only allows (abt-u13d, OD-17): identical in both arms, nothing that writes, deny rules still win ---`)
- `docs/plans/antislop-vs-fable-evals/operator-decisions.md` (anchor: line matching `  reaches the stream the probe searches; it says nothing about the checks or fixtures directories.`)
- `docs/experiments/abtest-2026-10.md` (anchor: line matching `to reach the stream, and treats `not-found` as a probe of the common route, not a proof that the token is unreachable.`)
- `eval/abtest/README.md` (anchor: line matching `   control token that the prompt asks it to print, so a `not-found` shows that the probe can see a printed token.`)

## Ordered edits
1. command: `test -f eval/abtest/arms/common.sh && /usr/bin/grep -qF "--allowedTools 'Bash(npm test)'" eval/abtest/arms/common.sh && ! /usr/bin/grep -qF 'OD-19' eval/abtest/arms/common.sh && test -f tests/abtest-arms.test.sh && ! /usr/bin/grep -qF 'OD-19' docs/plans/antislop-vs-fable-evals/operator-decisions.md`
   expect: 0
2. file: `eval/abtest/arms/common.sh`
   anchor: line matching `    --allowedTools 'Bash(npm test)' 'Bash(npm run *)' 'Bash(git *)' \`
   indent: 0
   before:
~~~~
    --allowedTools 'Bash(npm test)' 'Bash(npm run *)' 'Bash(git *)' \
    'Bash(grep *)' 'Bash(ls *)' 'Bash(find *)' 'Bash(cat *)' 'Bash(head *)' 'Bash(tail *)' 'Bash(wc *)' \
    'Bash(sort *)' 'Bash(cut *)' 'Bash(echo *)' 'Bash(pwd *)' 'Bash(diff *)' 'Bash(stat *)' \
    'Bash(basename *)' 'Bash(dirname *)' \
~~~~
   after:
~~~~
    --allowedTools Bash \
~~~~
3. file: `eval/abtest/arms/common.sh`
   anchor: line matching `# One flag or value per line, so a test can compare the two arms.`
   indent: 0
   insert-after:
~~~~
# OD-19: both arms allow all of Bash (the single value Bash), so a correct run is not scored stalled-human for an
# ordinary dev command. The isolation lives in abtest_deny_flags, the pruned plugin copy, the per-run HOME and a work
# directory outside the checkout, not in this list. A real ask or denial is still stalled-human (lib/stream.py).
~~~~
4. file: `eval/abtest/arms/common.sh`
   anchor: line matching `  # The read-only allows (OD-17) must not reach a form that writes or runs another command. Deny rules are checked`
   indent: 0
   before:
~~~~
  # The read-only allows (OD-17) must not reach a form that writes or runs another command. Deny rules are checked
  # before allow rules, so these win, as do the harness-root rules below. Each is anchored to a space or to the start
  # of the arguments, because a rule matches the command text with * for any text: Bash(find *-ok*) would also deny
  # find . -name '*-ok*', and Bash(sort *-o*) would deny sort log-old.txt. The no-path forms cover find -delete.
  printf '%s\n' 'Bash(find * -exec*)' 'Bash(find * -ok*)' 'Bash(find * -delete*)' 'Bash(find * -fprint*)' 'Bash(find * -fls*)'
  printf '%s\n' 'Bash(find -exec*)' 'Bash(find -ok*)' 'Bash(find -delete*)' 'Bash(find -fprint*)' 'Bash(find -fls*)'
  printf '%s\n' 'Bash(sort -o*)' 'Bash(sort * -o*)' 'Bash(sort --output*)' 'Bash(sort * --output*)'
  printf '%s\n' 'Bash(sort --compress-program*)' 'Bash(sort * --compress-program*)'
~~~~
   after:
~~~~
  # OD-19: Bash is allowed whole, so the rules below are the only command-level protection. Deny rules are checked
  # before allow rules whatever the flag order, and abtest_run_claude still puts them first. The find and sort rules of
  # OD-17 are gone: with every command allowed they guard nothing a plain shell lacks, and each is a denial that would
  # stall a correct run.
~~~~
5. file: `eval/abtest/arms/common.sh`
   anchor: line matching `  ( cd "$wt" && env HOME="$home" GIT_CONFIG_GLOBAL="$home/.gitconfig" timeout "${TIMEOUT_MIN}m" "$ABTEST_CLAUDE" -p "$(cat "$pf")" "${flags[@]}" "${deny[@]}" "$@" ) > "$out" 2> "$err" || rc=$?`
   indent: 0
   before:
~~~~
  ( cd "$wt" && env HOME="$home" GIT_CONFIG_GLOBAL="$home/.gitconfig" timeout "${TIMEOUT_MIN}m" "$ABTEST_CLAUDE" -p "$(cat "$pf")" "${flags[@]}" "${deny[@]}" "$@" ) > "$out" 2> "$err" || rc=$?
~~~~
   after:
~~~~
  ( cd "$wt" && env HOME="$home" GIT_CONFIG_GLOBAL="$home/.gitconfig" timeout "${TIMEOUT_MIN}m" "$ABTEST_CLAUDE" -p "$(cat "$pf")" "${deny[@]}" "${flags[@]}" "$@" ) > "$out" 2> "$err" || rc=$?
~~~~
6. file: `tests/abtest-arms.test.sh`
   anchor: line matching `# --- shared read-only allows (abt-u13d, OD-17): identical in both arms, nothing that writes, deny rules still win ---`
   indent: 0
   before:
~~~~
# --- shared read-only allows (abt-u13d, OD-17): identical in both arms, nothing that writes, deny rules still win ---
allow_of() { awk '/^--allowedTools$/ {f = 1; next} /^--/ {f = 0} f' "$1"; }
allow_of "$T/argvA" > "$T/allowA"
allow_of "$T/argvB" > "$T/allowB"
check "both arms pass the same --allowedTools values" "$(cmp -s "$T/allowA" "$T/allowB" && echo same || echo differ)" "same"
check "the shared allowed tools number 18" "$(wc -l < "$T/allowA" | tr -d ' ')" "18"
check "the shared allowed tools keep the original three" "$(grep -cxE 'Bash\(npm test\)|Bash\(npm run \*\)|Bash\(git \*\)' "$T/allowA")" "3"
for c in grep ls find cat head tail wc sort cut echo pwd diff stat basename dirname; do
  check "the shared allowed tools hold Bash($c *) in both arms" "$(grep -cxF "Bash($c *)" "$T/allowA")|$(grep -cxF "Bash($c *)" "$T/allowB")" "1|1"
done
check "no allowed tool names a command that writes, deletes, fetches or runs another" "$(grep -cE '^Bash\((rm|mv|cp|chmod|chown|ln|tee|sed|awk|dd|curl|wget|ssh|scp|nc|xargs|tar|touch|mkdir|sh|bash|env|eval|sudo|node|python3?) ' "$T/allowA")" "0"
check "no deny rule rides the allow list" "$(grep -c "$REPO_PHYS" "$T/allowA")" "0"
check "the shared allowed tools do not hold uniq (uniq IN OUT writes OUT)" "$(grep -c '^Bash(uniq ' "$T/allowA")" "0"
deny_of() { awk '/^--disallowedTools$/ {f = 1; next} /^--/ {f = 0} f' "$1"; }
deny_of "$T/argvA" > "$T/denyA"
deny_of "$T/argvB" > "$T/denyB"
check "both arms pass the same --disallowedTools values" "$(cmp -s "$T/denyA" "$T/denyB" && echo same || echo differ)" "same"
check "the find and sort deny rules number 16" "$(grep -cE '^Bash\((find|sort) ' "$T/denyA")" "16"
check "no find or sort deny rule starts with an unanchored star-dash" "$(grep -cE '^Bash\((find|sort) \*-' "$T/denyA")" "0"
# A rule is modelled as a shell glob: * is any text, spaces and nothing included (OD-17(c); the matcher itself is not run).
hits() {
  local r n=0
  while IFS= read -r r; do
    case "$r" in
      'Bash(find '* | 'Bash(sort '*)
        r="${r#Bash(}"
        r="${r%)}"
        case "$1" in $r) n=$((n + 1)) ;; esac
        ;;
    esac
  done < "$T/denyA"
  echo "$n"
}
for cmd in "sort log-old.txt" "sort -u a.txt" "sort a.txt b.txt" "find . -name x-ok.txt" "find . -name '*-ok*'" "find . -name '*-exec*' -type f" "find src -type f" "find . -name x-delete.txt"; do
  check "no find or sort deny rule matches the read $cmd" "$(hits "$cmd")" "0"
done
for cmd in "find . -exec rm {} ;" "find -exec rm {} ;" "find . -name x -execdir rm {} ;" "find . -ok rm {} ;" "find -okdir rm {} ;" "find . -delete" "find -delete" "find . -fprint out.txt" "find . -fprintf out.txt %p" "find . -fls out.txt" "sort -o out.txt in.txt" "sort in.txt -o out.txt" "sort -oout.txt in.txt" "sort --output=out.txt in.txt" "sort in.txt --output out.txt" "sort --compress-program=sh in.txt"; do
  check "a find or sort deny rule matches the write form $cmd" "$([ "$(hits "$cmd")" -ge 1 ] && echo matched || echo missed)" "matched"
done
~~~~
   after:
~~~~
# --- all of Bash for both arms (abt-u13g, OD-19, supersedes the read-only list of OD-17): the isolation rules stay ---
allow_of() { awk '/^--allowedTools$/ {f = 1; next} /^--/ {f = 0} f' "$1"; }
allow_of "$T/argvA" > "$T/allowA"
allow_of "$T/argvB" > "$T/allowB"
check "both arms pass the same --allowedTools values" "$(cmp -s "$T/allowA" "$T/allowB" && echo same || echo differ)" "same"
check "the allowed tools are the single value Bash in both arms" "$(cat "$T/allowA")|$(cat "$T/allowB")" "Bash|Bash"
check "no allowed tool is limited by a command pattern" "$(grep -c '^Bash(' "$T/allowA")" "0"
check "no deny rule rides the allow list" "$(grep -c "$REPO_PHYS" "$T/allowA")" "0"
deny_of() { awk '/^--disallowedTools$/ {f = 1; next} /^--/ {f = 0} f' "$1"; }
deny_of "$T/argvA" > "$T/denyA"
deny_of "$T/argvB" > "$T/denyB"
check "both arms pass the same --disallowedTools values" "$(cmp -s "$T/denyA" "$T/denyB" && echo same || echo differ)" "same"
check "no find or sort deny rule remains (OD-19 removes the OD-17 write-form rules)" "$(grep -cE '^Bash\((find|sort) ' "$T/denyA")" "0"
check "the deny rules are the four rules for the harness root and nothing else" "$(grep -vxF -e "Read(/$REPO_PHYS)" -e "Read(/$REPO_PHYS/**)" -e "Edit(/$REPO_PHYS/**)" -e "Bash(*$REPO_PHYS*)" "$T/denyA" | wc -l | tr -d ' ')|$(wc -l < "$T/denyA" | tr -d ' ')" "0|4"
check "the deny rules come before the allow rules on the command line" "$(awk '/^--disallowedTools$/ {d = NR} /^--allowedTools$/ {a = NR} END {print ((d > 0 && a > 0 && d < a) ? "deny-first" : "allow-first")}' "$T/argvA")" "deny-first"
for a in A B; do
  check "arm $a keeps --permission-mode acceptEdits" "$(grep -A1 -e '--permission-mode' "$T/argv$a" | tail -1)" "acceptEdits"
  check "arm $a asks for no permission bypass" "$(grep -cE 'bypassPermissions|dangerously-skip-permissions' "$T/argv$a")" "0"
done
~~~~
7. file: `docs/plans/antislop-vs-fable-evals/operator-decisions.md`
   anchor: line matching `  reaches the stream the probe searches; it says nothing about the checks or fixtures directories.`
   indent: 0
   insert-after:
~~~~
- OD-19 (2026-10-18, all of Bash for both arms; binding operator decision, option 1, from the 2026-10-18 pilot;
  supersedes OD-17(a)-(c) where they conflict)
  Evidence (pilot 2026-10-18, eval/abtest/results.jsonl, runs under eval/abtest/.runs/): 5 of 10 rows were
  `stalled-human` (E3 B, E4 B, E5 A and B; E1 and E2 completed), each with `permission_denied` system records on
  ordinary dev commands. Decision reasons seen: `subcommandResults` (`node -e`, a heredoc `python3 - <<'EOF'`,
  `node --test ...; head`), "Quoted text in this command can't be checked before it runs", "A variable in this command
  can't be checked before it runs", "Contains brace with quote character (expansion obfuscation)" and "Parser skipped
  input between top-level statements". Widening a list of read-only commands cannot fix this class, and left as it
  was the stalls would measure the permission rules, not the arms.
  (a) The rule. `--allowedTools` is the single value `Bash` (every Bash command) in both arms, in place of the 18 rules
  of OD-17(a). Unchanged and still binding: `--permission-mode acceptEdits`, `--disallowedTools`, the per-run HOME, the
  work directory and config directory outside the checkout, the pruned plugin copy (OD-16(a)-(b)). The arms stay equal:
  one function builds the flags for both.
  (b) Removed. The 16 find and sort deny rules of OD-17(c) are gone. They kept a read-only list read-only; with every
  command allowed, `find -exec` and `sort -o` add nothing a plain shell lacks, and each is one more denial that would
  stall a correct run. `uniq` is no longer a question for the same reason.
  (c) Kept. `--disallowedTools` carries the four OD-16 rules for the harness root and for each path of
  ABTEST_DENY_PATHS (`Read(/<p>)`, `Read(/<p>/**)`, `Edit(/<p>/**)`, `Bash(*<p>*)`). The deny flags are now put ahead of
  the allow flags on the command line; the order is for the reader, not what makes them win.
  (d) Verified (Claude Code docs read 2026-10-18 by a claude-code-guide lookup, quoted, not run): `Bash(*)` is
  equivalent to the bare `Bash` and matches all Bash commands; rules are evaluated "deny, then ask, then allow" and "an
  allow rule can't carve an exception out of a deny rule"; deny rules apply when any subcommand matches, including one
  inside a command substitution, a subshell or a loop body; deny rules block in every permission mode; in
  `stream-json` a denial appears as a `permission_denied` system message. Not verified: that flag position is
  irrelevant (the docs order rules by type, not by flag position); that an allow of all Bash silences the parser safety
  checks quoted in the evidence (the docs do not mention heredocs, `$VAR`, "expansion obfuscation" or "Parser skipped
  input", so those checks may still force a denial in a headless run); that `Bash(*<root>*)` matches every spelling of
  the root. No test runs the real matcher.
  (e) Residual risk, enlarged (extends OD-16(d)). A deny rule matches the command text Claude writes, so a shell can
  now search the filesystem and read what it finds: `find / -name '*.tok' -exec cat {} +` names no harness path and is
  allowed. Through the shell an arm can also write outside the worktree and read the operator's real home (the per-run
  HOME only changes what `~` means). The OD-16 measures stay as defence in depth, and the canary probe with its control
  token (OD-18) is the check: it may now report `FOUND`, and that is the result it exists to give. A `FOUND` blocks
  everything (no pilot, no full pass) and needs a new operator decision on isolation; nothing here chooses it.
  (f) Stall detection in lib/stream.py is unchanged (OD-3, OD-13, OD-17(d)): a real ask or denial, for example a
  command a deny rule matches or a safety check the allow does not silence, is still `stalled-human`.
  (g) Whether the stalls stop is confirmed only by re-running. After this lands, the operator re-runs, in order,
  `run-matrix.sh --probe-isolation`, `run-matrix.sh --probe-canary` and `run-matrix.sh --pilot`. The 10 pilot rows of
  2026-10-18 were made by the previous harness; the change moves `harness_commit`, so they are superseded under OD-14
  and the pilot repeats them. If the pilot still stalls on the safety checks of (d), that is a new operator decision
  (for example a different permission mode); this decision does not make it.
~~~~
8. file: `docs/experiments/abtest-2026-10.md`
   anchor: line matching `to reach the stream, and treats `not-found` as a probe of the common route, not a proof that the token is unreachable.`
   indent: 0
   insert-after:
~~~~
Amendment 2026-10-18 (OD-19, before the first full run): both arms now allow all of Bash (`--allowedTools Bash`),
because the first pilot stalled 5 of 10 rows (E3 B, E4 B, E5 A and B) on permission denials for ordinary dev
commands (`node -e`, heredocs, quoted text, `$VAR`), which a longer read-only list cannot fix. This supersedes the
read-only allow list and the find and sort deny rules of OD-17. The isolation deny rules for the harness root, the
per-run HOME, the work directory outside the checkout and the pruned plugin copy stay. A shell can now search the
filesystem, so the residual risk of OD-16 is larger; the canary probe with its control token is the check and is
re-run, and a `FOUND` blocks everything. The 10 pilot rows of 2026-10-18 are superseded by this harness change (OD-14)
and will be repeated. Stall detection is unchanged: a real ask or denial is still `stalled-human`.
~~~~
9. file: `eval/abtest/README.md`
   anchor: line matching `   control token that the prompt asks it to print, so a `not-found` shows that the probe can see a printed token.`
   indent: 0
   insert-after:
~~~~
   Since OD-19 both arms may run any shell command, so `find /` is no longer refused for lying outside the work
   directory: a `not-found` now means the arm printed no token, and a `FOUND` is a real leak by an allowed route.
~~~~
10. file: `eval/abtest/README.md`
   anchor: line matching `   rows and moves them to `results.superseded.jsonl`, which the scorer never reads (OD-14).`
   indent: 0
   insert-after:
~~~~
   After the harness change OD-19 (all of Bash for both arms), run steps 1, 2 and 4 again, in that order: the first
   pilot (2026-10-18) stalled 5 of 10 rows on permission rules, and its 10 rows are superseded by the harness change
   (OD-14), so the pilot repeats them. A canary `FOUND` blocks everything: do not run the pilot or the full pass; report it.
~~~~
11. file: `eval/abtest/README.md`
   anchor: line matching `stream the probe searches, not that the checks or fixtures directories are out of reach (OD-18).`
   indent: 0
   insert-after:
~~~~
Since OD-19 both arms may run any shell command, so a shell can now search the filesystem for the checkout and read
what it finds; the deny rules refuse only a command that names the harness root. The canary probe with its control
token is the check, it must be re-run after OD-19, and a `FOUND` blocks everything.
~~~~
12. command: `git add docs/experiments/abtest-2026-10.md docs/plans/antislop-vs-fable-evals/operator-decisions.md eval/abtest/README.md eval/abtest/arms/common.sh tests/abtest-arms.test.sh && git commit -m "fix(abt-u13g): both arms allow all of Bash and keep the isolation deny rules, the find and sort deny rules go (OD-19) (#624)" -m "Co-Authored-By: Claude Sonnet 5.5 <noreply@anthropic.com>" -m "Claude-Session: https://claude.ai/code/session_01YK99TBRAMRzztoenFf2Y9S"`
   expect: 0

## Do NOT touch
- `eval/abtest/lib/stream.py` (the stalled-human rule: any AskUserQuestion, permission denial or escalation marker; spec 4.1, OD-3, OD-13 bind it and OD-19(f) keeps it)
- `eval/abtest/arms/arm-a.sh`, `eval/abtest/arms/arm-b.sh` (they only call abtest_run_claude; acceptEdits, the per-run HOME and the pruned plugin copy stay)
- `eval/abtest/run-matrix.sh`, `tests/abtest-probe.test.sh`, `tests/abtest-stream.test.sh`, `tests/fixtures/abtest/`, `tests/validate.sh` (the fake claude and the probes are unchanged)
- `docs/plans/antislop-vs-fable-evals.md`, `docs/harness-glossary.md`, `CHANGELOG.md` (the design stays as written; a scribe owns the `shared allowed tools` and `anchored deny rule` glossary close-out and the CHANGELOG entry)
- `agents/`, `templates/`, `.claude-plugin/plugin.json`, `package.json` (no persona change, no version bump)

## Acceptance criteria
1. run: `set -o pipefail; bash tests/abtest-arms.test.sh | tail -n 1`
   exit: 0
   stdout: `All abtest-arms checks passed.`
   mutation: skip edit 2; exit 2, stdout `abtest-arms: 79 passed, 2 failed`.
2. run: `bash tests/abtest-arms.test.sh | /usr/bin/grep -c '^ok'`
   exit: 0
   stdout: `81`
   mutation: skip edit 6; exit 0, stdout `83`.
3. run: `bash tests/abtest-arms.test.sh | /usr/bin/grep -c '^FAIL'`
   exit: 1
   stdout: `0`
   mutation: skip edit 5; exit 0, stdout `1`.
4. run: `/usr/bin/grep -cxF '    --allowedTools Bash \' eval/abtest/arms/common.sh`
   exit: 0
   stdout: `1`
   mutation: skip edit 2; exit 1, stdout `0`.
5. run: `/usr/bin/grep -cE 'Bash\((find|sort) ' eval/abtest/arms/common.sh`
   exit: 1
   stdout: `0`
   mutation: skip edit 4; exit 0, stdout `6`.
6. run: `/usr/bin/grep -cF '"${deny[@]}" "${flags[@]}" "$@"' eval/abtest/arms/common.sh`
   exit: 0
   stdout: `1`
   mutation: skip edit 5; exit 1, stdout `0`.
7. run: `bash -n eval/abtest/arms/common.sh`
   exit: 0
   stdout: `empty`
   mutation: append a stray `fi` line to eval/abtest/arms/common.sh; exit 2, stdout `empty`.
   proof: `git clone -q . scratch && printf 'fi\n' >> scratch/eval/abtest/arms/common.sh && bash -n scratch/eval/abtest/arms/common.sh`
8. run: `/usr/bin/grep -c '^- OD-19 (2026-10-18, all of Bash for both arms' docs/plans/antislop-vs-fable-evals/operator-decisions.md`
   exit: 0
   stdout: `1`
   mutation: skip edit 7; exit 1, stdout `0`.
9. run: `tr '\n' ' ' < docs/plans/antislop-vs-fable-evals/operator-decisions.md | tr -s ' ' | /usr/bin/grep -cF 'so a shell can now search the filesystem and read what it finds'`
   exit: 0
   stdout: `1`
   mutation: skip edit 7; exit 1, stdout `0`.
10. run: `/usr/bin/grep -c '^Amendment 2026-10-18 (OD-19, before the first full run)' docs/experiments/abtest-2026-10.md`
   exit: 0
   stdout: `1`
   mutation: skip edit 8; exit 1, stdout `0`.
11. run: `tr '\n' ' ' < docs/experiments/abtest-2026-10.md | tr -s ' ' | /usr/bin/grep -cF 'are superseded by this harness change (OD-14) and will be repeated'`
   exit: 0
   stdout: `1`
   mutation: skip edit 8; exit 1, stdout `0`.
12. run: `tr '\n' ' ' < eval/abtest/README.md | tr -s ' ' | /usr/bin/grep -cF 'is no longer refused for lying outside the work directory'`
   exit: 0
   stdout: `1`
   mutation: skip edit 9; exit 1, stdout `0`.
13. run: `tr '\n' ' ' < eval/abtest/README.md | tr -s ' ' | /usr/bin/grep -cF 'blocks everything: do not run the pilot or the full pass; report it'`
   exit: 0
   stdout: `1`
   mutation: skip edit 10; exit 1, stdout `0`.
14. run: `tr '\n' ' ' < eval/abtest/README.md | tr -s ' ' | /usr/bin/grep -cF 'a shell can now search the filesystem for the checkout and read what it finds'`
   exit: 0
   stdout: `1`
   mutation: skip edit 11; exit 1, stdout `0`.
15. run: `set -o pipefail; bash tests/abtest-stream.test.sh | tail -n 1`
   exit: 0
   stdout: `All abtest-stream checks passed.`
   mutation: delete `denials > 0 or ` from eval/abtest/lib/stream.py; the denied-capture rows FAIL and the suite exits with a non-zero code.
   proof: git clone -q . scratch, apply the edits, `sed -i 's/denials > 0 or //' scratch/eval/abtest/lib/stream.py`, run `bash tests/abtest-stream.test.sh` in scratch: exit 1, `abtest-stream: 241 passed, 1 failed`
16. run: `/usr/bin/grep -cF 'T="$(mktemp -d)" && [ -d "${T:-}" ]' tests/abtest-arms.test.sh`
   exit: 0
   stdout: `1`
   mutation: replace the guarded mktemp line with `T=$(mktemp -d)`; exit 1, stdout `0`.
   proof: git clone -q . scratch, apply the edits, replace the guarded mktemp line in scratch/tests/abtest-arms.test.sh with `T=$(mktemp -d)`, rerun the run: command there
17. run: `/usr/bin/grep -cE '^[^#"]*(^|[ ;|&(])claude( |$)' tests/abtest-arms.test.sh`
   exit: 1
   stdout: `0`
   mutation: append the line `claude -p hi` to tests/abtest-arms.test.sh; exit 0, stdout `1`.
   proof: git clone -q . scratch, apply the edits, append `claude -p hi` to scratch/tests/abtest-arms.test.sh, rerun the run: command there
18. run: `L=$(git log --format='%H %s' | grep -E '^[0-9a-f]+ [a-z]+\(abt-u13g\): ' | cut -d' ' -f1); test -n "$L" || { echo no-unit-commit; exit 3; }; c=$(echo "$L" | sed -n 1p); git diff --name-only "$c~1..$c" | LC_ALL=C sort | paste -sd" "`
   exit: 0
   stdout: `docs/experiments/abtest-2026-10.md docs/plans/antislop-vs-fable-evals/operator-decisions.md eval/abtest/README.md eval/abtest/arms/common.sh tests/abtest-arms.test.sh`
   mutation: skip edit 12 (the commit); no unit commit exists and the run prints no-unit-commit with exit 3.
19. run: `L=$(git log --format='%H %s' | grep -E '^[0-9a-f]+ [a-z]+\(abt-u13g\): ' | cut -d' ' -f1); test -n "$L" || { echo no-unit-commit; exit 3; }; git log -1 --format=%B "$(echo "$L" | sed -n 1p)" | grep -c "^Co-Authored-By: Claude .* <noreply@anthropic.com>$"`
   exit: 0
   stdout: `1`
   mutation: skip edit 12; no unit commit exists and the exit is 3.
20. run: `L=$(git log --format='%H %s' | grep -E '^[0-9a-f]+ [a-z]+\(abt-u13g\): ' | cut -d' ' -f1); test -n "$L" || { echo no-unit-commit; exit 3; }; E=$(echo "$L" | head -1); git log --format=%s "$E..HEAD" -- docs/experiments/abtest-2026-10.md docs/plans/antislop-vs-fable-evals/operator-decisions.md eval/abtest/README.md eval/abtest/arms/common.sh tests/abtest-arms.test.sh | grep -vcE "^[a-z]+\(abt-u13g\): "`
   exit: 1
   stdout: `0`
   mutation: skip edit 12; no unit commit exists and the exit is 3.

## Pre-resolved context
tdd: yes tests/abtest-arms.test.sh (criteria 1 to 3 are red-then-green: at HEAD the allow list holds 18 patterns and the new rows do not exist; 117 rows become 81)
blast-radius: eval/abtest/arms/common.sh:16 eval/abtest/arms/common.sh:45 eval/abtest/arms/common.sh:146 eval/abtest/arms/arm-a.sh:29 eval/abtest/arms/arm-b.sh:87 tests/abtest-arms.test.sh:122 eval/abtest/lib/stream.py:152 (grep-derived; abtest_common_flags and abtest_deny_flags are called only from abtest_run_claude, which only arm-a.sh and arm-b.sh call; eval/harness/run.sh has its own flags and is a different harness)
gate-refusal: if any hook refuses a Bash command, STOP and report the refusal text; never route around it (no scratch-file, renamed-path or reworded-command workaround). Write every file with the Write or Edit tool, not a Bash heredoc.
payload-indent: every fenced payload in this contract starts at column 0 of the contract file, keeps its own leading spaces, and states indent: 0; strip nothing; empty payload lines stay empty.
decision: no SPEC-GAP. Operator ruling option 1 (2026-10-18, this session): all of Bash for both arms with the OD-16 isolation kept; recorded as OD-19, which supersedes OD-17's read-only allow list and find/sort deny rules where they conflict. Mechanism: the bare value `Bash` (documented as equal to `Bash(*)`); the deny flags go ahead of the allow flags in abtest_run_claude. The find and sort deny rules are removed because with every command allowed they guard nothing a plain shell lacks and each is a stall; the four root rules are kept. Stall detection (lib/stream.py line 152, OD-3, OD-13) is untouched. acceptEdits, --disallowedTools, the per-run HOME, the work and config directories outside the checkout and the pruned plugin copy are not undone: the arms tests keep their rows and add acceptEdits and no-bypass rows.
verified: from the Claude Code docs (read 2026-10-18 by lookup): Bash(*) equals Bash; rules evaluate deny, then ask, then allow; an allow cannot carve an exception out of a deny; deny rules apply to subcommands inside substitutions, subshells and loops. unverified: flag position is irrelevant (an inference); that an allow of all Bash silences the parser safety checks seen in the pilot (the docs are silent on heredocs, $VAR, expansion obfuscation, parser-skipped input); that Bash(*<root>*) matches every spelling of the root. The operator's rerun of the probes and the pilot is the check; no test spends usage.
operator-checklist: after landing, the operator re-runs `run-matrix.sh --probe-isolation`, `--probe-canary` and `--pilot` in that order; a canary FOUND blocks everything. The 10 pilot rows are superseded (OD-14) and repeat.
green-at-HEAD: criterion 15 to 17 already pass before the edits (regression guards, criterion 15 pins that lib/stream.py behaviour is untouched); criterion 2 is the red count (117 at HEAD); criteria 1, 3 to 14 and 18 to 20 fail at HEAD.
not-stamped: no agents/*.md or templates/ file is touched, so there is no version bump and no CHANGELOG entry; a scribe close-out owns the CHANGELOG entry and the `shared allowed tools` and `anchored deny rule` glossary entries (both now describe the OD-17 rules).
commit-message: fix(abt-u13g): both arms allow all of Bash and keep the isolation deny rules, the find and sort deny rules go (OD-19) (#624)
Co-Authored-By: Claude Sonnet 5.5 <noreply@anthropic.com>
Claude-Session: https://claude.ai/code/session_01YK99TBRAMRzztoenFf2Y9S
diagnosis: none
review-packet:
~~~
unit: abt-u13g (#624)
changed files: <FILL: changed files>
commit: <FILL: commit SHA>
criterion 1: <FILL: exit and stdout>
criterion 2: <FILL: exit and stdout>
criterion 3: <FILL: exit and stdout>
criterion 4: <FILL: exit and stdout>
criterion 5: <FILL: exit and stdout>
criterion 6: <FILL: exit and stdout>
criterion 7: <FILL: exit and stdout>
criterion 8: <FILL: exit and stdout>
criterion 9: <FILL: exit and stdout>
criterion 10: <FILL: exit and stdout>
criterion 11: <FILL: exit and stdout>
criterion 12: <FILL: exit and stdout>
criterion 13: <FILL: exit and stdout>
criterion 14: <FILL: exit and stdout>
criterion 15: <FILL: exit and stdout>
criterion 16: <FILL: exit and stdout>
criterion 17: <FILL: exit and stdout>
criterion 18: <FILL: exit and stdout>
criterion 19: <FILL: exit and stdout>
criterion 20: <FILL: exit and stdout>
~~~

## Escalation
If any instruction cannot be followed exactly as written, STOP and report a spec gap; do not improvise.
