Unit: rfp-u2f

## Objective
Fix the replay tooling before Gate G run 2, as the user decided for plan Open Questions 4 (a) and 6 (a)
(2026-10-28). Three changes, plus two small hardening items from the rfp-u2e review:
1. **Capped runs are recorded and gated.** `run.sh` writes the CLI result's own `subtype` and `is_error` on
   every report row (`none` and `true` for a row with no CLI result). `score.py --gate` fails when any scored
   id's run ended `error_max_turns`, and appends one field, `capped=<p>`, after `foreign=` on its single
   `replay-gate:` line. The thresholds stay exactly as they are: at least 30 real, at most 1 refuted-real, at
   most 20% unanswered, and no run over 10 turns as `score.py` measures `num_turns`.
2. **Whole claims.** `build-corpus.py` takes a defect's claim from the whole defect item: the bullet line plus
   every indented line after it, across blank lines, up to the next bullet or unindented line,
   whitespace-collapsed, cut at 8000 characters (a bound that no claim reaches). Which defects are kept still
   depends on the bullet line alone. A new `--refresh-claims` mode rewrites only the `dline` of each row of
   the committed corpus from its FAIL block, so the 41 ids, the rows' other fields, the row order and
   `labels.tsv` stay as they are. The committed `corpus.jsonl` is regenerated with it. `labels.tsv` stays
   byte-identical (sha256 `4efa7b128e8d9bc146610afe2116bee4b3f8cae5072070bdaf931bd527addd67`).
3. **Docs.** The builder docstring, the scorer docstring and the README say exactly this.
4. **Hardening (rfp-u2e PASS notes).**
   - Case (q) runs `run.sh` with stdin from a sentinel file. The draining fake `claude` records what it read,
     and the case asserts that the record is empty, under `timeout 60`. Without `run.sh`'s ` < /dev/null`,
     case (q) now fails at once instead of hanging on an open pipe.
   - `claude` also gets `3<&-`, so it does not inherit the group stream on fd 3 (new case (u)).
   - `run.sh`'s body becomes one function, `main`, called by the last line `main "$@"; exit`. bash then parses
     the whole file before it runs any of it, so an edit to the file during a replay cannot change that
     replay (new case (t)). This is what produced run 1's stray `line 116: … File name too long` line.

No model runs: every test fakes `claude`. No stamped path is touched, so there is no version bump and no
CHANGELOG entry (constitution P3; as for rfp-u2b, rfp-u2c, rfp-u2d and rfp-u2e).

## Retrieval
Fast path, no tracker issue. Spec: `docs/plans/2026-10-27-refutation-pass.md`, sections "Revision 3: Gate G
run 1 failed", "Step 2f" and "Gate G". This file is the contract of record. rfp-u1b (the brief) and this unit
may be implemented in either order, but both must have a reviewer PASS before Gate G run 2. rfp-u1b has its
PASS (4ec89dae). One unit is mid-review at a time.

## Affected files
- `tests/refutation-replay.test.sh` (anchor: line matching `# Fixture suite for eval/refutation-replay/ (rfp-u2): corpus builder, --check, scorer gate and run.sh`; hunks in edits 1 and 2; mode stays 755)
- `tests/refutation-replay-isolation.test.sh` (anchor: line matching `# history-limited replay clone, the guard hook, NONE rows for groups that cannot run, and the docs.`; hunks in edits 3 to 12; mode stays 755)
- `eval/refutation-replay/build-corpus.py` (anchor: line matching `HERE = os.path.dirname(os.path.abspath(__file__))`; hunks in edits 13 to 21; mode stays 755)
- `eval/refutation-replay/score.py` (anchor: line matching `MIN_REAL, MAX_MISSES, MAX_TURNS, MAX_UNANSWERED = 30, 1, 10, 0.20`, which stays byte-identical; hunks in edits 22 to 29; mode stays 755)
- `eval/refutation-replay/run.sh` (anchor: line matching `CLAUDE_FLAGS=(--model sonnet --max-turns 10 --output-format json --no-session-persistence`, which stays byte-identical; hunks in edits 30 to 37; mode stays 755)
- `eval/refutation-replay/README.md` (hunks in edits 38 to 42)
- `eval/refutation-replay/corpus.jsonl` (regenerated only by the command in edit 43, never by hand)

`tests/validate.sh` needs no edit: it already runs both suites (`tests/validate.sh:832-847`, rfp-u2 and
rfp-u2b), and a failing suite sets `fail=1`.

## Ordered edits
The hunks below were generated from spec-master's tested scratch payload. Applied in order to the files at
4ec89dae, they reproduce it byte for byte. Use the Write/Edit tools for every file edit, test files
included.

1. file: `tests/refutation-replay.test.sh`
   anchor: line matching `# --dry-run. Every fixture lives under mktemp -d. It never runs claude and never reads this repo's markers.`
   before:
~~~
# --dry-run. Every fixture lives under mktemp -d. It never runs claude and never reads this repo's markers.
~~~
   after:
~~~
# --dry-run; whole claims and --refresh-claims (rfp-u2f). Every fixture lives under mktemp -d. It never runs
# claude and never reads this repo's markers.
~~~

2. file: `tests/refutation-replay.test.sh`
   anchor: line matching `if [ "$rc" = 1 ]; then ok "(c) --check rejects a bad baseline"; else bad "(c) --check rc=$rc"; fi`
   before:
~~~
if [ "$rc" = 1 ]; then ok "(c) --check rejects a bad baseline"; else bad "(c) --check rc=$rc"; fi

~~~
   after:
~~~
if [ "$rc" = 1 ]; then ok "(c) --check rejects a bad baseline"; else bad "(c) --check rc=$rc"; fi

# rfp-u2f: the same u9 block, with its defects wrapped. The claim is the whole item, across a blank line;
# a word on a continuation line (`mutation`) does not change which defects are kept; the cut is 8000.
mk2="$tmp/markers2"; mkdir -p "$mk2"; cp "$mk/u9.pass" "$mk2/"
long="$(printf 'w %.0s' $(seq 1 4500))"
{ printf 'FAIL u9 2026-01-03T00:00:00Z\ntier: haiku\n'
  printf -- '- src/a.sh:2 x is unquoted, so a space splits it\n  when the caller passes "a b"; a mutation test\n    would not see it.\n\n  Repro: run a.sh with "a b".\n'
  printf -- '- src/a.sh:1 no guard on empty input %s\n' "$long"
  printf -- '- src/a.sh:1 review-precheck printed `criterion 2: fail`\nsummary, not indented\n  indented after an unindented line\n\n'; } > "$mk2/u9.fail"
w1='D1: src/a.sh:2 x is unquoted, so a space splits it when the caller passes "a b"; a mutation test would not see it. Repro: run a.sh with "a b".'
c2="$tmp/out2/corpus.jsonl"; mkdir -p "$tmp/out2"
python3 "$d/build-corpus.py" --repo "$repo" --markers "$mk2" --size 40 --out "$c2" >/dev/null
dl="$(python3 -c 'import json, sys
print("|".join("%s:%d" % (json.loads(l)["dline"][:2], len(json.loads(l)["dline"])) for l in open(sys.argv[1])))' "$c2" 2>/dev/null)"
d1="$(python3 -c 'import json, sys; print(json.loads(open(sys.argv[1]).readline())["dline"])' "$c2" 2>/dev/null)"
if [ "$d1" = "$w1" ] && [ "$dl" = "D1:${#w1}|D2:8015" ] && ! grep -q 'criterion 2\|summary\|indented after' "$c2"; then
  ok "(k) builder keeps the whole defect item, selects on the bullet line, cuts at 8000"
else
  bad "(k) dlines=$dl d1=$d1"
