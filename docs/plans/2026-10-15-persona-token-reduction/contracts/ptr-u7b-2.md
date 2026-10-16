Unit: ptr-u7b-2

## Objective
`scripts/gate-fp-harvest.py` prints a counts-only markdown table of gate blocks and flipped commands per family, `leaks=<n>` (`--check-doc`) and fills a doc span (`--fill-doc`), never printing a command; `tests/gate-fp-harvest.test.sh` proves it on a synthetic store and is registered in `tests/validate.sh`; `docs/audits/2026-10-15-gate-fp-corpus.md` is the skeleton with both lib hashes and the PENDING span; CHANGELOG records it; no version bump.

## Retrieval
GitHub issues: `gh issue view 563 --repo Storreslara/AntiSlop`. Siblings: `gh issue list --repo Storreslara/AntiSlop --label plan/persona-token-reduction`. Spec: `docs/plans/2026-10-15-persona-token-reduction.md`, "Step U7b-2" and "Ruling H-U7B2".

## Affected files
- `scripts/gate-fp-harvest.py`, `tests/gate-fp-harvest.test.sh`, `tests/fixtures/gate-fp-harvest/lib-base.sh`, `tests/fixtures/gate-fp-harvest/lib-new.sh`, `docs/audits/2026-10-15-gate-fp-corpus.md` (anchor: new file)
- `tests/validate.sh` (anchor: line matching `echo "FAIL tests/benign-command-families.test.sh"`)
- `CHANGELOG.md` (anchor: line matching `## [Unreleased]`)

## Ordered edits
1. command: `test ! -e scripts/gate-fp-harvest.py && test ! -e tests/gate-fp-harvest.test.sh && test ! -e docs/audits/2026-10-15-gate-fp-corpus.md && git log --format=%s | grep -qE '^[a-z]+\(ptr-u7b-1\): ' && test -z "$(git status --porcelain --untracked-files=no -- . ':!.claude/agent-memory')"`
   expect: 0
