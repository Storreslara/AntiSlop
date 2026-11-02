Unit: l2-scribe

## Objective
Plan unit 15, after 1-14; docs only. Do appendix items S1-S7 ("l2-scribe items"). Verify each claim in the shipped code and cite it as `path:line` (rv-scribe's ADR draft had two factual errors).

## Retrieval
No tracker issue; plan unit 15 and appendix. Size `--at-least medium` (S0).

## Affected files
- `CONTEXT.md`
- `docs/harness-glossary.md`
- `docs/adr/0020-write-edit-content-not-scanned.md`
- `docs/adr/0025-textual-gate-protection-requires-structural-triggers.md`
- `docs/adr/0046-lean-pipeline-2.md`
- `.claude/wiki/architecture.md`
- `.claude/wiki/changelog.md`
- `.claude/agent-memory/*/*.md`, only the files criterion 4 lists

## Do NOT touch
- `agents/`, `hooks/`, `bin/`, `tests/`, `CHANGELOG.md`

## Acceptance criteria
1. run: `e(){ awk -v t="**$2**" 'index($0,t)==1{f=1} f&&/^$/{exit} f' $1 | tr -s ' \n' ' '; }; g=docs/harness-glossary.md; echo "$(e CONTEXT.md 'Arm A / Arm B' | grep -c 'no-op since 0.32.0') $(grep -A1 -E '^\*\*DECISION (file|channel)\*\*' CONTEXT.md | grep -c '^Retired (0.32.0):') $(e $g 'small repo' | grep -c 'repo: small')"`
   exit: 0
   stdout: `1 2 1`
   mutation: skip **DECISION channel** → `1 1 1`.
2. run: `g=docs/harness-glossary.md; echo "$(grep -cE 'and on its Bash branch|was deleted, so this denial|stamp at each gated writer dispatch' $g) $(grep -cE '^\*\*(A/B harness parity|writer-dispatch stamp|marker check|fix-of|Output caps|plan appendix|small repo)\*\*:' $g)"`
   exit: 0
   stdout: `0 7`
   mutation: omit **small repo** → `0 6`.
3. run: `a=.claude/wiki/architecture.md; echo "$(head -8 docs/adr/0020-*.md docs/adr/0025-*.md | grep -c 'Superseded in part by ADR-0044') $(awk '/^## Marker state machine/{f=1;next} f&&/^## /{exit} f' $a | grep -m1 -c 'Retired (0.32.0)') $(tr -s ' \n' ' ' <$a | grep -c 'no agent can complete a .DECISION. write')"`
   exit: 0
   stdout: `2 1 0`
   mutation: note in 0025's body only → `1 1 0`.
4. run: `for f in $(git grep -l -E 'benign-command\.sh|command_skeleton|mentions_marker_dir' -- .claude/agent-memory); do grep -q 'deleted in 0.32.0' $f || echo $f; done`
   exit: 0
   stdout: empty
   mutation: skip `TECHNIQUES.md` → its path.
5. run: `s=$(awk '/^## /{n++} n==1' .claude/wiki/changelog.md); A=$(cat docs/adr/0046-*.md 2>/dev/null); grep -qE '^- No ADR: ' <<<"$s" || grep -q '^Status: Accepted' <<<"$A" || echo no-adr; for k in lean-pipeline-2 TTL l2-slim 'Review gating:' 'bookkeeping.sh repo' --blast-radius 'repo: small' run_pass H4 state_replace_pending_review index-flags rv-scribe; do grep -qF -- "$k" <<<"$s" || echo "missing $k"; done; n=0; b=0; for c in $(grep -oE '[[:alnum:]_./-]+\.[a-z]+:[0-9]+' <<<"$s$A"); do n=$((n+1)); f=${c%:*}; [ -f $f ] && [ $(wc -l <$f) -ge ${c##*:} ] || b=$((b+1)); done; echo "cites>=10:$((n>=10)) bad=$b"`
   exit: 0
   stdout: `cites>=10:1 bad=0`
   mutation: drop the `check` bullet → `missing index-flags` first; cite `bin/x.sh:9` → `bad=1`.
6. run: `bash tests/validate.sh >/dev/null 2>&1` (Bash tool timeout 600000 ms; once, after the final commit)
   exit: 0
   stdout: empty