fi
# (l) --refresh-claims extends the committed claims in place: same ids and other fields, labels untouched,
# idempotent
r3="$tmp/out3"; mkdir -p "$r3"; cp "$c" "$r3/corpus.jsonl"; printf 'KEEP\n' > "$r3/labels.tsv"
o3="$(python3 "$d/build-corpus.py" --repo "$repo" --markers "$mk2" --out "$r3/corpus.jsonl" --refresh-claims)"; rc3=$?
h3="$(md5sum < "$r3/corpus.jsonl")"
o4="$(python3 "$d/build-corpus.py" --repo "$repo" --markers "$mk2" --out "$r3/corpus.jsonl" --refresh-claims)"; rc4=$?
same="$(python3 -c 'import json, sys
a, b, w = ([json.loads(l) for l in open(p)] for p in sys.argv[1:4])
rest = lambda r: {k: v for k, v in r.items() if k != "dline"}
print(len(a) == len(b) == 2 and all(rest(x) == rest(y) for x, y in zip(a, b)) and [r["dline"] for r in b] == [r["dline"] for r in w])' "$c" "$r3/corpus.jsonl" "$c2" 2>/dev/null)"
if [ "$rc3" = 0 ] && [ "$o3" = "corpus: refreshed rows=2 longer=2 errors=0" ] && [ "$rc4" = 0 ] \
   && [ "$o4" = "corpus: refreshed rows=2 longer=0 errors=0" ] && [ "$(md5sum < "$r3/corpus.jsonl")" = "$h3" ] \
   && [ "$same" = True ] && [ "$(cat "$r3/labels.tsv")" = KEEP ]; then
  ok "(l) --refresh-claims rewrites only the claims, keeps labels.tsv, and is idempotent"
else
  bad "(l) rc3=$rc3 $o3 rc4=$rc4 $o4 same=$same"
fi
# (m) a row whose claim matches no defect of its block fails closed: exit 1, nothing written
sed 's/no guard on empty input/no such claim/' "$c" > "$r3/bad.jsonl"; h4="$(md5sum < "$r3/bad.jsonl")"
o5="$(python3 "$d/build-corpus.py" --repo "$repo" --markers "$mk2" --out "$r3/bad.jsonl" --refresh-claims)"; rc5=$?
if [ "$rc5" = 1 ] && printf '%s' "$o5" | grep -q '^corpus: refreshed rows=2 longer=0 errors=1$' && [ "$(md5sum < "$r3/bad.jsonl")" = "$h4" ]; then
  ok "(m) --refresh-claims refuses a row it cannot match and writes nothing"
else
  bad "(m) rc5=$rc5 $o5"
fi

~~~

3. file: `tests/refutation-replay-isolation.test.sh`
   anchor: line matching `# history-limited replay clone, the guard hook, NONE rows for groups that cannot run, and the docs.`
   before:
~~~
# history-limited replay clone, the guard hook, NONE rows for groups that cannot run, and the docs.
~~~
   after:
~~~
# history-limited replay clone, the guard hook, NONE rows for groups that cannot run, and the docs; the CLI
# result's subtype, the capped-run gate field, stdin and fd 3, and the parse-first run.sh body (rfp-u2f).
~~~

4. file: `tests/refutation-replay-isolation.test.sh`
   anchor: line matching `[ "$rc" = 1 ] && printf '%s' "$o" | grep -q 'unanswered=7 .* foreign=100$' \`
   before:
~~~
[ "$rc" = 1 ] && printf '%s' "$o" | grep -q 'unanswered=7 .* foreign=100$' \
~~~
   after:
~~~
[ "$rc" = 1 ] && printf '%s' "$o" | grep -q 'unanswered=7 .* foreign=100 capped=0$' \
~~~

5. file: `tests/refutation-replay-isolation.test.sh`
   anchor: line matching `  && ok "(f) a labelled id with no report row is insufficient" || bad "(f) rc=$rc $o"`
   before:
~~~
  && ok "(f) a labelled id with no report row is insufficient" || bad "(f) rc=$rc $o"
~~~
   after:
~~~
  && ok "(f) a labelled id with no report row is insufficient" || bad "(f) rc=$rc $o"
# rfp-u2f: a run cut off at the CLI's turn cap fails the gate on its own, whatever its num_turns says
labels "$tmp/s" 30; for i in $(seq 1 29); do row "$tmp/s" "r$i" CONFIRMED; done; cp -r "$tmp/s" "$tmp/s0"
printf '{"id": "r30", "answer": "NONE", "artifact": "", "num_turns": 5, "cost_usd": 0.1, "subtype": "error_max_turns", "is_error": true}\n' >> "$tmp/s/report.jsonl"
printf '{"id": "r30", "answer": "CONFIRMED", "artifact": "x.sh:1 guard", "num_turns": 5, "cost_usd": 0.1, "subtype": "success", "is_error": false}\n' >> "$tmp/s0/report.jsonl"
o="$(sc "$tmp/s")"; rc=$?; o0="$(sc "$tmp/s0")"; rc0=$?
[ "$rc" = 1 ] && printf '%s' "$o" | grep -q '^replay-gate: fail real=30 .* max-turns=5 .* foreign=0 capped=1$' \
  && [ "$rc0" = 0 ] && printf '%s' "$o0" | grep -q '^replay-gate: pass real=30 .* foreign=0 capped=0$' \
  && ok "(s) an error_max_turns run fails the gate as capped=1, appended after foreign=" || bad "(s) rc=$rc $o / rc0=$rc0 $o0"
~~~

6. file: `tests/refutation-replay-isolation.test.sh`
   anchor: line matching `[ -n "${FAKE_DRAIN:-}" ] && cat > /dev/null`
   before:
~~~
[ -n "${FAKE_DRAIN:-}" ] && cat > /dev/null
~~~
   after:
~~~
~~~

7. file: `tests/refutation-replay-isolation.test.sh`
   anchor: line matching `p="$PROBE/$(ls "$PROBE" | wc -l)"; mkdir -p "$p"`
   before:
~~~
p="$PROBE/$(ls "$PROBE" | wc -l)"; mkdir -p "$p"
~~~
   after:
~~~
p="$PROBE/$(ls "$PROBE" | wc -l)"; mkdir -p "$p"
[ -n "${FAKE_DRAIN:-}" ] && cat > "$p/stdin"
{ : <&3; } 2>/dev/null && echo open > "$p/fd3"
if [ -n "${FAKE_MUTATE:-}" ] && [ ! -e "$FAKE_MUTATE.done" ]; then
  # rewrite the runner in place (same inode), as an editor would while a replay runs
  sz="$(wc -c < "$FAKE_MUTATE")"; yes 'exit 7' | head -c "$((sz + 4096))" > "$FAKE_MUTATE"; : > "$FAKE_MUTATE.done"
fi
~~~

8. file: `tests/refutation-replay-isolation.test.sh`
   anchor: line matching `printf '{"result": "D1: CONFIRMED — q1=a — artifact: src/a.sh:2\\nD2: UNCERTAIN — q1=b — artifact: none", "num_turns": 3, "total_cost_usd": 0.01}\n'`
   before:
~~~
printf '{"result": "D1: CONFIRMED — q1=a — artifact: src/a.sh:2\\nD2: UNCERTAIN — q1=b — artifact: none", "num_turns": 3, "total_cost_usd": 0.01}\n'
~~~
   after:
~~~
if [ -n "${FAKE_SUBTYPE:-}" ]; then
  printf '{"type": "result", "subtype": "%s", "is_error": true, "num_turns": 11, "errors": ["Reached maximum number of turns (10)"], "total_cost_usd": 0.02}\n' "$FAKE_SUBTYPE"
  exit 0
fi
printf '{"type": "result", "subtype": "success", "is_error": false, "result": "D1: CONFIRMED — q1=a — artifact: src/a.sh:2\\nD2: UNCERTAIN — q1=b — artifact: none", "num_turns": 3, "total_cost_usd": 0.01}\n'
~~~

9. file: `tests/refutation-replay-isolation.test.sh`
   anchor: line matching `PATH="$fb:$PATH" PROBE="$pr4" LABELS="$d/labels.tsv" FAKE_DRAIN=1 bash "$d/run.sh" --corpus "$corp3" --repo "$repo" --out "$tmp/r4.jsonl" >"$tmp/r4.out" 2>"$tmp/r4.err"; rc=$?`
   before:
~~~
PATH="$fb:$PATH" PROBE="$pr4" LABELS="$d/labels.tsv" FAKE_DRAIN=1 bash "$d/run.sh" --corpus "$corp3" --repo "$repo" --out "$tmp/r4.jsonl" >"$tmp/r4.out" 2>"$tmp/r4.err"; rc=$?
~~~
   after:
~~~
# rfp-u2f: run.sh's own stdin is a sentinel file, so a claude that is handed it records the sentinel and
# the case fails at once instead of hanging on an open pipe; timeout bounds it anyway.
printf 'SENTINEL\n' > "$tmp/stdin.sentinel"
PATH="$fb:$PATH" PROBE="$pr4" LABELS="$d/labels.tsv" FAKE_DRAIN=1 timeout 60 bash "$d/run.sh" --corpus "$corp3" --repo "$repo" --out "$tmp/r4.jsonl" <"$tmp/stdin.sentinel" >"$tmp/r4.out" 2>"$tmp/r4.err"; rc=$?
~~~

10. file: `tests/refutation-replay-isolation.test.sh`
   anchor: line matching `print(",".join(json.loads(l)["id"] for l in open(sys.argv[1])))' "$tmp/r4.jsonl" 2>/dev/null)"`
   before:
~~~
print(",".join(json.loads(l)["id"] for l in open(sys.argv[1])))' "$tmp/r4.jsonl" 2>/dev/null)"
~~~
   after:
~~~
print(",".join(json.loads(l)["id"] for l in open(sys.argv[1])))' "$tmp/r4.jsonl" 2>/dev/null)"
read4="$(cat "$pr4"/*/stdin 2>/dev/null)"
~~~

11. file: `tests/refutation-replay-isolation.test.sh`
   anchor: line matching `  && ok "(q) a claude that drains standard input still sees all three groups" || bad "(q) rc=$rc ids=$ids4 $(tail -1 "$tmp/r4.out")"`
   before:
~~~
  && ok "(q) a claude that drains standard input still sees all three groups" || bad "(q) rc=$rc ids=$ids4 $(tail -1 "$tmp/r4.out")"
~~~
   after:
~~~
  && [ "$(ls "$pr4"/*/stdin 2>/dev/null | wc -l)" = 3 ] && [ -z "$read4" ] \
  && ok "(q) a claude that drains standard input still sees all three groups and reads nothing" || bad "(q) rc=$rc ids=$ids4 read=$read4 $(tail -1 "$tmp/r4.out")"
[ "$(ls "$pr4"/*/fd3 2>/dev/null | wc -l)" = 0 ] && [ "$(ls "$pr4" | wc -l)" = 3 ] \
  && ok "(u) claude does not inherit run.sh's group stream on fd 3" || bad "(u) fd 3 open in $(ls "$pr4"/*/fd3 2>/dev/null | wc -l) runs"

# rfp-u2f: every row carries the CLI result's subtype and is_error; a run cut off at the turn cap is
# error_max_turns, and a row with no CLI result says none
sub="$(python3 -c 'import json, sys
for l in open(sys.argv[1]):
    r = json.loads(l); print(r["id"], r["answer"], r.get("subtype", "-"), r.get("is_error", "-"), r["num_turns"])' "$rep" 2>/dev/null | tr '\n' ',')"
pr5="$tmp/probe5"; mkdir -p "$pr5"
PATH="$fb:$PATH" PROBE="$pr5" LABELS="$d/labels.tsv" FAKE_SUBTYPE=error_max_turns bash "$d/run.sh" --corpus "$corp" --repo "$repo" --out "$tmp/r5.jsonl" >/dev/null 2>&1 </dev/null; rc=$?
sub5="$(python3 -c 'import json, sys
for l in open(sys.argv[1]):
    r = json.loads(l); print(r["id"], r["answer"], r.get("subtype", "-"), r.get("is_error", "-"), r["num_turns"])' "$tmp/r5.jsonl" 2>/dev/null | tr '\n' ',')"
[ "$sub" = "g1#0 CONFIRMED success False 3,g1#1 UNCERTAIN success False 3,g2#2 NONE none True 0,g3#3 NONE none True 0," ] \
  && [ "$rc" = 0 ] && [ "$sub5" = "g1#0 NONE error_max_turns True 11,g1#1 NONE error_max_turns True 11,g2#2 NONE none True 0,g3#3 NONE none True 0," ] \
  && ok "(r) report rows carry the CLI result's subtype and is_error" || bad "(r) rows: $sub / rc=$rc $sub5"

# rfp-u2f: run.sh is parsed whole before it runs, so rewriting it during a replay changes nothing
rr="$tmp/rr"; mkdir -p "$rr/eval/refutation-replay" "$rr/bin"
cp -p "$d/run.sh" "$d/guard.py" "$rr/eval/refutation-replay/"; cp -p "$root/bin/refutation-brief.sh" "$rr/bin/"
pr6="$tmp/probe6"; mkdir -p "$pr6"
PATH="$fb:$PATH" PROBE="$pr6" LABELS="$d/labels.tsv" FAKE_MUTATE="$rr/eval/refutation-replay/run.sh" timeout 60 bash "$rr/eval/refutation-replay/run.sh" --corpus "$corp3" --repo "$repo" --out "$tmp/r6.jsonl" >"$tmp/r6.out" 2>"$tmp/r6.err" </dev/null; rc=$?
[ "$rc" = 0 ] && [ -e "$rr/eval/refutation-replay/run.sh.done" ] && grep -q ' groups=3 ' "$tmp/r6.out" && [ "$(grep -c . "$tmp/r6.jsonl")" = 3 ] && [ ! -s "$tmp/r6.err" ] \
  && ok "(t) rewriting run.sh during a replay does not change the running replay" || bad "(t) rc=$rc $(tail -1 "$tmp/r6.out") $(head -c 200 "$tmp/r6.err")"
~~~

12. file: `tests/refutation-replay-isolation.test.sh`
   anchor: line matching `  && ok "(p) the builder docstring and README state the $cut-character claim cut, and no diffstat" || bad "(p) cut=$cut"`
   before:
~~~
  && ok "(p) the builder docstring and README state the $cut-character claim cut, and no diffstat" || bad "(p) cut=$cut"

~~~
   after:
~~~
  && ok "(p) the builder docstring and README state the $cut-character claim cut, and no diffstat" || bad "(p) cut=$cut"

# rfp-u2f: the README states the capped rule with the subtype score.py actually counts
st="$(grep -oE "r\.get\('subtype'\) == '[a-z_]+'" "$d/score.py" | grep -oE "'[a-z_]+'$" | tr -d "'")"
[ -n "$st" ] && grep -qF 'needs all five of the following' "$d/README.md" && grep -qF "(\`capped=0\`: no row's \`subtype\` is \`$st\`)" "$d/README.md" \
  && ok "(v) README states the capped rule with score.py's subtype ($st)" || bad "(v) README does not state capped=0 for subtype '$st'"

~~~

   **Red step.** Run `bash tests/refutation-replay.test.sh` and `bash tests/refutation-replay-isolation.test.sh < /dev/null`.
   Both must exit 1. The first prints `FAIL` for cases (k), (l) and (m) only. The second prints `FAIL` for
   (e), (s), (u), (r), (t) and (v) only. Case (q) stays green here, because 2bf3ac51's `run.sh` already has
   ` < /dev/null`; its proof is mutation (ii) of criterion 1.