2. file: `scripts/gate-fp-harvest.py`
   anchor: new file (Write tool, exact content; a next edit of this file goes after this payload's last line)
   indent: 3
   insert-after:
   ~~~~
   #!/usr/bin/env python3
   """Count gate blocks in this repository's transcript store (ptr-u7b-2). Counts only:
   no mode prints, writes or returns a command; the outputs are a markdown table,
   `leaks=<n>` and `filled <path>`.

   Usage: python3 -I scripts/gate-fp-harvest.py [--root DIR] --since ISO --until ISO
            --lib PATH --baseline-lib PATH [--check-doc PATH | --fill-doc PATH]

   A hit is a Bash tool_use whose paired tool_result has is_error true and text
   containing BLOCKED, timestamped in [since, until). A command is flipped when
   command_is_provably_benign is false under --baseline-lib and true under --lib.
   """
   import argparse
   import datetime
   import glob
   import json
   import os
   import re
   import subprocess
   import sys

   GATES = ('reviewed-path-gate', 'human-decision-gate', 'harness-integrity-gate')
   CAP = 4096
   BEGIN = '<!-- harvest:begin -->'
   END = '<!-- harvest:end -->'
   F1 = re.compile(r'^\s*cd\s+[^\s;&|$`*?\[]+\s*(&&|;)')
   F2 = ('2>&1', '2>/dev/null', '>/dev/null')
   F3 = ('du', 'sort', 'uniq', 'cut', 'tr', 'nl', 'jq')


   def parse_ts(s):
       d = datetime.datetime.fromisoformat(s.replace('Z', '+00:00'))
       return d if d.tzinfo else d.replace(tzinfo=datetime.timezone.utc)


   def result_text(content):
       if isinstance(content, str):
           return content
       if isinstance(content, list):
           return '\n'.join(p.get('text', '') for p in content if isinstance(p, dict))
       return ''


   def default_root():
       key = os.getcwd().replace('/', '-')
       return os.path.join(os.path.expanduser('~'), '.claude', 'projects', key)


   def collect(root, since, until):
       """Return a list of (command, gate) for every hit in the window."""
       pat = [os.path.join(root, '*.jsonl'), os.path.join(root, '*', 'subagents', '*.jsonl')]
       hits = []
       for path in sorted(p for g in pat for p in glob.glob(g)):
           uses, results = {}, {}
           with open(path, encoding='utf-8', errors='replace') as fh:
               for line in fh:
                   try:
                       rec = json.loads(line)
                       content = rec['message']['content']
                   except (ValueError, KeyError, TypeError):
                       continue
                   for part in content if isinstance(content, list) else []:
                       if not isinstance(part, dict):
                           continue
                       if part.get('type') == 'tool_use' and part.get('name') == 'Bash':
                           uses[part.get('id')] = ((part.get('input') or {}).get('command'), rec.get('timestamp'))
                       elif part.get('type') == 'tool_result' and part.get('is_error') is True:
                           results[part.get('tool_use_id')] = result_text(part.get('content'))
           for uid, (cmd, ts) in uses.items():
               text = results.get(uid, '')
               try:
                   when = parse_ts(ts)
               except (AttributeError, TypeError, ValueError):
                   continue
               if isinstance(cmd, str) and 'BLOCKED' in text and since <= when < until:
                   hits.append((cmd, next((g for g in GATES if g in text), 'other')))
   ~~~~
3. file: `scripts/gate-fp-harvest.py`
   anchor: line matching `                hits.append((cmd, next((g for g in GATES if g in text), 'other')))`
   indent: 3
   insert-after:
   ~~~~
       return hits


   def benign(lib, cmd):
       script = '. "$1" && command_is_provably_benign "$2"'
       try:
           r = subprocess.run(['bash', '-c', script, 'x', lib, cmd], stdin=subprocess.DEVNULL,
                              stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL, timeout=20)
       except (subprocess.TimeoutExpired, ValueError, OSError):
           return False
       return r.returncode == 0


   def in_f3(cmd):
       segs = re.split(r'\|\||&&|;|\|', cmd)
       return any(s.split()[:1] and s.split()[0] in F3 for s in segs)


   def build_table(hits, lib, base):
       distinct = list(dict.fromkeys(c for c, _ in hits))
       classified = [c for c in distinct if len(c) <= CAP]
       d = len(classified)
       flipped, still = [], 0
       for c in classified:
           if not benign(lib, c):
               still += 1
           elif not benign(base, c):
               flipped.append(c)

       def share(n):
           return '%.3f' % (n / d) if d else '0.000'

       rows = [('hits', len(hits), '-'), ('distinct', len(distinct), '-'),
               ('oversize', len(distinct) - d, '-'), ('classified', d, '-'),
               ('F1', sum(1 for c in flipped if F1.match(c)), None),
               ('F2', sum(1 for c in flipped if any(t in c for t in F2)), None),
               ('F3', sum(1 for c in flipped if in_f3(c)), None),
               ('flipped', len(flipped), None), ('still-blocked', still, None)]
       for g in GATES + ('other',):
           rows.append(('gate:' + g, sum(1 for _, x in hits if x == g), '-'))
       out = ['| row | count | share |', '| --- | --- | --- |']
       for name, n, sh in rows:
           out.append('| %s | %d | %s |' % (name, n, share(n) if sh is None else sh))
       return '\n'.join(out)


   def doc_span(path):
       """Return (lines, begin index, end index) of a doc with exactly one marker pair, else None."""
       try:
           with open(path, encoding='utf-8', newline='') as fh:
               lines = fh.read().splitlines(keepends=True)
       except OSError:
           return None
       keys = [l.strip() for l in lines]
       if keys.count(BEGIN) != 1 or keys.count(END) != 1 or keys.index(BEGIN) > keys.index(END):
           return None
       return lines, keys.index(BEGIN), keys.index(END)


   def main(argv):
       ap = argparse.ArgumentParser(prog='gate-fp-harvest.py')
       ap.add_argument('--root')
       ap.add_argument('--since', required=True)
       ap.add_argument('--until', required=True)
       ap.add_argument('--lib')
       ap.add_argument('--baseline-lib')
       ap.add_argument('--check-doc')
       ap.add_argument('--fill-doc')
       a = ap.parse_args(argv)
       if a.check_doc and a.fill_doc:
           ap.error('--check-doc and --fill-doc are exclusive')
       if not a.check_doc and not (a.lib and a.baseline_lib):
           ap.error('--lib and --baseline-lib are required')
       try:
           since, until = parse_ts(a.since), parse_ts(a.until)
       except ValueError:
   ~~~~
4. file: `scripts/gate-fp-harvest.py`
   anchor: line matching `    except ValueError:`
   indent: 3
   insert-after:
   ~~~~
           ap.error('--since and --until must be ISO timestamps')
       span = doc_span(a.fill_doc) if a.fill_doc else None
       if a.fill_doc and span is None:
           print('the doc must hold exactly one begin and one end marker, in that order', file=sys.stderr)
           return 2
       hits = collect(a.root or default_root(), since, until)
       if a.check_doc:
           with open(a.check_doc, encoding='utf-8', errors='replace') as fh:
               text = fh.read()
           print('leaks=%d' % sum(1 for c in set(c for c, _ in hits) if len(c) >= 20 and c in text))
           return 0
       table = build_table(hits, os.path.abspath(a.lib), os.path.abspath(a.baseline_lib))
       if span:
           lines, b, e = span
           with open(a.fill_doc, 'w', encoding='utf-8', newline='') as fh:
               fh.write(''.join(lines[:b + 1] + [table + '\n'] + lines[e:]))
           print('filled %s' % a.fill_doc)
       else:
           print(table)
       return 0


   if __name__ == '__main__':
       sys.exit(main(sys.argv[1:]))
   ~~~~
5. file: `tests/gate-fp-harvest.test.sh`
   anchor: new file (Write tool, exact content; a next edit of this file goes after this payload's last line)
   indent: 3
   insert-after:
   ~~~~
   #!/usr/bin/env bash
   # Synthetic-store test for scripts/gate-fp-harvest.py (ptr-u7b-2); never reads the real store.
   cd "$(dirname "$0")/.." || exit 1
   script="${HARVEST_SCRIPT:-scripts/gate-fp-harvest.py}"
   fx=tests/fixtures/gate-fp-harvest
   w="$(mktemp -d)"
   trap 'rm -rf "$w"' EXIT
   fail=0
   pass() { echo "ok   $*"; }
   bad()  { echo "FAIL $*"; fail=1; }
   S=ZZ-PRIVATE-SENTINEL-42
   since=2026-09-25T00:00:00Z
   stop=2026-10-16T00:00:00Z

   # mkrec <file> <tool_use id> <timestamp> <command> <is_error> <result text> [list]
   mkrec() {
     local res='$t'
     [ "${7:-}" = list ] && res='[{type:"text",text:$t}]'
     jq -cn --arg id "$2" --arg ts "$3" --arg c "$4" \
       '{type:"assistant",timestamp:$ts,message:{content:[{type:"tool_use",id:$id,name:"Bash",input:{command:$c}}]}}' >> "$1"
     jq -cn --arg id "$2" --argjson e "$5" --arg t "$6" \
       "{type:\"user\",message:{content:[{type:\"tool_result\",tool_use_id:\$id,is_error:\$e,content:$res}]}}" >> "$1"
   }

   store="$w/store"
   mkdir -p "$store/sess2/subagents"
   in=2026-10-01T12:00:00.000Z
   s1="$store/s1.jsonl"
   s2="$store/sess2/subagents/a1.jsonl"
   mkrec "$s1" a1 "$in" 'cd docs && ls' true 'BLOCKED: human-decision-gate refused this command'
   mkrec "$s2" a2 "$in" 'cd docs && ls' true 'BLOCKED: human-decision-gate refused this command'
   mkrec "$s1" b1 "$in" 'sort f | uniq -c' true 'BLOCKED by reviewed-path-gate'
   mkrec "$s1" c1 "$in" 'cd x; sort y 2>/dev/null' true 'BLOCKED: harness-integrity-gate'
   mkrec "$s1" d1 "$in" 'rm -f x' true 'BLOCKED: no gate named'
   mkrec "$s2" e1 "$in" "rm $S" true 'BLOCKED: reviewed-path-gate' list
   mkrec "$s1" f1 "$in" "ls $(head -c 5000 /dev/zero | tr '\0' a)" true 'BLOCKED: oversize, no gate named'
   mkrec "$s1" g1 2026-10-17T00:00:00.000Z 'cd out && ls' true 'BLOCKED: human-decision-gate'
   mkrec "$s1" h1 "$in" 'sort h' false 'BLOCKED text, but the result is not an error'
   mkrec "$s1" i1 "$in" 'sort i' true 'permission denied'

   cat > "$w/expected.md" <<'EOF'
   | row | count | share |
   | --- | --- | --- |
   | hits | 7 | - |
   | distinct | 6 | - |
   | oversize | 1 | - |
   | classified | 5 | - |
   | F1 | 2 | 0.400 |
   | F2 | 1 | 0.200 |
   | F3 | 2 | 0.400 |
   | flipped | 3 | 0.600 |
   | still-blocked | 2 | 0.400 |
   | gate:reviewed-path-gate | 2 | - |
   | gate:human-decision-gate | 2 | - |
   | gate:harness-integrity-gate | 1 | - |
   | gate:other | 2 | - |
   EOF

   : > "$w/all.txt"
   run() {
     local rc=0
     python3 -I "$script" "$@" > "$w/last.out" 2>&1 || rc=$?
     cat "$w/last.out" >> "$w/all.txt"
     cat "$w/last.out"
     return "$rc"
   }
   win=(--since "$since" --until "$stop")
   common=("${win[@]}" --lib "$fx/lib-new.sh" --baseline-lib "$fx/lib-base.sh")

   run --root "$store" "${common[@]}" > "$w/t1.txt"
   if diff "$w/t1.txt" "$w/expected.md" > /dev/null; then pass "table equals the literal expected table"; else bad "table differs from the expected table"; fi

   printf '%s\n' '# Doc' "It quotes: rm $S" > "$w/leak.md"
   printf '%s\n' '# Doc' 'It quotes no command.' > "$w/clean.md"
   l1="$(run --root "$store" "${win[@]}" --check-doc "$w/leak.md")"
   l0="$(run --root "$store" "${win[@]}" --check-doc "$w/clean.md")"
   ~~~~
6. file: `tests/gate-fp-harvest.test.sh`
   anchor: line matching `l0="$(run --root "$store" "${win[@]}" --check-doc "$w/clean.md")"`
   indent: 3
   insert-after:
   ~~~~
   if [ "$l1" = leaks=1 ] && [ "$l0" = leaks=0 ]; then pass "check-doc prints leaks=1 and leaks=0"; else bad "check-doc printed $l1 and $l0"; fi

   printf '%s\n' '# Doc' 'Before the span.' '<!-- harvest:begin -->' 'PENDING: placeholder' '<!-- harvest:end -->' 'After the span.' > "$w/doc.md"
   cp "$w/doc.md" "$w/fill.md"
   f1="$(run --root "$store" "${common[@]}" --fill-doc "$w/fill.md")"
   if [ "$f1" = "filled $w/fill.md" ]; then pass "fill-doc prints filled <path>"; else bad "fill-doc stdout differs"; fi
   awk '/harvest:begin/{f=1;next} /harvest:end/{f=0} f' "$w/fill.md" > "$w/span.txt"
   if diff "$w/span.txt" "$w/expected.md" > /dev/null; then pass "fill-doc span equals the expected table"; else bad "fill-doc span differs from the expected table"; fi
   strip='/harvest:begin/{print;skip=1;next} /harvest:end/{skip=0} !skip'
   if diff <(awk "$strip" "$w/fill.md") <(awk "$strip" "$w/doc.md") > /dev/null; then pass "fill-doc leaves every line outside the span unchanged"; else bad "fill-doc changed a line outside the span"; fi
   if [ "$(grep -c "$S" "$w/fill.md")" = 0 ]; then pass "filled doc holds no sentinel"; else bad "filled doc holds the sentinel"; fi
   printf '%s\n' '# Doc' '<!-- harvest:begin -->' '<!-- harvest:begin -->' '<!-- harvest:end -->' > "$w/two.md"
   cp "$w/two.md" "$w/two.orig"
   rc=0
   run --root "$store" "${common[@]}" --fill-doc "$w/two.md" > /dev/null || rc=$?
   if [ "$rc" = 2 ] && cmp -s "$w/two.md" "$w/two.orig"; then pass "fill-doc exits 2 and leaves a two-begin doc unchanged"; else bad "fill-doc on a two-begin doc: rc=$rc or the file changed"; fi

   dr="$w/home/.claude/projects/$(pwd -P | tr / -)"
   mkdir -p "$dr"
   cp -r "$store"/. "$dr"/
   HOME="$w/home" python3 -I "$script" "${common[@]}" > "$w/t2.txt" 2>&1
   if diff "$w/t2.txt" "$w/expected.md" > /dev/null; then pass "the default root resolves under HOME"; else bad "the default root did not resolve to the project directory"; fi

   if [ "$(grep -c "$S" "$w/all.txt")" = 0 ]; then pass "$S appears in no output"; else bad "$S leaked into an output"; fi

   [ "$fail" = 0 ] && echo "All gate-fp-harvest checks passed."
   exit "$fail"
   ~~~~
7. file: `tests/fixtures/gate-fp-harvest/lib-base.sh`
   anchor: new file (Write tool, exact content)
   indent: 3
   insert-after:
   ~~~~
   # Stub baseline lib (ptr-u7b-2 fixture): only ls is benign.
   command_is_provably_benign() {
     case "$1" in
       "ls"|"ls "*) return 0 ;;
     esac
     return 1
   }
   ~~~~
8. file: `tests/fixtures/gate-fp-harvest/lib-new.sh`
   anchor: new file (Write tool, exact content)
   indent: 3
   insert-after:
   ~~~~
   # Stub new lib (ptr-u7b-2 fixture): ls, cd and sort are benign.
   command_is_provably_benign() {
     case "$1" in
       "ls"|"ls "*|"cd "*|"sort "*) return 0 ;;
     esac
     return 1
   }
   ~~~~
