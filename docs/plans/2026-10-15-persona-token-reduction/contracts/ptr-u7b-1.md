Unit: ptr-u7b-1

## Objective
`hooks/scripts/lib/benign-command.sh` treats a segment that is exactly `cd <plain word>` as benign (F1) and allowlists `du`, `cut`, `tr`, `nl`, `sort`, `uniq` and `jq` (F3), F2 unchanged; the 16 positive and 20 negative frozen commands pass in `tests/benign-command-families.test.sh`; the `[U7c]` cd control and pin OB-10 become `allowed` pins with new refused controls (two touch forms, OB-15); the `.claude` mirror is refreshed; no version bump.

## Retrieval
GitHub issues: `gh issue view 562 --repo Storreslara/AntiSlop`. Siblings: `gh issue list --repo Storreslara/AntiSlop --label plan/persona-token-reduction`. Spec: `docs/plans/2026-10-15-persona-token-reduction.md`, "Step U7b-1" and "Ruling H-U7B3".

## Affected files
- `hooks/scripts/lib/benign-command.sh` (anchor: line matching `echo|printf) return 0 ;;`, line matching `# $1 is one REAL (un-skeletonized) segment: the allowlist reads real text, since`)
- `tests/fixtures/gate-fp-corpus/positive.jsonl`, `tests/fixtures/gate-fp-corpus/negative.jsonl`, `tests/benign-command-families.test.sh` (anchor: new file)
- `tests/validate.sh` (anchor: line matching `echo "FAIL tests/contract-files.test.sh"`)
- `tests/harness-integrity-gate.test.sh` (anchor: line matching `pass "[U7c] harness-integrity-gate refuses the cd-prefixed compound form"`)
- `tests/human-decision-gate.test.sh` (anchor: line matching `(OB-1..OB-14)`)
- `CHANGELOG.md` (anchor: line matching `## [Unreleased]`)
- `.claude/hooks/scripts/lib/benign-command.sh`, `.claude/persona-config.json` (rewritten by `node bin/cli.js --update`, never hand-edited; anchor: line matching `program_allowed() {` and `"fileHashes": {`)

## Ordered edits
1. command: `test ! -e tests/benign-command-families.test.sh && test ! -e tests/fixtures/gate-fp-corpus/positive.jsonl && test ! -e tests/fixtures/gate-fp-corpus/negative.jsonl && test -z "$(git status --porcelain --untracked-files=no -- . ':!.claude/agent-memory')"`
   expect: 0
2. file: `hooks/scripts/lib/benign-command.sh`
   anchor: line matching `echo|printf) return 0 ;;`
   indent: 3
   before:
   ~~~~
   echo|printf) return 0 ;;
   ~~~~
   after:
   ~~~~
   echo|printf) return 0 ;;
       # F1/F3 (ptr-u7b-1): du/cut/tr/nl take no option rule; cd, sort, uniq and jq
       # go through the allowlist helpers defined below.
       du|cut|tr|nl) return 0 ;;
       cd) cd_segment_allowed "$1"; return $? ;;
       sort) sort_segment_allowed "$1"; return $? ;;
       uniq) uniq_segment_allowed "$1"; return $? ;;
       jq) jq_segment_allowed "$1"; return $? ;;
   ~~~~