13. file: `eval/refutation-replay/build-corpus.py`
   anchor: line matching `(every label `unknown`; a human sets real|bogus, Gate G1). A claim is whitespace-collapsed and cut at`
   before:
~~~
(every label `unknown`; a human sets real|bogus, Gate G1). A claim is whitespace-collapsed and cut at
300 characters; its cited <path>:<line> is kept whole.
~~~
   after:
~~~
(every label `unknown`; a human sets real|bogus, Gate G1). A claim is the whole defect item (rfp-u2f): the
bullet line plus every indented line after it, across blank lines, up to the next bullet or unindented line,
whitespace-collapsed and cut at 8000 characters; its cited <path>:<line> is kept whole. No committed claim
reaches that cut, which keeps a 3-defect brief far below Linux's 128 KiB limit on one argv string. Which
defects are kept still depends on the bullet line alone.
~~~

14. file: `eval/refutation-replay/build-corpus.py`
   anchor: line matching `--labels: print the human labelling checklist (the claim, then the fix commit's short hash and subject).`
   before:
~~~
--labels: print the human labelling checklist (the claim, then the fix commit's short hash and subject).
~~~
   after:
~~~
--labels: print the human labelling checklist (the claim, then the fix commit's short hash and subject).
--refresh-claims: rewrite the `dline` of each row of --out with its whole claim from the FAIL block it came
from, keeping every other field, the row order and labels.tsv; a row whose defect is not found exactly once
is an error, and then nothing is written (exit 1).
~~~

15. file: `eval/refutation-replay/build-corpus.py`
   anchor: line matching `HERE = os.path.dirname(os.path.abspath(__file__))`
   before:
~~~
HERE = os.path.dirname(os.path.abspath(__file__))
~~~
   after:
~~~
HERE = os.path.dirname(os.path.abspath(__file__))


def items(lines):
    """Yield (bullet line, whole item text) for each column-0 bullet: the bullet line plus every indented
    line after it, across blank lines, up to the next bullet or unindented line."""
    i = 0
    while i < len(lines):
        if not BULLET.match(lines[i]):
            i += 1
            continue
        parts, j = [lines[i]], i + 1
        while j < len(lines) and not BULLET.match(lines[j]):
            k = j
            while k < len(lines) and not lines[k].strip():
                k += 1
            if k == len(lines) or not lines[k][:1].isspace():
                break
            parts.extend(lines[j:k + 1])
            j = k + 1
        yield lines[i], ' '.join(parts)
        i = j


def claim_text(item, cite):
    claim = re.sub(r'\s+', ' ', BULLET.sub('', item)).strip()
    if claim.startswith(cite):
        claim = claim[len(cite):].lstrip(' :')
    return claim[:8000] or '(no claim text)'
~~~

16. file: `eval/refutation-replay/build-corpus.py`
   anchor: line matching `        defects = [l for l in b['lines'] if BULLET.match(l) and not MECH.search(l)]`
   before:
~~~
        defects = [l for l in b['lines'] if BULLET.match(l) and not MECH.search(l)]
~~~
   after:
~~~
        defects = [(l, item) for l, item in items(b['lines']) if not MECH.search(l)]
~~~

17. file: `eval/refutation-replay/build-corpus.py`
   anchor: line matching `        for d in defects:`
   before:
~~~
        for d in defects:
~~~
   after:
~~~
        for d, item in defects:
~~~

18. file: `eval/refutation-replay/build-corpus.py`
   anchor: line matching `            claim = re.sub(r'\s+', ' ', BULLET.sub('', d)).strip()`
   before:
~~~
            claim = re.sub(r'\s+', ' ', BULLET.sub('', d)).strip()
            if claim.startswith(cite):
                claim = claim[len(cite):].lstrip(' :')
            group.append({'cite': cite, 'claim': claim[:300] or '(no claim text)', 'fix_commit': fix.split('\n')[-1]})
~~~
   after:
~~~
            group.append({'cite': cite, 'claim': claim_text(item, cite), 'fix_commit': fix.split('\n')[-1]})
~~~

19. file: `eval/refutation-replay/build-corpus.py`
   anchor: line matching `    return 1 if errs else 0`
   before:
~~~
    return 1 if errs else 0


~~~
   after:
~~~
    return 1 if errs else 0


def refresh(a):
    rows = [json.loads(l) for l in open(a.out) if l.strip()]
    found = {}
    for b in blocks(a.markers):
        found.setdefault((b['unit'], b['ts']), b['lines'])
    errs, longer = [], 0
    for r in rows:
        m = re.match(r'^(D[1-3]): (\S+) (.*)$', r.get('dline', ''))
        if not m:
            errs.append('%s: bad dline' % r.get('id'))
            continue
        cite, old = m.group(2), m.group(3)
        old = '' if old == '(no claim text)' else old
        hits = []
        for line, item in items(found.get((r.get('unit'), r.get('fail_ts')), [])):
            c = CITE.search(line)
            if c and not MECH.search(line) and '%s:%s' % (c.group(1), c.group(2)) == cite:
                whole = claim_text(item, cite)
                if whole.startswith(old):
                    hits.append(whole)
        if len(hits) != 1:
            errs.append('%s: %d matching defects in its FAIL block' % (r.get('id'), len(hits)))
            continue
        dline = '%s: %s %s' % (m.group(1), cite, hits[0])
        longer += dline != r['dline']
        r['dline'] = dline
    print('corpus: refreshed rows=%d longer=%d errors=%d' % (len(rows), 0 if errs else longer, len(errs)))
    for e in errs[:20]:
        print('  error: ' + e)
    if errs:
        return 1
    with open(a.out, 'w') as f:
        for r in rows:
            f.write(json.dumps(r, sort_keys=True) + '\n')
    return 0


~~~

20. file: `eval/refutation-replay/build-corpus.py`
   anchor: line matching `    p.add_argument('--labels', action='store_true')`
   before:
~~~
    p.add_argument('--labels', action='store_true')
~~~
   after:
~~~
    p.add_argument('--labels', action='store_true')
    p.add_argument('--refresh-claims', action='store_true')
~~~

21. file: `eval/refutation-replay/build-corpus.py`
   anchor: line matching `        sys.exit(checklist(a))`
   before:
~~~
        sys.exit(checklist(a))
~~~
   after:
~~~
        sys.exit(checklist(a))
    if a.refresh_claims:
        sys.exit(refresh(a))
~~~

22. file: `eval/refutation-replay/score.py`
   anchor: line matching `"""Score a refutation replay (rfp-u2; per-id scoring rfp-u2b). Usage: score.py <report.jsonl> [--gate] [--labels <labels.tsv>]`
   before:
~~~
"""Score a refutation replay (rfp-u2; per-id scoring rfp-u2b). Usage: score.py <report.jsonl> [--gate] [--labels <labels.tsv>]
~~~
   after:
~~~
"""Score a refutation replay (rfp-u2; per-id scoring rfp-u2b; capped runs rfp-u2f). Usage: score.py <report.jsonl> [--gate] [--labels <labels.tsv>]
~~~

23. file: `eval/refutation-replay/score.py`
   anchor: line matching `A report row is {"id", "answer": REFUTED|CONFIRMED|UNCERTAIN|NONE, "artifact", "num_turns", "cost_usd"}.`
   before:
~~~
A report row is {"id", "answer": REFUTED|CONFIRMED|UNCERTAIN|NONE, "artifact", "num_turns", "cost_usd"}.
~~~
   after:
~~~
A report row is {"id", "answer": REFUTED|CONFIRMED|UNCERTAIN|NONE, "artifact", "num_turns", "cost_usd",
"subtype", "is_error"}; `subtype` and `is_error` are the CLI result's own fields (run.sh, rfp-u2f).
~~~

24. file: `eval/refutation-replay/score.py`
   anchor: line matching `  dup-conflict=<d> foreign=<f>`
   before:
~~~
  dup-conflict=<d> foreign=<f>
~~~
   after:
~~~
  dup-conflict=<d> foreign=<f> capped=<p>
capped counts the scored ids whose run ended `error_max_turns` (the CLI's --max-turns cap). A row with no
`subtype` (a report written before rfp-u2f) is not counted.
~~~

25. file: `eval/refutation-replay/score.py`
   anchor: line matching `max-turns <= MAX_TURNS and dup-conflict = 0. Anything else is fail. Without --gate it always exits 0.`
   before:
~~~
max-turns <= MAX_TURNS and dup-conflict = 0. Anything else is fail. Without --gate it always exits 0.
~~~
   after:
~~~
max-turns <= MAX_TURNS, dup-conflict = 0 and capped = 0. Anything else is fail. Without --gate it always exits 0.
~~~

26. file: `eval/refutation-replay/score.py`
   anchor: line matching `    max_turns = max(turns) if turns else 0`
   before:
~~~
    max_turns = max(turns) if turns else 0
~~~
   after:
~~~
    max_turns = max(turns) if turns else 0
    capped = sum(1 for r in scored if r.get('subtype') == 'error_max_turns')
~~~

27. file: `eval/refutation-replay/score.py`
   anchor: line matching `          and not conflict):`
   before:
~~~
          and not conflict):
~~~
   after:
~~~
          and not conflict and not capped):
~~~

28. file: `eval/refutation-replay/score.py`
   anchor: line matching `          'refuted-bogus=%d max-turns=%d mean-cost-usd=%.3f missing=%d dup-conflict=%d foreign=%d' % (`
   before:
~~~
          'refuted-bogus=%d max-turns=%d mean-cost-usd=%.3f missing=%d dup-conflict=%d foreign=%d' % (
~~~
   after:
~~~
          'refuted-bogus=%d max-turns=%d mean-cost-usd=%.3f missing=%d dup-conflict=%d foreign=%d capped=%d' % (
~~~

29. file: `eval/refutation-replay/score.py`
   anchor: line matching `              missing, len(conflict), len(foreign)))`
   before:
~~~
              missing, len(conflict), len(foreign)))
~~~
   after:
~~~
              missing, len(conflict), len(foreign), capped))