9. file: `docs/audits/2026-10-15-gate-fp-corpus.md`
   anchor: new file (Write tool, exact content)
   indent: 3
   insert-after:
   ~~~~
   # Gate false-positive corpus: share of real gate blocks that families F1 and F3 free (item 7b)

   Source: `docs/plans/2026-10-15-persona-token-reduction.md`, steps U7b-1 and U7b-2 (ruling H-U7B). This is a skeleton: the user fills the real-store counts in human step H7b2, and until then the families' real share is unmeasured.

   ## Method

   - Script: `scripts/gate-fp-harvest.py` (`python3 -I`). It reads only this repository's project directory under `~/.claude/projects` (the working directory with every `/` replaced by `-`): `<root>/*.jsonl` and `<root>/*/subagents/*.jsonl`.
   - Hit: a `Bash` tool_use whose paired tool_result (same `tool_use_id`) has `is_error: true` and text containing `BLOCKED`, timestamped in `[since, until)`. The gate is the first of `reviewed-path-gate`, `human-decision-gate` and `harness-integrity-gate` found in the result text, else `other`.
   - Distinct exact command strings are counted. A command over 4,096 characters is `oversize` and not classified; D, the denominator, is the number of distinct commands that are not oversize.
   - The classifier is the lib itself: a `bash` subprocess sources a lib and calls `command_is_provably_benign` with the command as an argument. A command is flipped when it is non-benign under `--baseline-lib` and benign under `--lib`.
   - Family attribution of flipped commands is a fixed syntactic rule, and a command may count in several families. F1: it starts with `cd <word>` followed by `&&` or `;`, where the word holds no whitespace, `;`, `&`, `|`, `$`, backtick, `*`, `?` or `[`. F2: it contains `2>&1`, `2>/dev/null` or `>/dev/null`. F3: any segment (split on `|`, `;`, `&&` and `||`) starts with one of `du sort uniq cut tr nl jq`.
   - Output: one markdown table (rows `hits`, `distinct`, `oversize`, `classified`, `F1`, `F2`, `F3`, `flipped`, `still-blocked`, one `gate:<name>` per gate; shares are count over D to 3 decimals), `leaks=<n>` (`--check-doc`) or `filled <path>` (`--fill-doc`). No mode prints, writes or returns a command, and no harvested command text is committed anywhere.
   - Reproduction is per-machine and best-effort: the store is local and transcript cleanup can delete in-window sessions. Both libs come from fixed commits, so a later lib edit cannot change a re-run.

   ## Human step H7b2

   The user runs this from the repository root, in their own terminal, after U7b-2 PASS. `PRE_HASH_TOKEN` is the parent of U7b-1's first commit and `U7B1_HASH_TOKEN` is U7b-1's final commit.

   ```
   b="$(mktemp)"; n="$(mktemp)"
   git show PRE_HASH_TOKEN:hooks/scripts/lib/benign-command.sh > "$b"
   git show U7B1_HASH_TOKEN:hooks/scripts/lib/benign-command.sh > "$n"
   python3 -I scripts/gate-fp-harvest.py --since 2026-09-25T00:00:00Z --until 2026-10-16T00:00:00Z --lib "$n" --baseline-lib "$b" --fill-doc docs/audits/2026-10-15-gate-fp-corpus.md
   python3 -I scripts/gate-fp-harvest.py --since 2026-09-25T00:00:00Z --until 2026-10-16T00:00:00Z --lib "$n" --baseline-lib "$b" --check-doc docs/audits/2026-10-15-gate-fp-corpus.md
   ```

   The second command must print `leaks=0`; a higher value means do not commit, run `git checkout -- docs/audits/2026-10-15-gate-fp-corpus.md` and report it. Then commit the doc by explicit path. Re-running the first command and then `git diff --exit-code -- docs/audits/2026-10-15-gate-fp-corpus.md` exits 0 on the measuring machine.

   ## Result

   <!-- harvest:begin -->
   PENDING: real-store harvest, human step H7b2
   <!-- harvest:end -->

   If the user declines H7b2, this document stays PENDING, which is a valid end state.
   ~~~~