3. file: `hooks/scripts/lib/benign-command.sh`
   anchor: line matching `# $1 is one REAL (un-skeletonized) segment: the allowlist reads real text, since`
   indent: 3
   before:
   ~~~~
   # $1 is one REAL (un-skeletonized) segment: the allowlist reads real text, since
   ~~~~
   after:
   ~~~~
   # Allowlist helpers for the families F1 and F3 (ptr-u7b-1): each takes the whole
   # REAL segment and returns 0 only if every word is recognised. A quote, `$`, brace
   # or glob can spell an option word a word scan never sees, so sort/uniq refuse them.
   segment_is_plain() {
     case "$1" in
       *\'*|*\"*|*'$'*|*'{'*|*'}'*|*'*'*|*'?'*|*'['*|*']'*) return 1 ;;
     esac
     return 0
   }

   # sort: listed options only, so -o, --output, -T, --compress-program and every
   # abbreviation of them are not benign.
   sort_segment_allowed() {
     local -a w
     local i=1 x key='^[0-9]+(\.[0-9]+)?[bdfghiMnRrV]*(,[0-9]+(\.[0-9]+)?[bdfghiMnRrV]*)?$'
     segment_is_plain "$1" || return 1
     read -ra w <<< "$1"
     while [ "$i" -lt "${#w[@]}" ]; do
       x="${w[i]}"
       i=$((i + 1))
       case "$x" in
         -k) [[ "${w[i]:-}" =~ $key ]] || return 1; i=$((i + 1)) ;;
         -k*) [[ "${x#-k}" =~ $key ]] || return 1 ;;
         --key=*) [[ "${x#--key=}" =~ $key ]] || return 1 ;;
         -t) [[ "${w[i]:-}" =~ ^.$ ]] || return 1; i=$((i + 1)) ;;
         -t?|--field-separator=?) ;;
         --reverse|--unique|--numeric-sort|--general-numeric-sort|--human-numeric-sort) ;;
         --version-sort|--month-sort|--random-sort|--ignore-case|--ignore-leading-blanks) ;;
         --dictionary-order|--ignore-nonprinting|--stable|--check|--zero-terminated) ;;
         --*) return 1 ;;
         -?*) [[ "$x" =~ ^-[bdfghiMnRrsuVcCz]+$ ]] || return 1 ;;
       esac
     done
     return 0
   }

   # uniq: listed options only, at most one operand (a second is the output file) and
   # no option word after it (POSIXLY_CORRECT makes it an operand).
   uniq_segment_allowed() {
     local -a w
     local i=1 x ops=0 dig='^[0-9]+$' rd='^[0-9]*>(&[0-9]+|/dev/null)$'
     segment_is_plain "$1" || return 1
     read -ra w <<< "$1"
     while [ "$i" -lt "${#w[@]}" ]; do
       x="${w[i]}"
       i=$((i + 1))
       [[ "$x" =~ $rd ]] && continue
       [ "$ops" = 0 ] || case "$x" in -?*) return 1 ;; esac
       case "$x" in
         -f|-s|-w) [[ "${w[i]:-}" =~ $dig ]] || return 1; i=$((i + 1)) ;;
         -[fsw][0-9]*) [[ "${x:2}" =~ $dig ]] || return 1 ;;
         --count|--repeated|--unique|--ignore-case|--zero-terminated) ;;
         --skip-fields=*|--skip-chars=*|--check-chars=*) [[ "${x#*=}" =~ $dig ]] || return 1 ;;
         --*) return 1 ;;
         -?*) [[ "$x" =~ ^-[cdDiuz]+$ ]] || return 1 ;;
         *) ops=$((ops + 1)) ;;
       esac
     done
     [ "$ops" -le 1 ]
   }

   # $1 is one REAL (un-skeletonized) segment: the allowlist reads real text, since
   ~~~~
4. file: `hooks/scripts/lib/benign-command.sh`
   anchor: line matching `# $1 is one REAL (un-skeletonized) segment: the allowlist reads real text, since`
   indent: 3
   before:
   ~~~~
   # $1 is one REAL (un-skeletonized) segment: the allowlist reads real text, since
   ~~~~
   after:
   ~~~~
   # jq: -f / --from-file takes the next word as a program file; benign only for a literal path.
   jq_segment_allowed() {
     local -a w
     local i=1 x lit='^[-[:alnum:]_./]+$'
     read -ra w <<< "$1"
     while [ "$i" -lt "${#w[@]}" ]; do
       x="${w[i]}"
       i=$((i + 1))
       case "$x" in
         -f|--from-file|-[!-]*f) [[ "${w[i]:-}" =~ $lit ]] || return 1; i=$((i + 1)) ;;
       esac
     done
     return 0
   }

   # F1: a segment that is exactly `cd <plain word>` is benign in any position (cd
   # writes nothing and runs nothing; every other segment is checked on its own).
   cd_segment_allowed() {
     local -a w
     read -ra w <<< "$1"
     [ "${#w[@]}" = 2 ] || return 1
     [[ "${w[1]}" =~ ^[-[:alnum:]_./~+@%,:=]+$ ]]
   }

   # $1 is one REAL (un-skeletonized) segment: the allowlist reads real text, since
   ~~~~
5. file: `tests/fixtures/gate-fp-corpus/positive.jsonl`
   anchor: new file (Write tool, exact content)
   indent: 3
   insert-after:
   ~~~~
   {"family":"F1","cmd":"cd /tmp && ls"}
   {"family":"F1","cmd":"cd docs; wc -l README.md"}
   {"family":"F1","cmd":"cd hooks && grep -c x f 2>/dev/null"}
   {"family":"F2","cmd":"ls 2>&1 | head -5"}
   {"family":"F2","cmd":"grep -c x f 2>/dev/null"}
   {"family":"F2","cmd":"wc -l f >/dev/null"}
   {"family":"F3","cmd":"du -sh ."}
   {"family":"F3","cmd":"sort f"}
   {"family":"F3","cmd":"grep x f | sort | uniq -c"}
   {"family":"F3","cmd":"cut -d: -f1 f"}
   {"family":"F3","cmd":"tr a b < f"}
   {"family":"F3","cmd":"nl f"}
   {"family":"F3","cmd":"jq .a f.json"}
   {"family":"F3","cmd":"jq -r .a f.json 2>/dev/null"}
   {"family":"F3","cmd":"sort -u f | uniq"}
   {"family":"F3","cmd":"uniq -c f"}
   ~~~~