~~~

30. file: `eval/refutation-replay/run.sh`
   anchor: line matching `# one NONE row per defect, so the scorer counts it as unanswered.`
   before:
~~~
# one NONE row per defect, so the scorer counts it as unanswered.
~~~
   after:
~~~
# one NONE row per defect, so the scorer counts it as unanswered. Every row also carries the CLI result's
# `subtype` and `is_error` (rfp-u2f): a run cut off at the turn cap is `error_max_turns`; a row with no
# CLI result says `none`.
~~~

31. file: `eval/refutation-replay/run.sh`
   anchor: line matching `# A real run spends API budget (each run capped by --max-budget-usd 1). The human runs it (Gate G2).`
   before:
~~~
# A real run spends API budget (each run capped by --max-budget-usd 1). The human runs it (Gate G2).
~~~
   after:
~~~
# A real run spends API budget (each run capped by --max-budget-usd 1). The human runs it (Gate G2).
# The body is one function, called on the last line (rfp-u2f): bash parses all of it before running any
# of it, so an edit to this file while a replay runs cannot change that replay.
~~~

32. file: `eval/refutation-replay/run.sh`
   anchor: line matching `set -uo pipefail`
   before:
~~~
set -uo pipefail
~~~
   after:
~~~
set -uo pipefail
main() {
~~~

33. file: `eval/refutation-replay/run.sh`
   anchor: line matching `    print(json.dumps({"id": i, "answer": "NONE", "artifact": "", "num_turns": 0, "cost_usd": 0, "setup": sys.argv[2]}, sort_keys=True))' "$1" "$2" >> "$out"`
   before:
~~~
    print(json.dumps({"id": i, "answer": "NONE", "artifact": "", "num_turns": 0, "cost_usd": 0, "setup": sys.argv[2]}, sort_keys=True))' "$1" "$2" >> "$out"
~~~
   after:
~~~
    print(json.dumps({"id": i, "answer": "NONE", "artifact": "", "num_turns": 0, "cost_usd": 0, "setup": sys.argv[2],
                  "subtype": "none", "is_error": True}, sort_keys=True))' "$1" "$2" >> "$out"
~~~

34. file: `eval/refutation-replay/run.sh`
   anchor: line matching `  ( cd "$wt" && claude -p "$prompt" "${CLAUDE_FLAGS[@]}" --settings "$work/$n.settings.json" < /dev/null ) > "$work/$n.json" 2> "$work/$n.err"`
   before:
~~~
  ( cd "$wt" && claude -p "$prompt" "${CLAUDE_FLAGS[@]}" --settings "$work/$n.settings.json" < /dev/null ) > "$work/$n.json" 2> "$work/$n.err"
~~~
   after:
~~~
  ( cd "$wt" && claude -p "$prompt" "${CLAUDE_FLAGS[@]}" --settings "$work/$n.settings.json" < /dev/null 3<&- ) > "$work/$n.json" 2> "$work/$n.err"
~~~

35. file: `eval/refutation-replay/run.sh`
   anchor: line matching `        ans[m.group(1)] = (m.group(2), art.group(1).strip() if art else '')`
   before:
~~~
        ans[m.group(1)] = (m.group(2), art.group(1).strip() if art else '')
~~~
   after:
~~~
        ans[m.group(1)] = (m.group(2), art.group(1).strip() if art else '')
sub = res.get('subtype') if isinstance(res.get('subtype'), str) and res.get('subtype') else 'none'
err = bool(res.get('is_error')) if res else True
~~~

36. file: `eval/refutation-replay/run.sh`
   anchor: line matching `                      'cost_usd': res.get('total_cost_usd', 0)}, sort_keys=True))`
   before:
~~~
                      'cost_usd': res.get('total_cost_usd', 0)}, sort_keys=True))
~~~
   after:
~~~
                      'cost_usd': res.get('total_cost_usd', 0), 'subtype': sub, 'is_error': err}, sort_keys=True))
~~~

37. file: `eval/refutation-replay/run.sh`
   anchor: line matching `echo "run.sh: groups=$n dry-run=$dry out=$( [ "$dry" = 1 ] && echo none || echo "$out")"`
   before:
~~~
echo "run.sh: groups=$n dry-run=$dry out=$( [ "$dry" = 1 ] && echo none || echo "$out")"
~~~
   after:
~~~
echo "run.sh: groups=$n dry-run=$dry out=$( [ "$dry" = 1 ] && echo none || echo "$out")"
}
main "$@"; exit
~~~

38. file: `eval/refutation-replay/README.md`
   anchor: line matching `| `report.jsonl` | `run.sh`, committed by the human | one row per defect: the answer, the artifact, the turns, the cost |`
   before:
~~~
| `report.jsonl` | `run.sh`, committed by the human | one row per defect: the answer, the artifact, the turns, the cost |
~~~
   after:
~~~
| `report.jsonl` | `run.sh`, committed by the human | one row per defect: the answer, the artifact, the turns, the cost, and the CLI result's `subtype` and `is_error` |
~~~

39. file: `eval/refutation-replay/README.md`
   anchor: line matching `   start. Commit `report.jsonl`.`
   before:
~~~
   start. Commit `report.jsonl`.
~~~
   after:
~~~
   start. `run.sh` parses its whole body before it runs, so an edit to the file during a replay does not
   change that replay; still, do not edit it while one runs. Commit `report.jsonl`.
~~~

40. file: `eval/refutation-replay/README.md`
   anchor: line matching `- **pass** needs all four of the following:`
   before:
~~~
- **pass** needs all four of the following:
~~~
   after:
~~~
- **pass** needs all five of the following:
~~~

41. file: `eval/refutation-replay/README.md`
   anchor: line matching `  - no run exceeded 10 turns.`
   before:
~~~
  - no run exceeded 10 turns.
~~~
   after:
~~~
  - no run exceeded 10 turns (`max-turns`, the CLI's `num_turns`: on a finished run, 1 plus its tool calls);
  - no run was cut off at the turn cap (`capped=0`: no row's `subtype` is `error_max_turns`).
- A run cut off at the cap also reports `num_turns` 11, so the turn rule fails it too; `capped` names the
  cause. A report written before rfp-u2f has no `subtype`, so it always shows `capped=0`.
~~~

42. file: `eval/refutation-replay/README.md`
   anchor: line matching `- A claim is whitespace-collapsed and cut at 300 characters when the corpus is built; its cited`
   before:
~~~
- A claim is whitespace-collapsed and cut at 300 characters when the corpus is built; its cited
  `<path>:<line>` is kept whole. The live reviewer writes its own defect lines, with no cut.
~~~
   after:
~~~
- A claim is the whole defect item: its bullet line plus every indented line after it, across blank lines,
  up to the next bullet or unindented line, whitespace-collapsed and cut at 8000 characters. No committed
  claim reaches the cut. Its cited `<path>:<line>` is kept whole. The live reviewer writes its own defect
  lines, with no cut. Which defects are kept still depends on the bullet line alone.
- `build-corpus.py --refresh-claims` rewrites the claims of the committed corpus from the FAIL records
  without selecting again, so the ids, the rows' other fields and `labels.tsv` stay as they are. A rebuild
  would select again from today's FAIL records and change the ids.
~~~
43. command: `python3 eval/refutation-replay/build-corpus.py --refresh-claims`
    expect: 0
    stdout: `corpus: refreshed rows=41 longer=40 errors=0`
    Run it from the main checkout's root. It reads the FAIL records through the builder's default
    `--markers`, the untracked per-clone review directory, so it cannot work in a linked worktree or a clone.
    Never name that directory in a command (hook constraint). It rewrites `corpus.jsonl` only; it never
    writes `labels.tsv`. Then run `python3 eval/refutation-replay/build-corpus.py --check`, which must print
    `corpus: rows=41 groups=24 units=24 unlabeled=0 real=41 bogus=0 errors=0`. In spec-master's run, the
    regenerated file's sha256 was `1072a1974abc78a208daa95f1f59df3d22cf7d8d594835b75a8f08095c46b439`. Never
    run the builder without `--refresh-claims` or `--check` (its build mode re-selects defects and rewrites
    `labels.tsv` to all `unknown`).
44. command: `git add eval/refutation-replay/README.md eval/refutation-replay/build-corpus.py eval/refutation-replay/corpus.jsonl eval/refutation-replay/run.sh eval/refutation-replay/score.py tests/refutation-replay.test.sh tests/refutation-replay-isolation.test.sh && git commit -m "fix(rfp-u2f): replay records the CLI subtype and fails the gate on a capped run; corpus keeps whole claims; run.sh parses whole before running"`
    expect: 0
    Run `git status --short` first. If a tracked file outside "Affected files" is modified, stop and report
    it. Stage by explicit path only, never `git add -A` or `git add .`. The untracked
    `eval/refutation-replay/report.jsonl` is the human's. Keep `(rfp-u2f)` in every fix-round commit subject.

## Do NOT touch
- `eval/refutation-replay/labels.tsv`: the human's Gate G1 labels (criterion 5 checks its committed hash).
- `eval/refutation-replay/report.jsonl`: the human's untracked run data. Never read, edit, stage, delete or
  commit it.
- `bin/refutation-brief.sh` and `tests/refutation-brief.test.sh` (rfp-u1b's unit, PASS at 4ec89dae).
- `eval/refutation-replay/guard.py`.
- The label server: `eval/refutation-replay/label.py`, `eval/refutation-replay/label_page.html`,
  `tests/refutation-label.test.sh`, `tests/refutation-label-server.py` and `tests/refutation-label-browser.js`.
- `agents/`, `templates/`, `hooks/`, `adapters/`, `.claude/`, `tests/validate.sh`, `.claude-plugin/plugin.json`,
  `package.json` and `CHANGELOG.md` (criterion 9).
- In `score.py`, the line `MIN_REAL, MAX_MISSES, MAX_TURNS, MAX_UNANSWERED = 30, 1, 10, 0.20`. In `run.sh`, the
  `CLAUDE_FLAGS=(…)` array (criteria 7 and 8).
- The order of the existing `replay-gate:` fields: `capped=` is appended after `foreign=` (criterion 6).

## Acceptance criteria
Every expected stdout is a single line. No criterion names the reviewed-markers directory or the persona
config file, and none uses `rm -rf`: each scratch directory comes from its own `mktemp -d` and is left in
place.
1. run: `bash -c 'bash tests/refutation-replay.test.sh >/dev/null 2>&1; a=$?; bash tests/refutation-replay-isolation.test.sh >/dev/null 2>&1 </dev/null; echo "$a $?"'`
   exit: 0
   stdout: `0 0`
   mutation: each of these, applied alone, turns the named cases red. spec-master ran them all on a scratch clone. (i) In `score.py`, ` and not conflict and not capped):` becomes ` and not conflict):`: case s, stdout `0 1`. (ii) In `run.sh`, delete ` < /dev/null` (mutant C of rfp-u2e): case q, with no hang, and this holds even when the suite's own stdin is an open pipe. (iii) Delete ` 3<&-`: case u. (iv) Delete the lines `main() {` and `}` + `main "$@"; exit`: case t. (v) Drop `, 'subtype': sub, 'is_error': err` from the row dict: case r. (vi) Delete `"subtype": "none", ` from `none_rows`: case r. (vii) In `build-corpus.py`, `MECH.search(l)]` becomes `MECH.search(item)]`: cases k and l, stdout `1 0`. (viii) Make `items()` stop at a blank line (`if k > j or k == len(lines) or …`): case k. (ix) `claim[:8000]` becomes `claim[:300]`: cases k and p, stdout `1 1`. (x) Delete `    if errs:` + `        return 1` in `refresh()`: case m. (xi) Swap `foreign=%d capped=%d` to `capped=%d foreign=%d`: cases e and s. (xii) In the README, write `error_max_budget_usd` for `error_max_turns` in the capped bullet: case v.
2. run: `bash -c 'b=$(git log --format=%H --fixed-strings --grep="(rfp-u2f)" | tail -1); [ -n "$b" ] || { echo no-commits; exit 1; }; t=$(mktemp -d); mkdir -p "$t/eval/refutation-replay" "$t/bin" "$t/tests"; for f in $(git ls-tree --name-only "$b^" eval/refutation-replay/) bin/refutation-brief.sh; do git show "$b^:$f" > "$t/$f"; done; cp tests/refutation-replay.test.sh tests/refutation-replay-isolation.test.sh "$t/tests/"; x=$(bash "$t/tests/refutation-replay.test.sh" 2>/dev/null | sed -n "s/^FAIL (\([a-z0-9]*\)).*/\1/p" | sort | paste -sd, -); y=$(bash "$t/tests/refutation-replay-isolation.test.sh" 2>/dev/null </dev/null | sed -n "s/^FAIL (\([a-z0-9]*\)).*/\1/p" | sort | paste -sd, -); echo "replay=$x isolation=$y"'`
   exit: 0
   stdout: `replay=k,l,m isolation=e,r,s,t,u,v`
   mutation: weaken a new case so that it also passes on the pre-unit files, for example make case (k)'s condition `if true`. Its letter drops out and stdout is `replay=l,m isolation=e,r,s,t,u,v` (spec-master ran this). Case (q) is absent on purpose: the pre-unit `run.sh` already has ` < /dev/null`, so (q)'s proof is mutation (ii) of criterion 1. On a tree with no `(rfp-u2f)` commit, stdout is `no-commits` and the exit is 1 (spec-master ran it on the real tree).
3. run: `bash -c 'b=$(git log --format=%H --fixed-strings --grep="(rfp-u2f)" | tail -1); [ -n "$b" ] || { echo no-commits; exit 1; }; t=$(mktemp -d); git show "$b^:eval/refutation-replay/corpus.jsonl" > "$t/old.jsonl"; python3 -c "import json, sys; o, n = ([json.loads(l) for l in open(p)] for p in sys.argv[1:3]); k = sys.argv[3]; r = lambda x: {a: v for a, v in x.items() if a != k}; print(\"rows=%d/%d same-ids=%d same-fields=%d extended=%d longer=%d\" % (len(o), len(n), sum(a[\"id\"] == b[\"id\"] for a, b in zip(o, n)), sum(r(a) == r(b) for a, b in zip(o, n)), sum(b[k].startswith(a[k]) for a, b in zip(o, n)), sum(len(b[k]) > len(a[k]) for a, b in zip(o, n))))" "$t/old.jsonl" eval/refutation-replay/corpus.jsonl dline'`
   exit: 0
   stdout: `rows=41/41 same-ids=41 same-fields=41 extended=41 longer=40`
   mutation: regenerate the corpus with `claim[:300]` in the builder; stdout ends `longer=7` (spec-master ran this). A full rebuild instead of `--refresh-claims` gives 40 rows and different ids. On an empty range, stdout is `no-commits` and the exit is 1.
4. run: `bash -c 'b=$(git log --format=%H --fixed-strings --grep="(rfp-u2f)" | tail -1); [ -n "$b" ] || { echo no-commits; exit 1; }; t=$(mktemp -d); git show "$b^:eval/refutation-replay/corpus.jsonl" > "$t/corpus.jsonl"; python3 eval/refutation-replay/build-corpus.py --out "$t/corpus.jsonl" --refresh-claims >/dev/null && cmp -s "$t/corpus.jsonl" eval/refutation-replay/corpus.jsonl && test ! -e "$t/labels.tsv" && echo same || echo differ'`
   exit: 0
   stdout: `same`
   mutation: hand-edit one claim in the committed `corpus.jsonl`; stdout is `differ` (spec-master ran this). It proves that the committed corpus is exactly what `--refresh-claims` makes from the FAIL records, and that refreshing writes no `labels.tsv`. Run it from the main checkout's root, as edit 43. On an empty range, stdout is `no-commits` and the exit is 1.
5. run: `bash -c 'b=$(git log --format=%H --fixed-strings --grep="(rfp-u2f)" | tail -1); [ -n "$b" ] || { echo no-commits; exit 1; }; h=$(git show HEAD:eval/refutation-replay/labels.tsv | sha256sum | cut -c1-64); n=$(git diff --name-only "$b^" HEAD -- eval/refutation-replay/labels.tsv | wc -l); w=$(git status --porcelain -- eval/refutation-replay/labels.tsv | wc -l); echo "$h changed=$n dirty=$w $(python3 eval/refutation-replay/build-corpus.py --check | head -1)"'`
   exit: 0
   stdout: `4efa7b128e8d9bc146610afe2116bee4b3f8cae5072070bdaf931bd527addd67 changed=0 dirty=0 corpus: rows=41 groups=24 units=24 unlabeled=0 real=41 bogus=0 errors=0`
   mutation: commit a `labels.tsv` written by the builder's build mode in an `(rfp-u2f)` commit; stdout is `a5f3912a… changed=1 dirty=0 corpus: rows=41 groups=24 units=24 unlabeled=37 real=0 bogus=0 errors=5` (spec-master ran this). On an empty range, stdout is `no-commits` and the exit is 1.
6. run: `bash -c 't=$(mktemp -d); : > "$t/report.jsonl"; : > "$t/labels.tsv"; o=$(python3 eval/refutation-replay/score.py "$t/report.jsonl" --labels "$t/labels.tsv" --gate); rc=$?; echo "$(printf "%s" "$o" | sed "s/=[^ ]*//g") rc=$rc"'`
   exit: 0
   stdout: `replay-gate: insufficient real refuted-real confirmed-real uncertain-real unanswered bogus refuted-bogus max-turns mean-cost-usd missing dup-conflict foreign capped rc=2`
   mutation: print `capped=` before `foreign=`; the last two names swap and stdout differs (spec-master ran this). This shows the existing fields keep their order, so rfp-u3 criterion 8's `cut -d" " -f1-2` still reads `replay-gate: <verdict>`.
7. run: `bash -c 'grep -qxF "MIN_REAL, MAX_MISSES, MAX_TURNS, MAX_UNANSWERED = 30, 1, 10, 0.20" eval/refutation-replay/score.py && grep -qF "CLAUDE_FLAGS=(--model sonnet --max-turns 10 --output-format json --no-session-persistence" eval/refutation-replay/run.sh && grep -qF "  --max-budget-usd 1 --setting-sources local --strict-mcp-config --permission-mode dontAsk" eval/refutation-replay/run.sh && echo thresholds-same || echo changed'`
   exit: 0
   stdout: `thresholds-same`
   mutation: set `MAX_TURNS` to 11; stdout is `changed` (spec-master ran this).
8. run: `bash -c 'b=$(git log --format=%H --fixed-strings --grep="(rfp-u2f)" | tail -1); [ -n "$b" ] || { echo no-commits; exit 1; }; t=$(mktemp -d); mkdir -p "$t/eval/refutation-replay" "$t/bin"; git show "$b^:eval/refutation-replay/run.sh" > "$t/eval/refutation-replay/run.sh"; git show "$b^:eval/refutation-replay/corpus.jsonl" > "$t/corpus.jsonl"; cp bin/refutation-brief.sh "$t/bin/"; o=$(bash "$t/eval/refutation-replay/run.sh" --dry-run --corpus "$t/corpus.jsonl"); n=$(bash eval/refutation-replay/run.sh --dry-run); [ "$o" = "$n" ] && [ "$(printf "%s\n" "$n" | grep -c "^group=")" = 24 ] && echo same || echo differ'`
   exit: 0
   stdout: `same`
   mutation: change `--max-turns 10` to `--max-turns 9` in `run.sh`; stdout is `differ` (spec-master ran this). The dry-run of the new `run.sh` on the new corpus matches the pre-unit `run.sh` on the pre-unit corpus line for line, so run 2 replays the same 24 groups with the same flags. On an empty range, stdout is `no-commits` and the exit is 1.
9. run: `bash -c 'c=$(git log --format=%H --fixed-strings --grep="(rfp-u2f)"); [ -n "$c" ] || { echo no-commits; exit 1; }; for x in $c; do git show --name-only --format= "$x"; done | sort -u | grep -vxE "eval/refutation-replay/(README\.md|build-corpus\.py|corpus\.jsonl|run\.sh|score\.py)|tests/refutation-replay(-isolation)?\.test\.sh" | wc -l'`
   exit: 0
   stdout: `0`
   mutation: change `labels.tsv`, `bin/refutation-brief.sh` or `guard.py` in an `(rfp-u2f)` commit; stdout is `1` (spec-master ran the `labels.tsv` case). Only this unit's commits are read, and on an empty range stdout is `no-commits` with exit 1.
10. run: `bash -c 'git ls-files -s eval/refutation-replay/build-corpus.py eval/refutation-replay/run.sh eval/refutation-replay/score.py tests/refutation-replay.test.sh tests/refutation-replay-isolation.test.sh | cut -c1-6 | paste -sd, -'`
    exit: 0
    stdout: `100755,100755,100755,100755,100755`
    mutation: commit `run.sh` at mode 644; the second field reads `100644` (spec-master ran this).
11. run: `bash -c 'ANTISLOP_VALIDATE_LANES=4 bash tests/validate.sh >/dev/null 2>&1; echo $?'` (Bash tool timeout 600000 ms)
    exit: 0
    stdout: `0`
    mutation: put `exit 1` as line 2 of `tests/refutation-replay.test.sh`; validate.sh's rfp-u2 block (`tests/validate.sh:833-838`) sets `fail=1` and stdout is `1`. spec-master ran the 4-lane payload in a scratch clone: exit 0 in 365 s.
12. run: `bash -c 'git status --porcelain --untracked-files=all -- eval/refutation-replay tests/refutation-replay.test.sh tests/refutation-replay-isolation.test.sh | grep -vxF "?? eval/refutation-replay/report.jsonl" | wc -l'`
    exit: 0
    stdout: `0`
    mutation: leave the edit-12 test change uncommitted, or leave an `eval/refutation-replay/__pycache__/` behind; stdout is at least `1`. The human's untracked `report.jsonl` is excluded by name and never read.

## Pre-resolved context
- **What a capped run looks like.** spec-master read the result builder in the installed Claude Code 2.1.312
  bundle (no model run). `--output-format json` prints one object with `type: "result"`, `subtype`,
  `is_error`, `num_turns`, `total_cost_usd`, `stop_reason` and `terminal_reason`.
  - A finished run is `subtype: "success"` with `result` text. `is_error` is false unless an API error
    ended it.
  - The turn cap gives `subtype: "error_max_turns"`, `is_error: true`, `num_turns` = the loop's turn count
    (11 under `--max-turns 10`), `errors: ["Reached maximum number of turns (10)"]` and no `result`.
  - `error_max_budget_usd` (the `--max-budget-usd 1` cap) and `error_during_execution` are the other two
    error subtypes. Both are recorded on the row; neither counts in `capped` (Open Question 4 (a) named only
    the turn cap). Plan "Out of scope" 9 names this as a follow-up.
  - So a capped run already fails the turn rule (`max-turns=11`). `capped` names the cause, and it keeps
    the check if the cap or `MAX_TURNS` ever changes. A report from before this unit (run 1) has no
    `subtype`, so it shows `capped=0`. Run 1's copy scores `… foreign=0 capped=0`, exit 1.
- **Why `capped=` goes last.** rfp-u3 criterion 8 reads `cut -d" " -f1-2`, and the suites grep fixed field
  runs. Only isolation case (e) anchored on the last field (`foreign=100$`). Edit 4 changes it to
  `foreign=100 capped=0$`, which also pins the new field's place.
- **The claim rule, and why.**
  - Live, the reviewer pipes one `D<n>: <file:line> <claim>` line per defect into the brief (rfp-u3 contract,
    reviewer bullet). The claim is its own defect as written in its verdict, and the FAIL record keeps the
    defect list verbatim. So the faithful replay claim is the whole defect item, joined into one line. The
    brief reads each line with `read -r` and matches `.+$`, so it has no line or input length limit.
  - Against the 41 committed rows: 40 claims get longer, and one (gh315 D3) was already whole. The longest
    `dline` is 1,915 characters, against 372 before.
  - Only gh-303 D1 depends on crossing blank lines: 315 characters if the item stops at a blank line, 1,483
    if it does not. Its later paragraphs are its Mechanism and Reproduce text, and gh-303 is one of the 7
    UNCERTAIN rows that named the clipped claim (plan diagnosis 3). So the rule crosses blank lines.
  - `run.sh` passes the brief as one argument to `claude -p`, and Linux caps one argument at 128 KiB
    (MAX_ARG_STRLEN). The 8000-character cut keeps a 3-defect brief near 27 KB at worst. With rfp-u1b's
    brief (4ec89dae), spec-master built all 24 run-2 briefs from the regenerated corpus in fresh clones:
    every one exits 0, and the largest is 4,710 bytes (abt-u10; abt-u12 is 4,117 bytes, against 2,972
    before).
- **Why `--refresh-claims` and not a rebuild.** spec-master rebuilt the corpus into a scratch file at
  today's FAIL records: 58 candidates (57 when it was built), 40 rows and different ids. The build mode also
  writes `labels.tsv` with every label `unknown`, which would erase the human's G1 labels. Refresh finds each
  row's block by `(unit, fail_ts)`, and a defect in it by the cited `<path>:<line>` plus a whole claim that
  starts with the row's current claim. It needs exactly one match, or it fails and writes nothing. It is
  idempotent: a second refresh prints `longer=0` and changes no byte. The new builder's selection equals the
  old one's: spec-master ran both on today's records, with the same 40 ids, and every new claim begins with
  the old one.
- **The stray stderr line of run 1** (rfp-u2e PASS note): the human's run started before 2bf3ac51, while a
  lead's in-place mutant of `run.sh` was on disk. The lead then restored the file in place, 12 bytes longer.
  bash had parsed the whole `while … done 3<<< "$groups"` loop, and after it read the next command at the old
  offset, so it ran `< "$groups"`. With the `main` wrapper, bash has parsed `main "$@"; exit` before `main`
  runs, so it never reads the file again. Case (t) rewrites a scratch copy of `run.sh` in place (same inode)
  during the first group. The pre-unit `run.sh` then exits 7. The wrapped one finishes all three groups
  with empty stderr. The body is not re-indented, which keeps the diff to the wrapper lines.
- **Case (q).** The old fake drained stdin into `/dev/null`. With ` < /dev/null` gone, it read the suite's
  own stdin, which passes on `/dev/null` and hangs on an open pipe (rfp-u2e PASS note). Now `run.sh`'s stdin
  is a sentinel file, so the first fake records `SENTINEL` and the case fails at once. spec-master ran
  mutant C with `sleep 200 |` as the suite's stdin: `FAIL (q) … read=SENTINEL`, no hang.
- **The label suite's snapshot.** `tests/refutation-label.test.sh` hashes every file under
  `eval/refutation-replay/`. If the human's run writes `report.jsonl` while that suite runs, it goes red
  without any defect (rfp-u2e PASS note). Re-run it. Do not import an `eval/` module in place: that leaves
  an untracked `__pycache__/`, which turns criterion 12 red (rfp-u2c PASS note).
- **spec-master's scratch proof** (a clone at 4ec89dae, payload committed as `(rfp-u2f)`):
  - Both suites pass. On the pre-unit files they fail exactly `k,l,m` and `e,r,s,t,u,v`.
  - Criteria 1 to 12 print their expected lines. Criteria 4 and 43 read the FAIL records through
    `--repo <main checkout>` in the clone, which is the default in the main checkout.
  - Criteria 2, 3, 4, 5, 8 and 9 print `no-commits` and exit 1 on the real tree.
  - Every `mutation:` line was run and changes the output as stated.
  - `node bin/contract-anchors.js` on this contract prints the line quoted in the plan's Step 2f.

## Escalation
Hard rules (each has caused damage in this plan before):
- Run every mutation and experiment in a scratch copy or a detached scratch worktree, never in the shared
  tree. Never edit a tracked file in the shared tree and then restore it: a lead did that to `run.sh` while
  the human ran a paid job on that file (rfp-u2e).
- Never `pkill` or `kill` a process you did not start.
- Never run `eval/refutation-replay/run.sh` without `--dry-run`: a real run spends the human's API budget.
- Never read, edit, stage, delete or commit `eval/refutation-replay/report.jsonl`.
- If `writer-scope-gate.sh` blocks an edit to a file in "Affected files" and suggests `git checkout`, do not
  obey the suggestion. Report the block as a false positive and wait.
- Use the Write/Edit tools for file edits, test files included.
- Run `tests/validate.sh` only with `ANTISLOP_VALIDATE_LANES=4`.

If a `before:` or anchor text is not found exactly once, stop and report the current text. If edit 43 prints
anything other than `corpus: refreshed rows=41 longer=40 errors=0`, or exits non-zero, stop and report its
output; never hand-edit `corpus.jsonl` and never run the build mode. If a gate blocks a command, report it and
wait. Anything outside "Affected files" goes in your report as a proposal.