10. command: `f=$(git log --format='%H %s' | grep -E '^[0-9a-f]+ [a-z]+\(ptr-u7b-1\): ' | cut -d' ' -f1 | tail -1); u=$(git log --format='%H %s' | grep -E '^[0-9a-f]+ [a-z]+\(ptr-u7b-1\): ' | cut -d' ' -f1 | head -1); p=$(git rev-parse "$f~1"); test -n "$f" && test -n "$u" && sed -i "s/PRE_HASH_TOKEN/$p/g; s/U7B1_HASH_TOKEN/$u/g" docs/audits/2026-10-15-gate-fp-corpus.md`
   expect: 0
11. file: `tests/validate.sh`
   anchor: line matching `echo "FAIL tests/benign-command-families.test.sh"`
   indent: 3
   before:
   ~~~~
     echo "FAIL tests/benign-command-families.test.sh"
     fail=1
   fi
   ~~~~
   after:
   ~~~~
     echo "FAIL tests/benign-command-families.test.sh"
     fail=1
   fi

   echo
   echo "== tests/gate-fp-harvest.test.sh: synthetic-store test for scripts/gate-fp-harvest.py (Bash, ptr-u7b-2) =="
   if bash tests/gate-fp-harvest.test.sh > /dev/null; then
     echo "OK   tests/gate-fp-harvest.test.sh"
   else
     echo "FAIL tests/gate-fp-harvest.test.sh"
     fail=1
   fi
   ~~~~