6. file: `tests/fixtures/gate-fp-corpus/negative.jsonl`
   anchor: new file (Write tool, exact content)
   indent: 3
   insert-after:
   ~~~~
   {"cmd":"sort -o x y"}
   {"cmd":"sort --output=x y"}
   {"cmd":"uniq a b"}
   {"cmd":"jq . f > g"}
   {"cmd":"cd x && rm -f y"}
   {"cmd":"cd $(pwd) && ls"}
   {"cmd":"ls 2>x"}
   {"cmd":"cut -f1 f >> g"}
   {"cmd":"du -sh . ; touch z"}
   {"cmd":"tr a b < f > g"}
   {"cmd":"sort --ou=x y"}
   {"cmd":"sort --compress-program=sh y"}
   {"cmd":"sort -T d y"}
   {"cmd":"sort -uo x y"}
   {"cmd":"sort '-o' x y"}
   {"cmd":"sort -{o,x} y"}
   {"cmd":"sort -[o] x y"}
   {"cmd":"sort $O x y"}
   {"cmd":"uniq -- -c b"}
   {"cmd":"uniq f -c"}
   ~~~~
7. file: `tests/benign-command-families.test.sh`
   anchor: new file (Write tool, exact content)
   indent: 3
   insert-after:
   ~~~~
   #!/usr/bin/env bash
   # Frozen-corpus test for the read-only families F1 and F3 of the benign-command lib
   # (ptr-u7b-1). It sources the lib named by $BENIGN_LIB (default
   # hooks/scripts/lib/benign-command.sh) and calls command_is_provably_benign
   # directly for every line of the two corpus files, passing the command as an
   # argument and never through eval. One line per case: ok|FAIL <positive|negative>
   # <family|-> <cmd>. Exit 0 only when there is no FAIL line.
   cd "$(dirname "$0")/.." || exit 1
   lib="${BENIGN_LIB:-hooks/scripts/lib/benign-command.sh}"
   # shellcheck source=/dev/null
   . "$lib" || exit 1
   dir=tests/fixtures/gate-fp-corpus
   fail=0

   while IFS= read -r line; do
     [ -n "$line" ] || continue
     fam="$(jq -r '.family' <<< "$line")"
     cmd="$(jq -r '.cmd' <<< "$line")"
     if command_is_provably_benign "$cmd"; then
       echo "ok positive $fam $cmd"
     else
       echo "FAIL positive $fam $cmd"
       fail=1
     fi
   done < "$dir/positive.jsonl"

   while IFS= read -r line; do
     [ -n "$line" ] || continue
     cmd="$(jq -r '.cmd' <<< "$line")"
     if command_is_provably_benign "$cmd"; then
       echo "FAIL negative - $cmd"
       fail=1
     else
       echo "ok negative - $cmd"
     fi
   done < "$dir/negative.jsonl"

   exit "$fail"
   ~~~~
8. file: `tests/validate.sh`
   anchor: line matching `echo "FAIL tests/contract-files.test.sh"`
   indent: 3
   before:
   ~~~~
     echo "FAIL tests/contract-files.test.sh"
     fail=1
   fi
   ~~~~
   after:
   ~~~~
     echo "FAIL tests/contract-files.test.sh"
     fail=1
   fi

   echo
   echo "== tests/benign-command-families.test.sh: frozen corpora for the read-only families F1 and F3 (Bash, ptr-u7b-1) =="
   if bash tests/benign-command-families.test.sh > /dev/null; then
     echo "OK   tests/benign-command-families.test.sh"
   else
     echo "FAIL tests/benign-command-families.test.sh"
     fail=1
   fi
   ~~~~