12. file: `CHANGELOG.md`
   anchor: line matching `## [Unreleased]`
   indent: 3
   before:
   ~~~~
   ## [Unreleased]
   ~~~~
   after:
   ~~~~
   ## [Unreleased]

   **Gate false-positive harvest script and audit skeleton (ptr-u7b-2).** `scripts/gate-fp-harvest.py` counts, from this repository's Claude Code transcript store, the `Bash` calls a gate blocked in a time window, deduplicates them (a command over 4,096 characters is counted as oversize), asks `command_is_provably_benign` under a baseline lib and a current lib which ones the new lib frees, and attributes those to the families F1, F2 and F3 by a fixed syntactic rule. Its only outputs are a markdown table of counts, `--check-doc` (`leaks=<n>`) and `--fill-doc` (fills the span between two markers); no mode prints a command. `tests/gate-fp-harvest.test.sh` (registered in `tests/validate.sh`) proves it on a synthetic store built in a temp dir. `docs/audits/2026-10-15-gate-fp-corpus.md` is the skeleton: method, both lib hashes and the human step H7b2 command block, with the result span PENDING, so the families' real share stays unmeasured until the user runs H7b2. No version bump.
   ~~~~
13. command: `git add scripts/gate-fp-harvest.py tests/gate-fp-harvest.test.sh tests/fixtures/gate-fp-harvest docs/audits/2026-10-15-gate-fp-corpus.md tests/validate.sh CHANGELOG.md && git commit -m "feat(ptr-u7b-2): gate-fp-harvest script, synthetic test and audit skeleton (#563)" -m "Co-Authored-By: Claude Sonnet 5.5 <noreply@anthropic.com>"`
   expect: 0

## Do NOT touch
- `hooks/` (the script only sources the libs)
- `tests/fixtures/gate-fp-corpus/` (the ptr-u7b-1 corpora; no blocked.jsonl is ever created)
- `agents/`, `templates/`, `.claude-plugin/plugin.json`, `package.json` (no version bump)
- `docs/harness-glossary.md`, `CONTEXT.md`, `docs/adr/` (no glossary or ADR edits)
- `.claude/agent-memory/` and `adapters/`

## Acceptance criteria
1. run: `bash tests/gate-fp-harvest.test.sh | tail -1`
   exit: 0
   stdout: `All gate-fp-harvest checks passed.`
   mutation: skip the third script edit (build_table onward); the table cases print FAIL and the last line is missing.
2. run: `m="$(mktemp)"; o="$(mktemp)"; sed 's/list(dict.fromkeys(c for c, _ in hits))/[c for c, _ in hits]/' scripts/gate-fp-harvest.py > "$m"; HARVEST_SCRIPT="$m" bash tests/gate-fp-harvest.test.sh > "$o"; echo "rc=$? line=$(grep -cxF "FAIL table differs from the expected table" "$o")"; rm -f "$m" "$o"`
   exit: 0
   stdout: `rc=1 line=1`
   mutation: the run is the mutation: it removes the dedupe from a throwaway copy of the script, and the distinct row changes.
   proof: scratch replay printed rc=1 line=1.