9. file: `tests/harness-integrity-gate.test.sh`
   anchor: line matching `pass "[U7c] harness-integrity-gate refuses the cd-prefixed compound form"`
   indent: 3
   before:
   ~~~~
   # Negative control: the same read behind a cd prefix is a compound command, which
     # the integrity gate refuses. It proves the gate is armed in this fixture.
     u7c_got="$(u7c_rc hooks/scripts/harness-integrity-gate.sh "cd /tmp; $u7c_cmd")"
     if [ "$u7c_got" = 2 ]; then
       pass "[U7c] harness-integrity-gate refuses the cd-prefixed compound form"
     else
       bad "[U7c] harness-integrity-gate exit $u7c_got on the cd-prefixed form, expected 2"
     fi
   ~~~~
   after:
   ~~~~
   # Behind a cd prefix the lone jq read is benign since F1 and F3 (U7b-1). The two
     # touch forms stay refused: touch is in no allowlist, and a cd prefix launders no
     # other segment.
     u7c_expect() {  # $1 expected exit, $2 prefix, $3 pass label
       u7c_got="$(u7c_rc hooks/scripts/harness-integrity-gate.sh "$2$u7c_cmd")"
       if [ "$u7c_got" = "$1" ]; then
         pass "[U7c] harness-integrity-gate $3"
       else
         bad "[U7c] harness-integrity-gate exit $u7c_got behind '$2', expected $1"
       fi
     }
     u7c_expect 0 "cd /tmp; " "allows the cd-prefixed form (F1+F3, U7b-1)"
     u7c_expect 2 "touch /tmp/u7c-armed; " "refuses the touch-prefixed compound form"
     u7c_expect 2 "cd /tmp; touch u7c-armed; " "refuses the cd-then-touch compound form"
   ~~~~
10. file: `tests/human-decision-gate.test.sh`
   anchor: line matching `(OB-1..OB-14)`
   indent: 3
   before:
   ~~~~
   -- accepted over-blocks from the esc-left-3 and qp-1 differential sweeps (OB-1..OB-14) --
   ~~~~
   after:
   ~~~~
   -- accepted over-blocks from the esc-left-3 and qp-1 differential sweeps (OB-1..OB-15) --
   ~~~~
11. file: `tests/human-decision-gate.test.sh`
   anchor: line matching `a later narrowing that frees one shows up here.`
   indent: 3
   before:
   ~~~~
   # `blocked`, so a later narrowing that frees one shows up here.
   ~~~~
   after:
   ~~~~
   # `blocked`, so a later narrowing that frees one shows up here.
   # Exception: OB-10 is pinned `allowed` since U7b-1 (F3 makes its cut segment
   # provably benign), and OB-15 is derived from it (cut replaced by tee), not
   # from the sweep corpus.
   ~~~~
12. file: `tests/human-decision-gate.test.sh`
   anchor: line matching `the cut segment is not provably benign`
   indent: 3
   before:
   ~~~~
   "unquoted adapters/*/rules/* can name both tokens; the cut segment is not provably benign"
   ~~~~
   after:
   ~~~~
   "freed by F3 (U7b-1): the cut segment is now provably benign"
   ~~~~
13. file: `tests/human-decision-gate.test.sh`
   anchor: line matching `its scratch path a/h*/D* can name both tokens`
   indent: 3
   before:
   ~~~~
   "a sh -c / bash -c payload is scanned live; its scratch path a/h*/D* can name both tokens"
   ~~~~
   after:
   ~~~~
   "a sh -c / bash -c payload is scanned live; its scratch path a/h*/D* can name both tokens"
     "OB-10's shape with cut replaced by tee: unquoted adapters/*/rules/* can name both tokens; the tee segment is not provably benign"
   ~~~~
14. file: `tests/human-decision-gate.test.sh`
   anchor: line matching `for ob_i in "${!ob_cmds[@]}"; do`
   indent: 3
   before:
   ~~~~
   OBEOF
   for ob_i in "${!ob_cmds[@]}"; do
   ~~~~
   after:
   ~~~~
   "grep -n 'both modes\\|reviewer-join' templates/persona-protocol.md README.md agents/*.md adapters/*/agents/* adapters/*/rules/* adapters/codex/agents-md-fragment.md CONTEXT.md docs/adr/0038* commands/gate.md 2>/dev/null | tee /tmp/ob15.out"
   OBEOF
   for ob_i in "${!ob_cmds[@]}"; do
   ~~~~
15. file: `tests/human-decision-gate.test.sh`
   anchor: line matching `check "OB-$((ob_i + 1)) ${ob_reasons[ob_i]}" blocked`
   indent: 3
   before:
   ~~~~
   check "OB-$((ob_i + 1)) ${ob_reasons[ob_i]}" blocked
   ~~~~
   after:
   ~~~~
   ob_verdict=blocked
     [ "$ob_i" = 9 ] && ob_verdict=allowed
     check "OB-$((ob_i + 1)) ${ob_reasons[ob_i]}" "$ob_verdict"
   ~~~~