3. run: `m="$(mktemp)"; o="$(mktemp)"; sed 's/lines\[:b + 1\]/lines[:e + 1]/; s/ + lines\[e:\]/ + lines[e + 1:]/' scripts/gate-fp-harvest.py > "$m"; HARVEST_SCRIPT="$m" bash tests/gate-fp-harvest.test.sh > "$o"; echo "rc=$? line=$(grep -cxF "FAIL fill-doc span differs from the expected table" "$o")"; rm -f "$m" "$o"`
   exit: 0
   stdout: `rc=1 line=1`
   mutation: the run is the mutation: --fill-doc appends the table after the end marker instead of replacing the span, in a throwaway copy of the script.
   proof: scratch replay printed rc=1 line=1.
4. run: `/usr/bin/grep -c 'tests/gate-fp-harvest.test.sh' tests/validate.sh`
   exit: 0
   stdout: `4`
   mutation: skip the validate.sh edit; stdout `0`, exit 1.
5. run: `git ls-files tests/fixtures/gate-fp-corpus/blocked.jsonl | wc -l`
   exit: 0
   stdout: `0`
   mutation: git add a file of that name; stdout `1`.
6. run: `f=docs/audits/2026-10-15-gate-fp-corpus.md; echo "pending=$(grep -c '^PENDING: real-store harvest, human step H7b2$' $f) begin=$(grep -c 'harvest:begin' $f) end=$(grep -c 'harvest:end' $f) shows=$(grep -cE 'git show [0-9a-f]{40}:hooks/scripts/lib/benign-command.sh' $f) fill=$(grep -c -- '--fill-doc docs/audits/2026-10-15-gate-fp-corpus.md' $f) tok=$(grep -c HASH_TOKEN $f)"`
   exit: 0
   stdout: `pending=1 begin=1 end=1 shows=2 fill=1 tok=0`
   mutation: write the second hash abbreviated (the substitution command); shows=1.
7. run: `f=docs/audits/2026-10-15-gate-fp-corpus.md; p=$(grep -oE '[0-9a-f]{40}:hooks' $f | cut -c1-40 | sed -n 1p); u=$(grep -oE '[0-9a-f]{40}:hooks' $f | cut -c1-40 | sed -n 2p); F=$(git log --format='%H %s' | grep -E '^[0-9a-f]+ [a-z]+\(ptr-u7b-1\): ' | cut -d' ' -f1 | tail -1); L=$(git log --format='%H %s' | grep -E '^[0-9a-f]+ [a-z]+\(ptr-u7b-1\): ' | cut -d' ' -f1 | head -1); git merge-base --is-ancestor "$p" "$u" && test "$p" != "$u" && test "$p" = "$(git rev-parse "$F~1")" && test "$u" = "$L"`
   exit: 0
   stdout: empty
   mutation: swap the two hashes in the doc; the ancestor test fails, exit 1.
8. run: `bash tests/validate-lanes.sh --lanes 4 | tail -1`
   exit: 0
   stdout: `All checks passed.`
   mutation: break the new suite; the last line reads One or more checks FAILED.
9. run: `L=$(git log --format='%H %s' | grep -E '^[0-9a-f]+ [a-z]+\(ptr-u7b-2\): ' | cut -d' ' -f1); test -n "$L" || { echo no-unit-commit; exit 3; }; for c in $L; do git diff --name-only "$c~1..$c" | LC_ALL=C sort | paste -sd' '; done | head -1`
   exit: 0
   stdout: `CHANGELOG.md docs/audits/2026-10-15-gate-fp-corpus.md scripts/gate-fp-harvest.py tests/fixtures/gate-fp-harvest/lib-base.sh tests/fixtures/gate-fp-harvest/lib-new.sh tests/gate-fp-harvest.test.sh tests/validate.sh`
   mutation: also stage `agents/orchestrator.md`; the list gains that path.
   proof: scratch replay printed exactly that list.
10. run: `L=$(git log --format='%H %s' | grep -E '^[0-9a-f]+ [a-z]+\(ptr-u7b-2\): ' | cut -d' ' -f1); test -n "$L" || { echo no-unit-commit; exit 3; }; for c in $L; do git log -1 --format=%B "$c" | grep -c "^Co-Authored-By: Claude .* <noreply@anthropic.com>$"; done`
   exit: 0
   stdout: `1`
   mutation: omit the second -m of the commit command; stdout `0`, exit 1.
   proof: scratch replay printed 1.
11. run: `L=$(git log --format='%H %s' | grep -E '^[0-9a-f]+ [a-z]+\(ptr-u7b-2\): ' | cut -d' ' -f1); test -n "$L" || { echo no-unit-commit; exit 3; }; E=$(echo "$L" | head -1); git log --format=%s "$E..HEAD" -- scripts/gate-fp-harvest.py tests/gate-fp-harvest.test.sh tests/fixtures/gate-fp-harvest docs/audits/2026-10-15-gate-fp-corpus.md | grep -vcE '^[a-z]+\(ptr-u7b-2\): '`
   exit: 1
   stdout: `0`
   mutation: add a later commit `fix: x` touching scripts/gate-fp-harvest.py; stdout `1`.
   proof: scratch replay printed 0.
12. run: `git check-ignore scripts/gate-fp-harvest.py tests/gate-fp-harvest.test.sh tests/fixtures/gate-fp-harvest/lib-base.sh tests/fixtures/gate-fp-harvest/lib-new.sh docs/audits/2026-10-15-gate-fp-corpus.md | wc -l`
   exit: 0
   stdout: `0`
   mutation: list an ignored path such as microworlds/x; stdout `1`.
13. run: `git status --porcelain --untracked-files=no -- . ':!.claude/agent-memory' | wc -l`
   exit: 0
   stdout: `0`
   mutation: leave one edited file uncommitted; stdout `1`.

## Pre-resolved context
tdd: yes tests/gate-fp-harvest.test.sh
blast-radius: tests/validate.sh:1381 hooks/scripts/lib/benign-command.sh:185 (grep-derived, no graph run; nothing sources the script)
real-store: build and test only against the synthetic store the test creates in a temp dir; never read the Claude project transcript directory. The real run is human step H7b2 (the doc holds its command block), after this unit's PASS.
file-tools: use the Write tool for new files and the Edit tool for the rest. If a tool call is rejected or a hook refuses a command, STOP and report the refusal text; never route around it (no heredoc, no python, no path obfuscation).
payload-indent: strip exactly 3 leading spaces from each non-empty payload line. Chunks of one new file append in order.
gate-run: criterion 8 runs the lanes gate in the foreground (2-3 minutes; 600000 ms timeout; never background it). On a failure capture the FAILED check name first. Only tests/rollout-preflight.test.sh (AC14/W9) or tests/microworld/dashboard-decision-run.test.js (Test 5) may be called flaky, and only after that check alone passes on a rerun; report both runs.
already-green: criterion 5 passes before the edits (a hygiene guard); criteria 6 and 7 and edit 10 need ptr-u7b-1 committed first.
commit-message: feat(ptr-u7b-2): gate-fp-harvest script, synthetic test and audit skeleton (#563)
Co-Authored-By: Claude Sonnet 5.5 <noreply@anthropic.com>
review-packet:
~~~
unit: ptr-u7b-2 (#563)
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
~~~
diagnosis: none

## Escalation
If any instruction cannot be followed exactly as written, STOP and report a spec gap; do not improvise.