16. file: `CHANGELOG.md`
   anchor: line matching `## [Unreleased]`
   indent: 3
   before:
   ~~~~
   ## [Unreleased]
   ~~~~
   after:
   ~~~~
   ## [Unreleased]

   **Read-only families F1 and F3 in the benign-command lib (ptr-u7b-1).** `hooks/scripts/lib/benign-command.sh` now treats a segment that is exactly `cd <plain word>` as benign (F1, any position) and adds `du`, `cut`, `tr`, `nl` plus allowlist helpers for `sort` (listed options only, so `-o`, `--output`, `-T`, `--compress-program` and their abbreviations stay refused), `uniq` and `jq`; F2 is unchanged. The lib is Claude-only, so there is no adapter copy. `tests/benign-command-families.test.sh` (registered in `tests/validate.sh`) runs 16 positive and 20 negative frozen commands from `tests/fixtures/gate-fp-corpus/`. Two pins follow the lib: the `[U7c]` cd-prefixed control in `tests/harness-integrity-gate.test.sh` becomes an `allowed` pin beside two still-refused touch forms, and OB-10 in `tests/human-decision-gate.test.sh` becomes an `allowed` pin beside new blocked pin OB-15. No version bump.
   ~~~~
17. command: `node bin/cli.js --update`
   expect: 0
18. command: `git add hooks/scripts/lib/benign-command.sh tests/fixtures/gate-fp-corpus/positive.jsonl tests/fixtures/gate-fp-corpus/negative.jsonl tests/benign-command-families.test.sh tests/validate.sh tests/harness-integrity-gate.test.sh tests/human-decision-gate.test.sh CHANGELOG.md && git add -u -- .claude && git reset -q -- .claude/agent-memory && git commit -m "feat(ptr-u7b-1): read-only families F1 and F3 in the benign-command lib (#562)" -m "Co-Authored-By: Claude Sonnet 5.5 <noreply@anthropic.com>"`
   expect: 0

## Do NOT touch
- `adapters/` (the lib is Claude-only; create no adapter copy)
- `agents/`, `templates/`, `.claude-plugin/plugin.json`, `package.json` (no version bump)
- `docs/harness-glossary.md`, `CONTEXT.md`, `docs/adr/` (no glossary or ADR edits)
- `hooks/scripts/*.sh` (the gate scripts; only the lib under `hooks/scripts/lib/` changes)
- `scripts/` and `docs/audits/` (the harvest script and audit doc are ptr-u7b-2)
- `tests/reviewed-path-gate.test.sh` and `.claude/agent-memory/`

## Acceptance criteria
1. run: `bash tests/benign-command-families.test.sh > /dev/null`
   exit: 0
   stdout: empty
   mutation: skip edit 3 (sort and uniq helpers); their positives print FAIL, exit 1.
2. run: `bash tests/benign-command-families.test.sh | cut -d' ' -f1,2 | sort | uniq -c | sed 's/^ *//' | paste -sd' '`
   exit: 0
   stdout: `20 ok negative 16 ok positive`
   mutation: drop the jq arm of edit 2; the jq positives print FAIL and the positive count is 14.
3. run: `m="$(mktemp)"; o="$(mktemp)"; git show "$(git log --format='%H %s' | grep -E '^[0-9a-f]+ [a-z]+\(ptr-u7b-1\): ' | cut -d' ' -f1 | tail -1)~1:hooks/scripts/lib/benign-command.sh" > "$m"; BENIGN_LIB="$m" bash tests/benign-command-families.test.sh > "$o"; echo "rc=$? f13=$(grep -c '^FAIL positive F[13] ' "$o") fail=$(grep -c '^FAIL ' "$o")"; rm -f "$m" "$o"`
   exit: 0
   stdout: `rc=1 f13=13 fail=13`
   mutation: use the finished lib instead of the parent's; stdout `rc=0 f13=0 fail=0`.
   proof: scratch replay printed rc=1 f13=13 fail=13.
4. run: `m="$(mktemp)"; o="$(mktemp)"; sed 's/\[bdfghiMnRrsuVcCz\]/[bdfghiMnRrsuVcCzo]/' hooks/scripts/lib/benign-command.sh > "$m"; BENIGN_LIB="$m" bash tests/benign-command-families.test.sh > "$o"; echo "rc=$? line=$(grep -cxF "FAIL negative - sort -o x y" "$o")"; rm -f "$m" "$o"`
   exit: 0
   stdout: `rc=1 line=1`
   mutation: the run is the mutation, applied to a throwaway copy of the lib. (a) adds o to sort's short options.
   proof: scratch replay printed rc=1 line=1.
5. run: `m="$(mktemp)"; o="$(mktemp)"; sed 's/^      --\*) return 1 ;;$/      --output*) return 1 ;;\n      --*) ;;/' hooks/scripts/lib/benign-command.sh > "$m"; BENIGN_LIB="$m" bash tests/benign-command-families.test.sh > "$o"; echo "rc=$? line=$(grep -cxF "FAIL negative - sort --ou=x y" "$o")"; rm -f "$m" "$o"`
   exit: 0
   stdout: `rc=1 line=1`
   mutation: the run is the mutation, applied to a throwaway copy of the lib. (b) swaps the long-option allowlist for the old denylist.
   proof: scratch replay printed rc=1 line=1.
6. run: `m="$(mktemp)"; o="$(mktemp)"; sed '/segment_is_plain "\$1" || return 1/d' hooks/scripts/lib/benign-command.sh > "$m"; BENIGN_LIB="$m" bash tests/benign-command-families.test.sh > "$o"; echo "rc=$? line=$(grep -cxF "FAIL negative - sort '-o' x y" "$o")"; rm -f "$m" "$o"`
   exit: 0
   stdout: `rc=1 line=1`
   mutation: the run is the mutation, applied to a throwaway copy of the lib. (c) drops the banned-character check.
   proof: scratch replay printed rc=1 line=1.
7. run: `m="$(mktemp)"; o="$(mktemp)"; sed '/\[ "\$ops" = 0 \] || case/d' hooks/scripts/lib/benign-command.sh > "$m"; BENIGN_LIB="$m" bash tests/benign-command-families.test.sh > "$o"; echo "rc=$? line=$(grep -cxF "FAIL negative - uniq f -c" "$o")"; rm -f "$m" "$o"`
   exit: 0
   stdout: `rc=1 line=1`
   mutation: the run is the mutation, applied to a throwaway copy of the lib. (d) drops uniq's options-before-operand rule.
   proof: scratch replay printed rc=1 line=1.
8. run: `cmp hooks/scripts/lib/benign-command.sh .claude/hooks/scripts/lib/benign-command.sh && git ls-files adapters/codex/hooks/scripts/lib/benign-command.sh adapters/cursor/hooks/scripts/lib/benign-command.sh | wc -l`
   exit: 0
   stdout: `0`
   mutation: skip edit 17 (node bin/cli.js --update); cmp reports a difference, exit 1.
9. run: `bash -c '. hooks/scripts/lib/benign-command.sh; command_is_provably_benign "ls && cd docs" && command_is_provably_benign "cd docs | wc -l f" && ! command_is_provably_benign "cd a b && ls" && ! command_is_provably_benign "cd && ls" && ! command_is_provably_benign "ls; cd docs; touch z"'`
   exit: 0
   stdout: empty
   mutation: skip edit 4 (cd helper); the cd checks fail, exit 1.
10. run: `m="$(mktemp)"; o="$(mktemp)"; sed 's/cd) cd_segment_allowed "\$1"; return \$? ;;/cd) [ "\$start" = 0 ] \&\& cd_segment_allowed "\$1"; return \$? ;;/' hooks/scripts/lib/benign-command.sh > "$m"; bash -c ". $m; command_is_provably_benign \"ls && cd docs\" && command_is_provably_benign \"cd docs | wc -l f\" && ! command_is_provably_benign \"cd a b && ls\" && ! command_is_provably_benign \"cd && ls\" && ! command_is_provably_benign \"ls; cd docs; touch z\""; echo "rc=$?"; rm -f "$m"`
   exit: 0
   stdout: `rc=1`
   mutation: the run is the mutation, applied to a throwaway copy of the lib. (e) allows cd only in the first segment.
   proof: scratch replay printed rc=1.
11. run: `m="$(mktemp)"; o="$(mktemp)"; sed '/\[ "\${#w\[@\]}" = 2 \] || return 1/d' hooks/scripts/lib/benign-command.sh > "$m"; bash -c ". $m; command_is_provably_benign \"ls && cd docs\" && command_is_provably_benign \"cd docs | wc -l f\" && ! command_is_provably_benign \"cd a b && ls\" && ! command_is_provably_benign \"cd && ls\" && ! command_is_provably_benign \"ls; cd docs; touch z\""; echo "rc=$?"; rm -f "$m"`
   exit: 0
   stdout: `rc=1`
   mutation: the run is the mutation, applied to a throwaway copy of the lib. (f) drops the two-word rule of cd.
   proof: scratch replay printed rc=1.
12. run: `bash tests/harness-integrity-gate.test.sh | /usr/bin/grep -cE '^OK +\[U7c\] harness-integrity-gate (allows the cd-prefixed form \(F1\+F3, U7b-1\)|refuses the touch-prefixed compound form|refuses the cd-then-touch compound form)$'`
   exit: 0
   stdout: `3`
   mutation: skip edit 9; the labels are absent, stdout `0`, exit 1.
13. run: `D=$(mktemp -d) && git worktree add -q --detach "$D/w" HEAD && sed -i 's/du|cut|tr|nl) return 0 ;;/du|cut|tr|nl|touch) return 0 ;;/' "$D/w/hooks/scripts/lib/benign-command.sh" && (cd "$D/w" && bash tests/harness-integrity-gate.test.sh > "$D/o.txt" 2>&1; echo "rc=$? n=$(/usr/bin/grep -cE '^OK +\[U7c\] harness-integrity-gate (allows the cd-prefixed form \(F1\+F3, U7b-1\)|refuses the touch-prefixed compound form|refuses the cd-then-touch compound form)$' "$D/o.txt")"); git worktree remove --force "$D/w"; rm -rf "$D"`
   exit: 0
   stdout: `rc=1 n=1`
   mutation: the run is the mutation: touch is added to the allowlist in a detached worktree of HEAD.
   proof: scratch replay printed rc=1 n=1.
14. run: `o="$(mktemp)"; bash tests/human-decision-gate.test.sh > "$o"; echo "blocked=$(/usr/bin/grep -cE '^OK +OB-([1-9]|1[0-5]) .* -> blocked$' "$o") allowed=$(/usr/bin/grep -cE '^OK +OB-10 .* -> allowed$' "$o") fail=$(/usr/bin/grep -c '^FAIL OB-' "$o")"; rm -f "$o"`
   exit: 0
   stdout: `blocked=14 allowed=1 fail=0`
   mutation: skip edit 15 (verdict variable); OB-10 is checked blocked: `blocked=13 allowed=0 fail=1`.
15. run: `D=$(mktemp -d) && cp -r hooks/scripts/lib "$D/" && cp hooks/scripts/human-decision-gate.sh "$D/mutant.sh" && sed -i 's/du|cut|tr|nl) return 0 ;;/du|cut|tr|nl|tee) return 0 ;;/' "$D/lib/benign-command.sh" && GATE_UNDER_TEST="$D/mutant.sh" bash tests/human-decision-gate.test.sh > "$D/o.txt" 2>&1; echo "rc=$? blocked=$(/usr/bin/grep -cE '^OK +OB-([1-9]|1[0-5]) .* -> blocked$' "$D/o.txt") fail15=$(/usr/bin/grep -c '^FAIL OB-15 ' "$D/o.txt")"; rm -rf "$D"`
   exit: 0
   stdout: `rc=1 blocked=13 fail15=1`
   mutation: the run is the mutation: tee is added to the allowlist in a throwaway copy of the lib.
   proof: scratch replay printed rc=1 blocked=13 fail15=1.
16. run: `bash tests/reviewed-path-gate.test.sh > /dev/null && bash tests/human-decision-gate.test.sh > /dev/null && bash tests/harness-integrity-gate.test.sh > /dev/null`
   exit: 0
   stdout: empty
   mutation: skip edit 9 or 12; a pin disagrees with the lib and its suite exits 1.
17. run: `bash tests/harness-integrity-gate.test.sh | /usr/bin/grep -c '^FAIL.*C4[.]1' || true`
   exit: 0
   stdout: `0`
   mutation: write any of the four phrases of the c41_pattern line into a new tracked file; a C4.1 FAIL line appears.
18. run: `/usr/bin/grep -c 'tests/benign-command-families.test.sh' tests/validate.sh`
   exit: 0
   stdout: `4`
   mutation: skip edit 8; stdout `0`, exit 1.
19. run: `bash tests/validate-lanes.sh --lanes 4 | tail -1`
   exit: 0
   stdout: `All checks passed.`
   mutation: break any suite; the last line reads One or more checks FAILED.
20. run: `L=$(git log --format='%H %s' | grep -E '^[0-9a-f]+ [a-z]+\(ptr-u7b-1\): ' | cut -d' ' -f1); test -n "$L" || { echo no-unit-commit; exit 3; }; for c in $L; do git diff --name-only "$c~1..$c" | LC_ALL=C sort | paste -sd' '; done | head -1`
   exit: 0
   stdout: `.claude/hooks/scripts/lib/benign-command.sh .claude/persona-config.json CHANGELOG.md hooks/scripts/lib/benign-command.sh tests/benign-command-families.test.sh tests/fixtures/gate-fp-corpus/negative.jsonl tests/fixtures/gate-fp-corpus/positive.jsonl tests/harness-integrity-gate.test.sh tests/human-decision-gate.test.sh tests/validate.sh`
   mutation: also stage `agents/orchestrator.md`; the list gains that path.
   proof: scratch replay printed exactly that list.
21. run: `L=$(git log --format='%H %s' | grep -E '^[0-9a-f]+ [a-z]+\(ptr-u7b-1\): ' | cut -d' ' -f1); test -n "$L" || { echo no-unit-commit; exit 3; }; for c in $L; do git log -1 --format=%B "$c" | grep -c "^Co-Authored-By: Claude .* <noreply@anthropic.com>$"; done`
   exit: 0
   stdout: `1`
   mutation: omit the second -m of the commit command; stdout `0`, exit 1.
   proof: scratch replay printed 1.
22. run: `L=$(git log --format='%H %s' | grep -E '^[0-9a-f]+ [a-z]+\(ptr-u7b-1\): ' | cut -d' ' -f1); test -n "$L" || { echo no-unit-commit; exit 3; }; E=$(echo "$L" | head -1); git log --format=%s "$E..HEAD" -- hooks/scripts/lib/benign-command.sh tests/benign-command-families.test.sh tests/fixtures/gate-fp-corpus tests/harness-integrity-gate.test.sh tests/human-decision-gate.test.sh | grep -vcE '^[a-z]+\(ptr-u7b-1\): '`
   exit: 1
   stdout: `0`
   mutation: add a later commit `fix: x` touching tests/benign-command-families.test.sh; stdout `1`.
   proof: scratch replay printed 0.
23. run: `git check-ignore tests/benign-command-families.test.sh tests/fixtures/gate-fp-corpus/positive.jsonl tests/fixtures/gate-fp-corpus/negative.jsonl | wc -l`
   exit: 0
   stdout: `0`
   mutation: list an ignored path such as microworlds/x; stdout `1`.
24. run: `git status --porcelain --untracked-files=no -- . ':!.claude/agent-memory' | wc -l`
   exit: 0
   stdout: `0`
   mutation: leave one edited file uncommitted; stdout `1`.

## Pre-resolved context
tdd: yes tests/benign-command-families.test.sh
blast-radius: hooks/scripts/lib/benign-command.sh:36 hooks/scripts/reviewed-path-gate.sh:253 hooks/scripts/human-decision-gate.sh:727 hooks/scripts/harness-integrity-gate.sh:289 tests/human-decision-gate.test.sh:1118 tests/harness-integrity-gate.test.sh:1491 (grep-derived, no graph run; only these three gates source the lib)
c41-trap: tests/harness-integrity-gate.test.sh sweeps tracked files for the four phrases of its c41_pattern line. Nothing this unit writes may contain one (do not copy them); criterion 17 enforces it. Leave the C4.1 table alone.
file-tools: use the Edit tool, and the Write tool for new files. If an edit is rejected or a hook refuses a command, STOP and report the refusal text; never route around it (no heredoc, no python, no path obfuscation).
payload-indent: strip exactly 3 leading spaces from each non-empty payload line. A `before:` or `after:` payload starts at the first non-space character of its first line (that line's leading spaces stay in the file); later lines carry their own indentation.
gate-run: criterion 19 runs the lanes gate in the foreground (2-3 minutes; 600000 ms timeout; never background it). On a failure capture the FAILED check name first. Only tests/rollout-preflight.test.sh (AC14/W9) or tests/microworld/dashboard-decision-run.test.js (Test 5) may be called flaky, and only after that check alone passes on a rerun; report both runs.
already-green: before the edits criteria 8, 16, 17, 23 and 24 already pass (parity, regression and hygiene guards), and 10 and 11 print rc=1 on any lib without the cd helper, so they prove their point only after edit 4. Criterion 13 makes its own detached worktree; if interrupted, run git worktree prune.
commit-message: feat(ptr-u7b-1): read-only families F1 and F3 in the benign-command lib (#562)
Co-Authored-By: Claude Sonnet 5.5 <noreply@anthropic.com>
review-packet:
~~~
unit: ptr-u7b-1 (#562)
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
criterion 21: <FILL: exit and stdout>
criterion 22: <FILL: exit and stdout>
criterion 23: <FILL: exit and stdout>
criterion 24: <FILL: exit and stdout>
~~~
diagnosis: none

## Escalation
If any instruction cannot be followed exactly as written, STOP and report a spec gap; do not improvise.
