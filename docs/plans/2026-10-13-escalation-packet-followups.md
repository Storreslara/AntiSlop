# Escalation packet follow-ups (epf-1..epf-6): every open note from epa-1..epa-4

Status: FINAL (spec-master, 2026-10-13). Six dispatchable units, so this is the
**standard path**: `task-master` slices it and writes the dispatch contracts.
Baseline: HEAD 9122697, version 0.31.159.

## Goal

Close every open follow-up left by the escalation-packet aesthetics work
(`docs/plans/2026-10-12-escalation-packet-aesthetics.md`, units epa-1..epa-4).
Sources: the scribe note `.claude/agent-memory/scribe/project_epa2_completion.md`
(items 1-14), the four `epa-N.pass` non-blocking notes, and the coordinator's
list. Nothing is dropped. Every item is either fixed by a unit below or shown
already closed, with a check that proves it (see the inventory).

## Context

### Item inventory (every open note → its unit)

| # | Item (source) | Disposition |
|---|---|---|
| S1 | AC2.3 loop reports only the last file (scribe 1, epa-2 note) | epf-6 |
| S2 | Parity probes lack `**After:**`, `### <n>.`, the `>` blockquote line (scribe 2, epa-2 note) | epf-2 |
| S3 | Dashboard `markdown-lite.js` has no tables; OQ1 asked for an issue to be filed (scribe 3, epa-2 note) | epf-4 implements table support, so no tracker issue is needed |
| S4 | view.sh fallback order not pinned by T4-T7 (scribe 4) | epf-3 (O1-O4) |
| S5 | T8 misses a dropped `[ -f "$p" ] \|\| continue` (scribe 5) | epf-3 (T8 checks stderr) |
| S6 | T1 compares copies only with each other (scribe 6) | epf-3 (T1b golden copy) |
| S7 | AC3.2 is met by echo lines; AC3.3 `view.sh` probe is met by the block comments (scribe 7) | epf-2 adds the prose probe; epf-6 corrects AC3.2/AC3.3 |
| S8 | `parseProtocolSections` (bin/cli.js:717) splits on `## ` inside fences (scribe 8) | epf-5 |
| S9 | Stale criterion at docs/plans/2026-10-01-in-session-escalation-decision.md:928 (scribe 9) | epf-6 |
| S10 | AC4.6 as written always gives rc=1 (scribe 10) | epf-6 |
| S11 | AC4.4 is met by the template table row, not by the prose (scribe 11) | epf-6 |
| S12 | No rule for older `.escalated` markers with no fold or `decide:` line (scribe 12, epa-4 note) | epf-1 |
| S13 | `examples: none —` vs card `examples: none -` (scribe 13; reviewer.md:377, template:514, CONTEXT.md:1049) | epf-2 (aligns to the ASCII hyphen, see Clarifications) |
| S14 | Column-0 card block in reviewer.md ends the list item; "In the **same action**" renders as a loose paragraph (scribe 14) | epf-2 |
| N1 | epa-1: AC1.3 is a presence check, vacuous for step 3 | epf-6 (count must be 2) |
| N2 | epa-1: no test pins the orchestrator/template wording | epf-1 (new parity check); T10 already pins the step 2/3 clause |
| N3 | epa-1: orchestrator lines overflow the ~80-column wrap | epf-1 (steps 1-5 kept to 80 columns or less) |
| N4 | epa-1: "pastes" (template:610) vs "reproduce" | epf-1 |
| N5 | epa-2: AC2.2 monotone count weak for `consequence` | epf-6 |
| N6 | epa-2: ragged wrapping (reviewer.md:359/369/373; ports :252/:258 at 104 chars) | epf-2 |
| N7 | epa-2: CONTEXT.md "`>` callout" / "lead-ins" near-synonyms | Already closed by the epa-2 scribe pass. Check: `! grep -nE 'callout\|lead-ins' CONTEXT.md` exits 0 (verified 2026-10-13) |
| N8 | epa-3: CONTEXT.md packet viewer said "comprehension tooling" | Already closed. Check: `! grep -n 'comprehension tooling' CONTEXT.md` (verified) |
| N9 | epa-1: step 3 lacked the prefix clause | Already closed by epa-3; T10 of tests/packet-view-script.test.sh pins it |
| N10 | Template :608-610 says the orchestrator prints "the `.escalated` marker verbatim", which is stale since epa-4 (found while speccing) | epf-1 |

The 2026-10-13 sweep (`bin/marker-audit.sh . --notes`) found 53 `NOTE[spec]`
lines on these surfaces. Apart from epa-1 (N1/N9 above), none concerns packet
presentation, the card, the viewer or the dashboard renderer (blc-*, blf-*,
item06-*, esc-chat-3, gh295-*, rgh-*, and others). **Disposition:** out of
scope. gh295-2's "order of the `human:` line and the notes on approve" note is
already settled by epa-4 (notes go after the `human:` line). The sweep is
best-effort, so an empty result proves nothing.

### Prior FAIL history (Implementer-tier ratchet input)

- `examples-2`: probes were line-wrapped in the ports. Every probe literal must stay on ONE physical line (epf-2).
- `packet-brevity-1`: mirrors were hand-edited. Mirrors change only through `node bin/cli.js --update --force-render` (epf-1, epf-2).
- `reviewer-changes-examples-lean-2`: P3 was missed. epf-1 and epf-2 bump the version in the same commit.
- `dash-ux-1`: escape-first XSS, sentinel splitting. epf-4 table cells must go through `renderInline` only, with no new escape site.
- `dash-ux-2`/`-4`, `dash-scroll-1`, `dash-rail-collapse-1`: vacuous dashboard criteria. epf-4's criteria were run against the old renderer and fail there.

Suggestion only (tiering is task-master's call): start epf-1, epf-2 and epf-4
no cheaper than `sonnet`.

### Measured facts this spec rests on (2026-10-13, HEAD 9122697)

- `tests/validate.sh` has 115 sections. Section 101 (reviewed-dir leak guard) runs a **nested full validate.sh**: 696 s alone. That exceeds the 600 s Bash cap, so the full run cannot be one call. Section 101 is a no-op when `REVIEWED_DIR_LEAK_GUARD_NESTED=1`. With that set, the ranges took: [1,60] ≈ 210 s; [61,108] 94 s (measured, rc 0); [109,110] ≈ 175 s; [111,end] ≈ 125 s.
- `ls -1 .claude/reviewed | md5sum` passes `reviewed-path-gate.sh` as a read-only call. It must be its OWN Bash call: any other text in the same command, or a `$(…)`, is refused.
- Template fences are all at column 0 (lines 434/448, 536/552, 616/624). Neither template has a `## ` line inside a fence, so a fence-aware parser leaves rendering unchanged (prototype: dry-run rc 0).
- `escapeHtml(` occurs 5 times in markdown-lite.js (the definition plus 4 call sites).
- Nothing machine-reads `examples: none -` or `examples: none —`. The gate and the tests read only `examples: none-offered`.
- `version-stamp-check.sh` gates only `agents/*.md` and `templates/*`. The ports, bin/, tests/ and docs/ take no bump (dash-scroll-1 and hyg-2 precedent: no bump, no CHANGELOG).
- Unit-id prefix `epf-` is unused in git history.

## Clarifications
1. Functional scope & success criteria: Clear
2. Domain entities / data model: Partial
3. User interaction flow: Partial
4. Non-functional attributes (perf, security, scale): Partial
5. External dependencies & integrations: Clear
6. Edge cases / failure handling: Partial
7. Technical constraints & tradeoffs: Partial
8. Terminology consistency: Partial
9. Completion / acceptance signals: Partial

- 2026-10-13 Domain entities / data model: Q Which spelling wins for the skip token, the card's ASCII `examples: none - <reason>` or the prose's em dash? → A (self-resolved): the ASCII hyphen. The card is declared ASCII and is byte-checked in six copies, and the ports already use a hyphen. Changing the prose is 3 lines; changing the card is 6 copies and breaks the ASCII rule. This reverses the scribe note's candidate.
- 2026-10-13 User interaction flow: Q What does the orchestrator print for a marker with no `---` fold, and what is Q1's description with no `decide:` line? → A (self-resolved): print the whole marker verbatim with no pointer line, and use exactly `How should this escalation be resolved?`. The two conditions are independent.
- 2026-10-13 Non-functional attributes: Q Can table support reopen dash-ux-1's XSS class? → A (self-resolved): no. Cells go only through `renderInline`; the escape-call count stays 5; tags carry no attributes (no `align`/`style`); the adjacency and cross-product XSS suites also run in table header and body cells.
- 2026-10-13 Edge cases / failure handling: Q Could a card's piped lines or its `---` fold become a table? → A (self-resolved): no. A delimiter row must contain `|`, every cell must match `:?-+:?`, and the cell count must equal the header's (TB5 pins this).
- 2026-10-13 Edge cases / failure handling: Q Fix parseProtocolSections, or forbid fenced `## ` lines? → A (self-resolved): both. Make it fence-aware (CommonMark-style ``` / ~~~, opener indented up to 3 spaces, closer of the same character and at least as long), and add an invariant test that the live templates have no fenced `## ` line. The naive sibling splitters (parity test, cli-backfill test, protocol-doc-drift) therefore stay correct without edits.
- 2026-10-13 Technical constraints & tradeoffs: Q How is the merge gate run under the 600 s cap? → A (self-resolved): four `vsec` ranges with `REVIEWED_DIR_LEAK_GUARD_NESTED=1`, bracketed by two standalone `ls -1 .claude/reviewed | md5sum` calls that must match. That is the leak guard's own property, computed across the ranges.
- 2026-10-13 Technical constraints & tradeoffs: Q Should old plan criteria be fixed in place or in an appendix? → A (self-resolved): in place, each with an `erratum` sub-bullet, plus an Errata section listing them. Git keeps the originals, and a re-run then uses the right command.
- 2026-10-13 Terminology consistency: Q Does "marker with no fold line" need a new glossary term? → A (self-resolved): no. One sentence goes into the existing **fold line** and **escalation card** entries; "pastes" is replaced by "reproduces" (N4).
- 2026-10-13 Completion / acceptance signals: Q Which criteria could not be fully verified before implementation? → A (self-resolved): marked `unverified` inline. All others were run at HEAD (they fail as expected) and, where noted, against prototypes or worktree mutations.

## Risks / dependencies

- R1: epf-1 then epf-2, strictly in that order. Both edit `templates/persona-protocol.md` and the parity test, and each takes the next patch version (expected 0.31.160 and 0.31.161; re-derive both from `.claude-plugin/plugin.json`).
- R2: epf-6 runs after epf-2, because the corrected AC3.3 needs epf-2's prose probe. epf-6 is also after epf-4 (it marks OQ1 resolved).
- R3: epf-3, epf-4 and epf-5 share no file with each other. The order epf-3, epf-4, epf-5 is a suggestion.
- R4: Criteria are bash blocks. **Save each block to a scratch file (Write tool) and run `bash <file>` from the repo root.** Do not paste them as Bash text: `reviewed-path-gate.sh` and `harness-integrity-gate.sh` scan command text.
- R5: The mirror/P3 idiom requires `git status --porcelain` to be empty. Commit your own agent-memory files first.
- R6: `ls -1 .claude/reviewed | md5sum` can differ if another agent writes a marker during the run. If so, re-run.

## Constitution check (.claude/constitution.md v1.1.0)
- P1 "Verify, don't assume": satisfied. Every criterion was run at HEAD; the mutation harnesses for epf-3 and epf-6, plus prototypes for epf-4 and epf-5, were run in worktrees. The exceptions are marked `unverified`.
- P2 "Prefer deterministic scripts over LLM re-derivation": satisfied. Mirrors change only through `node bin/cli.js --update --force-render`.
- P3 "Version-stamp discipline": satisfied. epf-1 and epf-2 bump plugin.json and package.json and add a CHANGELOG entry in the same commit. epf-3..epf-6 touch no stamped path.
- P4 "Optional personas degrade gracefully" (SHOULD): satisfied. New orchestrator prose keeps "this project's `reviewer` (if present)".
- P5 "`tests/validate.sh` is the merge gate": satisfied. The merge gate is the full section coverage via the G procedure below; the section count it runs equals the file's.

## Shared criterion idioms

Save this as a scratch file and `source` it at the top of every G call (shell
state does not persist between Bash calls):

```sh
# vsec <i> <j>: run validate.sh sections i..j (1-based header order; j>=count means "to the end").
vsec() {
  local s rc; s=$(mktemp)
  { printf 'set -uo pipefail\ncd %s\nfail=0\n' "$(git rev-parse --show-toplevel)"
    awk -v i="$1" -v j="$2" '
      NR==FNR { if (/^echo "== /) h[++c]=FNR; next }
      FNR==1  { lo=h[i]; hi=(j<c)?h[j+1]-1:999999 }
      FNR>=lo && FNR<=hi' tests/validate.sh tests/validate.sh
    printf '\nexit "$fail"\n'; } > "$s"
  bash "$s"; rc=$?; rm -f "$s"; return "$rc"
}
# vrun '<header substring>': run every section whose == header contains the string.
vrun() {
  local s rc; s=$(mktemp)
  { printf 'set -uo pipefail\ncd %s\nfail=0\n' "$(git rev-parse --show-toplevel)"
    awk -v k="$1" '/^echo "== /{on=index($0,k)>0} on' tests/validate.sh
    printf '\nexit "$fail"\n'; } > "$s"
  grep -q '^echo "== ' "$s" || { echo "vrun: no section matches: $1"; rm -f "$s"; return 2; }
  bash "$s"; rc=$?; rm -f "$s"; return "$rc"
}
F=$(git log --format=%H -E --grep='^[a-z]+\(epf-N\)' | tail -1)   # first unit commit
L=$(git log --format=%H -E --grep='^[a-z]+\(epf-N\)' | head -1)   # last unit commit
```

**G: the full merge gate.** Five separate Bash calls, each with `timeout: 600000`:

1. `ls -1 .claude/reviewed | md5sum` on its own; note the hash.
2. `export CLAUDE_PROJECT_DIR="$(git rev-parse --show-toplevel)" REVIEWED_DIR_LEAK_GUARD_NESTED=1; vsec 1 60`
3. the same exports, then `vsec 61 108`
4. the same exports, then `vsec 109 110`, then (same call) `vsec 111 999`. Split this into two calls if it nears the cap.
5. `ls -1 .claude/reviewed | md5sum` on its own; it must equal step 1.

Pass when every vsec exits 0 and the hashes match. Coverage check: the
ranges cover 1..`grep -c '^echo "== ' tests/validate.sh`, which is 115 today.
No unit adds a section.

**P3 / mirror idiom** (from the epa plan, verified there; epa-3 notes a stale mirror gives dry-run rc=3):
`node bin/cli.js --update --dry-run >/dev/null && [ -z "$(git status --porcelain)" ] && bash hooks/scripts/version-stamp-check.sh "$F^..$L" | grep -q '^version-stamp-check: ok' && grep -q '(epf-N, ' CHANGELOG.md`

**Mirror regex** for scope checks: `^\.claude/(agents/[^/]+\.md|persona-protocol(-slim)?\.md|protocol-digest\.md|persona-config[.]json)$`

## Steps

### Step 1 — epf-1: orchestrator rule for markers with no card (S12, N2, N3, N4, N10)

**Affected files:** `agents/orchestrator.md` (escalation steps 1-5, about lines 246-298); `templates/persona-protocol.md` (:608-610, "The prompt-confirmed decision write" paragraph); `CONTEXT.md` (**fold line** entry about :940, **escalation card** about :931); `.claude/wiki/architecture.md` (:80-82); `tests/adapter-protocol-parity.test.js` (one new `check`); `.claude-plugin/plugin.json`, `package.json`, `CHANGELOG.md`; mirrors (regenerated).

**Ordered edits:**
1. Step 1: after "Never summarize the record.", add: "A marker with no `---` fold line was written before the card format: print the whole marker verbatim instead, with no pointer line."
2. Step 5: after "Q1's description is the text after `decide: ` on the card, verbatim.", add: "When the marker has no `decide: ` line, Q1's description is exactly `How should this escalation be resolved?`."
3. Re-wrap steps 1-5 so that no line exceeds 80 columns, except the `Full record (criteria, notes): …` pointer literal, which stays on one physical line. Every flattened phrase that existing checks read stays intact: T10's clause count of 2, AC1.1's count of 2, AC3.4's `Never run \`run.sh\` or \`view.sh\` yourself`, and AC4.5's phrases. Step 6 is byte-unchanged.
4. Template :608-610: replace "prints the `.escalated` marker verbatim in chat, pastes `CHANGES.md` and `EXAMPLES.md` verbatim as its own message text" with "prints marker lines 1 through the `---` fold line verbatim in chat (the whole marker when it has no fold line), reproduces `CHANGES.md` and `EXAMPLES.md` verbatim as its own message text". The rest of the sentence ("outside any code fence, so they render, and asks …") is unchanged.
5. CONTEXT.md: append "A marker with no fold line is printed whole." to **fold line**. In **escalation card**, change "Q1's description is the card's `decide:` text" to "Q1's description is the card's `decide:` text, or a fixed generic question when the marker has no `decide:` line".
6. architecture.md :82: "the orchestrator prints only through the fold" becomes "the orchestrator prints only through the fold; a marker with no fold is printed whole".
7. Parity test: add `check('orchestrator escalation steps handle a marker with no fold line or no decide: line', …)`. It flattens whitespace (`/\s+/g` → `' '`) and asserts that `agents/orchestrator.md` and `.claude/agents/orchestrator.md` contain the literals from edits 1 and 2, and that `templates/persona-protocol.md` contains the edit-4 literal.
8. Bump the patch version in plugin.json and package.json. Add a CHANGELOG `[Unreleased]` entry whose bold lead ends `(epf-1, <version>).**`. Run `node bin/cli.js --update --force-render`. Make ONE commit with the subject `docs(epf-1): …`.

**Acceptance criteria** (each block was run at HEAD and fails there as expected):
- AC1.1 (step-1 rule, source and mirror). Mutation: delete the sentence from the mirror only by skipping `--force-render` → exit 1.
  ```sh
  for f in agents/orchestrator.md .claude/agents/orchestrator.md; do
    t=$(tr -s ' \n' ' ' < "$f")
    echo "$t" | grep -qF 'A marker with no `---` fold line' || { echo "MISSING fold rule: $f"; exit 1; }
    echo "$t" | grep -qF 'print the whole marker verbatim instead, with no pointer line' || { echo "MISSING whole-marker rule: $f"; exit 1; }
  done
  ```
- AC1.2 (generic Q1; card rule kept). Mutation: drop edit 2 → exit 1.
  ```sh
  for f in agents/orchestrator.md .claude/agents/orchestrator.md; do
    t=$(tr -s ' \n' ' ' < "$f")
    echo "$t" | grep -qF 'When the marker has no `decide: ` line, Q1'"'"'s description is exactly `How should this escalation be resolved?`' || { echo "MISSING generic Q1: $f"; exit 1; }
    echo "$t" | grep -qF 'Q1'"'"'s description is the text after `decide: ` on the card, verbatim' || { echo "LOST card Q1 rule: $f"; exit 1; }
  done
  ```
- AC1.3 (template sentence; "pastes" gone; epa AC1.4 count kept). Mutation: revert edit 4 → exit 1.
  ```sh
  for f in templates/persona-protocol.md .claude/persona-protocol.md; do
    t=$(tr -s ' \n' ' ' < "$f")
    echo "$t" | grep -qF 'prints marker lines 1 through the `---` fold line verbatim in chat (the whole marker when it has no fold line)' || { echo "MISSING: $f"; exit 1; }
    echo "$t" | grep -qF 'reproduces `CHANGES.md` and `EXAMPLES.md` verbatim as its own message text' || { echo "MISSING reproduces: $f"; exit 1; }
    ! echo "$t" | grep -qF 'pastes `CHANGES.md`' || { echo "STALE pastes: $f"; exit 1; }
    [ "$(echo "$t" | grep -oF 'as its own message text, outside any code fence' | wc -l)" -eq 1 ] || { echo "count: $f"; exit 1; }
  done
  ```
- AC1.4 (glossary entries and wiki, entry-scoped). Mutation: omit edit 6 → exit 1.
  ```sh
  entry() { awk -v h="$1" 'f&&/^\*\*/{exit} index($0,h)==1{f=1;next} f' CONTEXT.md | tr -s ' \n' ' '; }
  entry '**fold line**:' | grep -qF 'A marker with no fold line is printed whole' || { echo "fold line entry"; exit 1; }
  entry '**escalation card**:' | grep -qF 'a fixed generic question when the marker has no `decide:` line' || { echo "escalation card entry"; exit 1; }
  sed -n '76,90p' .claude/wiki/architecture.md | tr -s ' \n' ' ' | grep -qF 'a marker with no fold is printed whole' || { echo "wiki"; exit 1; }
  ```
- AC1.5 (durable pin). Mutation: remove edit 1 → the parity test exits 1.
  ```sh
  log=$(mktemp)
  node tests/adapter-protocol-parity.test.js > "$log" || { tail -5 "$log"; exit 1; }
  grep -q '^OK   orchestrator escalation steps handle a marker with no fold line or no decide: line' "$log" || { echo "check not run"; exit 1; }
  ```
- AC1.6 (80-column wrap; pointer literal on one line). At HEAD this reports 3 lines over 80.
  ```sh
  n=$(awk '/^1\. Print the marker/{f=1} /^6\. Make the/{f=0} f && length($0)>80 && index($0,"Full record (criteria, notes)")==0' agents/orchestrator.md | wc -l)
  [ "$n" -eq 0 ] || { echo "$n over-80 lines in steps 1-5"; exit 1; }
  grep -F 'Full record (criteria, notes): ' agents/orchestrator.md | grep -qF 'PACKET.md`.' || { echo "pointer literal split"; exit 1; }
  ```
- AC1.7 (epa invariants kept): `bash tests/packet-view-script.test.sh`, plus epa AC4.5 and the corrected AC4.6 (Step 6 below, with F/L of epa-4) exit 0. Mutation: edit a word of step 6 → AC4.6 exits 1.
- AC1.8 (scope): `git diff --name-only "$F^" "$L" | grep -vxE 'agents/orchestrator\.md|templates/persona-protocol\.md|CONTEXT\.md|\.claude/wiki/architecture\.md|tests/adapter-protocol-parity\.test\.js|\.claude-plugin/plugin\.json|package\.json|CHANGELOG\.md' | grep -vE '<mirror regex>'` prints nothing.
- AC1.9 (mirror and P3): the P3 idiom with `epf-1`.
- AC1.10 (merge gate): G. Targeted sections first: `vrun 'adapter protocol-port parity'`, `vrun 'packet viewer'`, `vrun 'persona-config fileHashes'`, `vrun 'version-stamp-check'`, `vrun 'protocol doc-drift'`.

### Step 2 — epf-2: reviewer prose consistency and parity probes (S2, S7 probe, S13, S14, N6)

**Affected files:** `agents/reviewer.md` (:295 card follow-on, :355-377); `templates/persona-protocol.md` (:493-514); `adapters/codex/agents-md-fragment.md` (:251-268); `adapters/cursor/rules/persona-protocol.mdc` (:257-274); `CONTEXT.md` (:1049); `tests/adapter-protocol-parity.test.js` (`ESCALATION_PROBES`); version files, CHANGELOG, mirrors.

**Ordered edits:**
1. Change `examples: none — <one-line reason>` to `examples: none - <one-line reason>` at reviewer.md:377, template:514 and CONTEXT.md:1049. Change only the token; em-dash punctuation elsewhere stays.
2. reviewer.md :295: change "In the **same action**, snapshot the unit's bundle to" so that the line starts a list item: `- **Durable escalation packet**: in the **same action** that writes the marker,` followed by the existing text re-wrapped at a 2-space continuation indent. This is the template's own name for the packet. The card block and the view.sh block are byte-unchanged.
3. Re-wrap so that every line carrying a layout anchor is 80 columns or less in all four sources. The anchors are: `blockquote line`, `| Where | What to check |`, `lines under its heading`, `**After:**`, `**Before:**`, `no wrapped paragraph longer than two lines`, `most one consequence line`. Each probe literal stays on ONE physical line.
4. Append to `ESCALATION_PROBES`, each commented `// epf-2`: `'**After:**'`, `'### <n>. <one-phrase title>'`, ``'one `>` blockquote line'``, ``'`run.sh` and `view.sh` commands'``. The last is the prose probe for S7; the view.sh block's own comment lines cannot satisfy it. All four are present on one line in both ports at HEAD.
5. Bump the version, add a CHANGELOG entry `(epf-2, <version>).**`, run `--force-render`, and make one commit `docs(epf-2): …`.

**Acceptance criteria** (all were run at HEAD and fail as expected):
- AC2.1 (token aligned). Mutation: leave the em dash in the template → exit 1.
  ```sh
  for f in agents/reviewer.md templates/persona-protocol.md .claude/agents/reviewer.md .claude/persona-protocol.md CONTEXT.md; do
    [ "$(grep -c 'examples: none —' "$f")" -eq 0 ] || { echo "EM DASH left: $f"; exit 1; }
  done
  for f in agents/reviewer.md templates/persona-protocol.md .claude/agents/reviewer.md .claude/persona-protocol.md; do
    [ "$(grep -cF 'examples: none - <one-line reason>' "$f")" -ge 2 ] || { echo "token count <2: $f"; exit 1; }
  done
  grep -qF 'examples: none - <one-line reason>' CONTEXT.md || { echo "CONTEXT.md token"; exit 1; }
  ```
- AC2.2 (card no longer orphans the paragraph). Mutation: revert edit 2 → exit 1.
  ```sh
  for f in agents/reviewer.md .claude/agents/reviewer.md; do
    nxt=$(awk 'f&&NF{print;exit} /^<!-- escalated-card:end -->$/{f=1}' "$f")
    case "$nxt" in '- **Durable escalation packet**: in the **same action** that writes the marker,'*) : ;;
      *) echo "line after card in $f: $nxt"; exit 1 ;; esac
    [ "$(grep -c '^In the \*\*same action\*\*' "$f")" -eq 0 ] || { echo "column-0 paragraph left: $f"; exit 1; }
  done
  ```
- AC2.3 (anchor lines 80 columns or less). At HEAD: reviewer 3 lines, codex 3, cursor 3.
  ```sh
  for f in agents/reviewer.md templates/persona-protocol.md adapters/codex/agents-md-fragment.md adapters/cursor/rules/persona-protocol.mdc; do
    n=$(grep -F -e 'blockquote line' -e '| Where | What to check |' -e 'lines under its heading' -e '**After:**' -e '**Before:**' -e 'no wrapped paragraph longer than two lines' -e 'most one consequence line' "$f" | awk 'length($0)>80' | wc -l)
    [ "$n" -eq 0 ] || { echo "$f: $n anchor line(s) over 80 columns"; exit 1; }
  done
  ```
- AC2.4 (probes added, old probes kept, parity green). Mutations: remove `**After:**` from the cursor port → exit 1. Hard-wrap ``one `>` blockquote line`` in the codex port → exit 1.
  ```sh
  T=tests/adapter-protocol-parity.test.js
  node "$T" >/dev/null || { echo "parity test failed"; exit 1; }
  for p in "'**After:**'" "'### <n>. <one-phrase title>'" "'one \`>\` blockquote line'" "'\`run.sh\` and \`view.sh\` commands'"; do
    grep -F -- "$p" "$T" | grep -qF '// epf-2' || { echo "probe missing or untagged: $p"; exit 1; }
  done
  B=$(git log --format=%H -E --grep='^[a-z]+\(epf-2\)' | tail -1); [ -n "$B" ] || B=HEAD
  git show "$B^:$T" | sed -n '/^const ESCALATION_PROBES/,/^];/p' | grep -oE "^  '[^']+'" | while read -r p; do
    grep -qF -- "$p" "$T" || { echo "LOST $p"; exit 1; }
  done || exit 1
  ```
- AC2.5 (blocks untouched): `node tests/adapter-protocol-parity.test.js` (card byte-identity) and `bash tests/packet-view-script.test.sh` (T1) exit 0.
- AC2.6 (scope): changed files are limited to the Affected files plus the mirror regex.
- AC2.7: the P3 idiom with `epf-2`. AC2.8: G.

### Step 3 — epf-3: view.sh test hardening (S4, S5, S6)

**Affected files:** `tests/packet-view-script.test.sh` only. No version bump.

**Ordered edits** (prototyped and run; see AC3.2):
1. **T1b**, after `script="$tmp/ref"`: write the canonical viewer (the 15 lines between the fences of the plan's "Canonical packet viewer block", docs/plans/2026-10-12-escalation-packet-aesthetics.md:180-194) to `$tmp/canon` with a quoted heredoc (`<<'VIEW_SH_CANONICAL'`). Then `cmp -s "$tmp/ref" "$tmp/canon"` → `pass "T1b copies equal the canonical viewer"`, else `bad "T1b copies differ from the canonical viewer"`.
2. `runv`: add `2>"$tmp/err"` to the viewer invocation.
3. **T8**: also require `[ ! -s "$tmp/err" ]`. Label: `T8 missing EXAMPLES.md skipped, rc 0, stderr empty`.
4. **O1-O4**, after T7. Each case puts two renderers on PATH and requires only the earlier one to run, using `cnt() { printf '%s\n' "$out" | grep -c "^$1:"; }`:
   - O1: glow 0 + bat 0 → GLOW=2, BAT=0, label `O1 glow before bat`.
   - O2: bat + batcat → `O2 bat before batcat`.
   - O3: batcat + rich → `O3 batcat before rich`.
   - O4: rich only → RICH=2 and no `raw` text, label `O4 rich before cat`.

**Acceptance criteria:**
- AC3.1 (cases run and pass):
  ```sh
  log=$(mktemp)
  bash tests/packet-view-script.test.sh > "$log" 2>&1 || { grep '^FAIL' "$log"; exit 1; }
  for c in 'T1b ' 'O1 ' 'O2 ' 'O3 ' 'O4 ' 'T8 '; do grep -q "^OK   $c" "$log" || { echo "not OK: $c"; exit 1; }; done
  grep -q '^OK   T8 .*stderr empty' "$log" || { echo "T8 does not check stderr"; exit 1; }
  ```
- AC3.2 (mutation proof: each mutation is applied to ALL SIX copies in a worktree, T1 stays green, and the named case fails). **Verified 2026-10-13** against a prototype of this exact test: all six killed (O1, O2, O3, O4, T8, T1b). Against today's test the first mutation survives (rc 0).
  ```sh
  set -u
  root=$(git rev-parse --show-toplevel); wt=$(mktemp -d)/wt
  git -C "$root" worktree add -q --detach "$wt" HEAD || exit 1
  trap 'git -C "$root" worktree remove --force "$wt"' EXIT
  copies="agents/reviewer.md templates/persona-protocol.md adapters/codex/agents-md-fragment.md adapters/cursor/rules/persona-protocol.mdc .claude/agents/reviewer.md .claude/persona-protocol.md"
  mut() { ( cd "$wt" && git checkout -q -- $copies && for f in $copies; do perl -0pi -e "$2" "$f"; done
      git diff --quiet -- $copies && { echo "$1 changed nothing"; exit 1; }
      out=$(bash tests/packet-view-script.test.sh 2>&1) && { echo "$1 survived"; exit 1; }
      printf '%s\n' "$out" | grep -q "^FAIL $3" || { echo "$1: no FAIL $3"; exit 1; }
      printf '%s\n' "$out" | grep -q '^FAIL T1 ' && { echo "$1 not in all six"; exit 1; }
      echo "$1 killed by $3" ); }
  ( cd "$wt" && bash tests/packet-view-script.test.sh >/dev/null 2>&1 ) || { echo "unmutated fails"; exit 1; }
  mut glow-bat    's/  if command -v glow( [^\n]*)\n  elif command -v bat( [^\n]*)\n/  if command -v bat$2\n  elif command -v glow$1\n/' O1 || exit 1
  mut bat-batcat  's/  elif command -v bat( [^\n]*)\n  elif command -v batcat( [^\n]*)\n/  elif command -v batcat$2\n  elif command -v bat$1\n/' O2 || exit 1
  mut batcat-rich 's/  elif command -v batcat( [^\n]*)\n  elif command -v rich( [^\n]*)\n/  elif command -v rich$2\n  elif command -v batcat$1\n/' O3 || exit 1
  mut no-rich     's/  elif command -v rich [^\n]*\n//' O4 || exit 1
  mut no-skip     's/  \[ -f "\$p" \] \|\| continue\n//' T8 || exit 1
  mut comment     's/else prints them plain\. Read-only\./else prints them plain./' T1b || exit 1
  ```
- AC3.3 (scope): `git diff --name-only "$F^" "$L"` prints only `tests/packet-view-script.test.sh`.
- AC3.4: `vrun 'packet viewer'` exits 0. G is optional: a test-only change in a file already registered.

### Step 4 — epf-4: dashboard markdown-lite table rendering (S3)

**Affected files:** `bin/microworld-dashboard/markdown-lite.js`, `tests/microworld/dashboard-markdown-lite.test.js`, `bin/microworld-dashboard/index.html` (CSS only). No version bump.

**Behaviour** (prototyped; every expected string below is the prototype's output):
- A table starts at line i when line i contains `|` and line i+1 is a delimiter row. A delimiter row contains `|`; after stripping one optional leading and trailing `|`, every `|`-separated cell trims to `/^:?-+:?$/`; and its cell count equals the header's. Checked after the list branches, before the paragraph branch.
- `splitRow`: trim, strip one optional leading/trailing `|`, split on `|` not preceded by `\`, turn `\|` into `|`, trim each cell. No escaping here.
- Body rows are the following lines that are non-blank and contain `|`. Extra cells are dropped; missing cells become empty.
- Output is `<table><thead><tr><th>…</th></tr></thead>`, plus `<tbody>…</tbody>` only when there are rows, then `</table>`. Emit cells exactly as `'<th>' + renderInline(cell) + '</th>'` / `'<td>' + renderInline(cell) + '</td>'`. Tags carry no attributes; alignment colons are ignored.
- index.html: `.doc-pane table { border-collapse: collapse; margin: var(--space-2) 0; }` and `.doc-pane th, .doc-pane td { border: 1px solid var(--gvx-bg-soft); padding: var(--space-1) var(--space-2); text-align: left; vertical-align: top; }`, next to the `.doc-pane` rule (:83). Theme tokens only.

**Test edits:**
- In `ALLOWED_TAG`, change `|blockquote)>` to `|blockquote|table|thead|tbody|tr|th|td)>`.
- Add two `CONTEXTS` entries: `{ name: 'table header cell', wrap: (s) => '| ' + s + ' |\n|---|' }` and `{ name: 'table body cell', wrap: (s) => '| h |\n|---|\n| ' + s + ' |' }`.
- Add the `TABLE_CASES`, checked with exact equality:

| Label | Input | Expected |
|---|---|---|
| TB1 basic | `\| Where \| What to check \|` / `\|---\|---\|` / ``\| `a.js:1` \| the guard \|`` | `<table><thead><tr><th>Where</th><th>What to check</th></tr></thead><tbody><tr><td><code>a.js:1</code></td><td>the guard</td></tr></tbody></table>` |
| TB2 aligned | `\| a \| b \|` / `\| :--- \| ---: \|` / `\| 1 \| 2 \|` | same shape as TB1, cells a,b / 1,2, no attributes |
| TB3 no outer pipes | `a \| b` / `--- \| ---` / `1 \| 2` | as TB2 |
| TB4 no delimiter | `\| a \| b \|` / `\| 1 \| 2 \|` | `<p>\| a \| b \|</p><p>\| 1 \| 2 \|</p>` |
| TB5 card | `why: x` / `criteria checked: AC1 ; exceptions: none \| none` / `examples: 3 \| examples: none - x` / `---` / `commit: abc` | five `<p>` lines and `<hr />`, with no `<table` |
| TB6 width mismatch | a 2-cell header with a 3-cell delimiter | paragraphs only |
| TB7 ragged rows | `\| 1 \|` and `\| 1 \| 2 \| 3 \|` under a 2-cell header | `<tr><td>1</td><td></td></tr><tr><td>1</td><td>2</td></tr>` |
| TB8 escaped pipe | `\| x \\\| y \|` | `<td>x \| y</td>` |
| TB9 ends at blank line | table, blank line, `after` | `…</table><p>after</p>` |
| TB10 header only | header and delimiter only | `<table><thead><tr><th>a</th><th>b</th></tr></thead></table>` |

**Acceptance criteria:**
- AC4.1 (cases and table XSS contexts). At HEAD this fails at TB1.
  ```sh
  T=tests/microworld/dashboard-markdown-lite.test.js; log=$(mktemp)
  node "$T" > "$log" 2>&1 || { grep -B1 '✗' "$log" | head -20; exit 1; }
  for n in 1 2 3 4 5 6 7 8 9 10; do
    awk -v n="TB$n " 'index($0,"Test " n)==1{getline nx; ok=(nx=="  ✓ ok"); found=1} END{exit !(found&&ok)}' "$log" || { echo "TB$n missing or not ok"; exit 1; }
  done
  for ctx in 'table header cell' 'table body cell'; do
    [ "$(grep -c "^Test U1-C3c adjacency payload [1-5] in $ctx\.\.\.\$" "$log")" -eq 5 ] || { echo "adjacency not run in: $ctx"; exit 1; }
  done
  grep -qF '|table|thead|tbody|tr|th|td)>' "$T" || { echo "ALLOWED_TAG not extended exactly"; exit 1; }
  ```
- AC4.2 (escape-first kept):
  ```sh
  M=bin/microworld-dashboard/markdown-lite.js
  [ "$(grep -c 'escapeHtml(' "$M")" -eq 5 ] || { echo "escapeHtml( count changed"; exit 1; }
  [ "$(grep -c 'function renderInline' "$M")" -eq 1 ] || exit 1
  grep -q "'<th>' + renderInline(" "$M" && grep -q "'<td>' + renderInline(" "$M" || { echo "cells bypass renderInline"; exit 1; }
  ! grep -qE '<t[hd] |align=|style=' "$M" || { echo "table tags carry attributes"; exit 1; }
  ```
- AC4.3 (mutation proof). The new test must fail against (a) the pre-epf-4 renderer, with TB1 failing, and (b) a renderer whose cells skip `renderInline` (`perl -pi -e "s/'<(t[hd])>' \+ renderInline\(([^)]*)\)/'<\$1>' + \$2/g"`), with a `table body cell` failure. Both were verified against the prototype: old renderer rc 1 with TB1 ✗; raw-cell renderer rc 1 with 12 failures, including table-cell contexts. Run in a worktree as in AC3.2, restoring `git show "$F^:bin/microworld-dashboard/markdown-lite.js"` for (a).
- AC4.4 (CSS tokens and scope) — **unverified** (the CSS is not prototyped):
  ```sh
  H=bin/microworld-dashboard/index.html
  grep -qE '^ *\.doc-pane table *\{' "$H" && grep -qE '^ *\.doc-pane th, *\.doc-pane td *\{' "$H" || { echo "table CSS missing"; exit 1; }
  ! grep -E '^ *\.doc-pane (table|th)' "$H" | grep -qE '#[0-9a-fA-F]{3,8}\b|rgb\(' || { echo "raw colour"; exit 1; }
  extra=$(git diff --name-only "$F^" "$L" | grep -vxE 'bin/microworld-dashboard/markdown-lite\.js|bin/microworld-dashboard/index\.html|tests/microworld/dashboard-markdown-lite\.test\.js')
  [ -z "$extra" ] || { echo "out of scope: $extra"; exit 1; }
  ```
- AC4.5: `vrun 'microworld dashboard'` exits 0 (covers server, client, decisions and markdown-lite).

### Step 5 — epf-5: fence-aware `parseProtocolSections` (S8)

**Affected files:** `bin/cli.js` (`parseProtocolSections` :717-730; `module.exports`), `tests/protocol-cross-references.test.js`. No version bump.

**Ordered edits:**
1. Track fence state in the loop. A line matching ``/^ {0,3}(`{3,}|~{3,})/`` opens a fence (remember the run). It closes on a line made of the same character, at least as long, up to 3 spaces of indent and trailing whitespace only. Inside a fence (including the opener and closer lines), a `## ` line is appended to the current section or the preamble; it never starts a section. Joining preamble + sections with `\n` still reproduces the input.
2. Export `parseProtocolSections`.
3. Add checks to `tests/protocol-cross-references.test.js`:
   - **F1** `F1 fenced ## line stays inside its section`: the AC5.1 fixtures.
   - **F2** `F2 live templates round-trip byte-for-byte`.
   - **F3** `F3 no ## line inside a fence in templates/persona-protocol.md or templates/persona-protocol-slim.md`: the fence-aware section count equals `(text.match(/^## /gm)||[]).length`. This keeps the naive splitters in the parity, cli-backfill and doc-drift tests correct.

**Acceptance criteria:**
- AC5.1. Fails at HEAD ("not exported"). **Verified** against a worktree prototype: rc 0, and `--update --dry-run` rc 0.
  ```sh
  node -e '
  const c = require("./bin/cli.js");
  if (typeof c.parseProtocolSections !== "function") { console.log("not exported"); process.exit(1); }
  const cases = [
    ["pre\n## A\n```\n## not a header\n```\n## B\nx", ["A", "B"]],
    ["pre\n## A\n~~~\n## not a header\n~~~\n## B", ["A", "B"]],
    ["pre\n## A\n````\n```\n## still fenced\n````\n## B", ["A", "B"]],
    ["pre\n## A\n  ```sh\n## inside an indented fence\n  ```\n## B", ["A", "B"]],
  ];
  for (const [t, want] of cases) {
    const r = c.parseProtocolSections(t);
    if (JSON.stringify(r.sections.map((s) => s.header)) !== JSON.stringify(want)) { console.log("headers", JSON.stringify(t)); process.exit(1); }
    if ([r.preamble, ...r.sections.map((s) => s.text)].join("\n") !== t) { console.log("round-trip", JSON.stringify(t)); process.exit(1); }
  }'
  ```
- AC5.2:
  ```sh
  log=$(mktemp)
  node tests/protocol-cross-references.test.js > "$log" 2>&1 || { grep '^FAIL' "$log"; exit 1; }
  for n in F1 F2 F3; do grep -q "^OK   $n " "$log" || { echo "$n not OK"; exit 1; }; done
  grep '^OK   F3 ' "$log" | grep -q 'persona-protocol-slim.md' || { echo "F3 omits slim"; exit 1; }
  ```
- AC5.3 (mutation proof, worktree) — **unverified** end-to-end; the parts were checked separately. (a) Splice the pre-epf-5 function body back in, keeping the export → `FAIL F1`. (b) `perl -0pi -e 's/(<!-- escalated-card:begin -->\n```text\n)/$1## fenced heading\n/' templates/persona-protocol.md` → `FAIL F3`. (c) `node bin/cli.js --update --dry-run` exits 0 at HEAD, so rendering is unchanged.
- AC5.4 (scope): only `bin/cli.js` and the test file change. AC5.5: `vrun 'protocol cross-references'`, `vrun 'bin/cli.js'`, `vrun 'adapter protocol-port parity'`, `vrun 'protocol doc-drift'` all exit 0.

### Step 6 — epf-6: correct the defective plan criteria (S1, S7, S9, S10, S11, N1, N5)

**Affected files:** `docs/plans/2026-10-12-escalation-packet-aesthetics.md`, `docs/plans/2026-10-01-in-session-escalation-decision.md`. Runs after epf-2 and epf-4.

**Ordered edits.** In the 2026-10-12 plan, replace each `- run:` line in place with the text below. Add a sub-bullet `  - erratum (2026-10-13, epf-6): <why>` under each one, and add a `## Errata (2026-10-13, epf-6)` section before `## Open Questions` that lists the seven.
- **AC1.3:** ``for f in agents/orchestrator.md .claude/agents/orchestrator.md; do [ "$(tr -s ' \n' ' ' < $f | grep -oF "without the Read tool's line-number prefixes" | wc -l)" -eq 2 ] || exit 1; done``
- **AC2.2:** same command, with the token `'consequence'` replaced by `'one-line consequence'`.
- **AC2.3:** ``for f in agents/reviewer.md templates/persona-protocol.md .claude/agents/reviewer.md .claude/persona-protocol.md; do ! tr -s ' \n' ' ' < $f | grep -qF 'no new tool, no rendering' || exit 1; done && tr -s ' \n' ' ' < agents/reviewer.md | grep -qF 'plain markdown, no HTML'``
- **AC3.2:** ``grep -qx 'if bash tests/packet-view-script.test.sh; then' tests/validate.sh``
- **AC3.3:** ``node tests/adapter-protocol-parity.test.js && grep -F '// epf-2' tests/adapter-protocol-parity.test.js | grep -qF 'and `view.sh` commands'``
- **AC4.4:** keep the existing loop, then append ``&& for f in templates/persona-protocol.md .claude/persona-protocol.md; do [ "$(grep -cF 'under the exact `Non-blocking notes:` anchor' $f)" -ge 2 ] || { echo "prose sentence lost: $f"; exit 1; }; done``, keeping the final `exactly` grep.
- **AC4.6:** prefix `a=$(mktemp); b=$(mktemp); `, and replace `"${a:=$(mktemp)}"` / `"${b:=$(mktemp)}"` with `"$a"` / `"$b"`.
- Open Question 1 and R4: append "Resolved 2026-10-13 by epf-4 (table support in markdown-lite.js)."
- In the 2026-10-01 plan :928, change `'Never run \`run.sh\` yourself'` to `'Never run \`run.sh\`'` and append the trailing comment `# erratum 2026-10-13 (epf-6)`.

**Acceptance criteria:**
- AC6.1 (each corrected run line is green). **Verified** against a corrected scratch copy: all pass except AC3.3, which needs epf-2's probe.
  ```sh
  P=docs/plans/2026-10-12-escalation-packet-aesthetics.md
  runac() { cmd=$(awk -v id="- **$1** " 'index($0,id)==1{f=1;next} f&&/^  - run: `/{sub(/^  - run: `/,""); sub(/`$/,""); print; exit}' "$P")
    [ -n "$cmd" ] || { echo "$1: no run line"; return 1; }
    F=$(git log --format=%H -E --grep="^[a-z]+\\($2\\)" | tail -1); L=$(git log --format=%H -E --grep="^[a-z]+\\($2\\)" | head -1)
    F="$F" L="$L" bash -c "$cmd" >/dev/null 2>&1 || { echo "$1 exits non-zero"; return 1; }; }
  runac AC1.3 epa-1 && runac AC2.2 epa-2 && runac AC2.3 epa-2 && runac AC3.2 epa-3 && runac AC3.3 epa-3 && runac AC4.4 epa-4 && runac AC4.6 epa-4
  ```
- AC6.2 (each corrected criterion fails under its own mutation, in a worktree; use the AC6.1 extraction). **Verified** against the corrected copy: all killed (AC3.3 not run, since it needs epf-2). Mutations (`perl -0pi -e`):
  - AC1.3: orchestrator.md, `s/(3\. Read \`EXAMPLES\.md\`.*?), without the Read\s+tool.s line-number prefixes/$1/s`
  - AC2.2: reviewer.md, `s/one-line\s+consequence/consequence/`
  - AC2.3: template, `s/\z/\nno new tool, no rendering\n/`
  - AC3.2: validate.sh, `s/^if bash tests\/packet-view-script\.test\.sh; then/if true; then/m`
  - AC3.3: cursor port, ``s/`run\.sh` and `view\.sh` commands/`run.sh` command/``
  - AC4.4: template, ``s/under the exact `Non-blocking notes:` anchor/under the exact\n`Non-blocking notes:` anchor/``
  - AC4.6: orchestrator.md, `s/(6\. Make the \*\*prompt-confirmed decision write\*\*: run exactly one Bash) call/$1 command/`
- AC6.3 (2026-10-01 :928). Verified: today rc 1; with the change rc 0.
  ```sh
  line=$(grep -F "for f in agents/orchestrator.md .claude/agents/orchestrator.md; do grep -q 'AskUserQuestion'" docs/plans/2026-10-01-in-session-escalation-decision.md)
  echo "$line" | grep -qF 'erratum 2026-10-13 (epf-6)' && bash -c "$line"
  ```
- AC6.4: `grep -c '^  - erratum (2026-10-13, epf-6)' docs/plans/2026-10-12-escalation-packet-aesthetics.md` is at least 7, and `grep -q '^## Errata (2026-10-13, epf-6)'` succeeds. Scope: only the two plan files change.

## Open Questions

None blocking. Every decision above was self-resolved and recorded in
Clarifications; the user may overrule any of them. The decision most worth a
look is the hyphen-vs-em-dash direction (S13).

## Self-check
- CHK1: Does every scribe item 1-14 and every epa-N.pass note map to a unit or a verified "closed" check? — PASS (inventory S1-S14, N1-N10)
- CHK2: Do epf-1 and epf-2 agree on the order and version handling for their shared files? — PASS (R1; each re-derives its version)
- CHK3: Is the merge gate runnable under the 600 s cap? — PASS (G; 101 measured at 696 s and replaced by its own property across ranges)
- CHK4: Do new criteria avoid the AC2.3/AC4.6 defects (loop exit, `:=` in pipelines)? — PASS (every loop uses `|| exit 1`; no `${x:=…}`; temp files are assigned up front)
- CHK5: Is each new criterion non-vacuous at HEAD? — PASS (AC1.1-1.6, AC2.1-2.4, AC4.1-4.2, AC5.1 were run at HEAD and fail with the expected message)
- CHK6: Is a criterion missing for epf-4's CSS? — FAIL (ambiguous: AC4.4 is not prototyped) — revised in place: marked `unverified`
- CHK7: Does AC5.3 have an end-to-end run? — FAIL (missing) — revised in place: marked `unverified`, parts verified separately
- CHK8: Could the parity-test check from epf-1 collide with epf-2's probe edits? — PASS (different blocks of the same file; sequential per R1)
- CHK9 (replay, examples-2 [host]; gh348-3 / mw-step2 / mw-step3 [vacuous]): Does AC2.4 still fail when a probe literal is hard-wrapped in a port? — PASS (the AC2.4 mutation line)
- CHK10 (replay, gh310 / gh429 / gh348-14 / gh307 [vacuous]): Does AC1.1 fail when only the mirror lacks the rule? — PASS (the AC1.1 mutation)
- CHK11 (replay, dash-ux-2 / dash-ux-4 / dash-scroll-1 / dash-rail-collapse-1 [vacuous]): Does AC4.1 fail on the old renderer? — PASS (AC4.3(a), verified)
- CHK12 (replay, gh348-4 / gh360 / gh409 / gh413 / item04-2 / gh377-5 [vacuous/host] on bin/cli.js): Does AC5.1 fail under the old parser? — PASS (it fails at HEAD)
- CHK13 (replay, gh-303 / gh339 / gh354 / spec2-unitA/B / human-review-cleanup-1 [vacuous] on CONTEXT.md): Is AC1.4 entry-scoped, so that another entry cannot satisfy it? — PASS (the `entry()` awk stops at the next `**term**`)

## Scribe update hint
After epf-6 passes, mark items 1-14 closed in `.claude/agent-memory/scribe/project_epa2_completion.md`, naming the closing unit for each (inventory table). Glossary edits are in epf-1 and epf-2 already; no new term is minted.

## Dispatch contracts (task-master, standard path, 2026-10-13)

Sliced from this finalized spec by `task-master`. Six dispatchable units; none held. The spec's substance is unchanged.

**Retrieval contract.** No tracker issue exists for these units: the configured tracker is GitHub issues (`gh issue view <n> --repo Storreslara/AntiSlop`), but filing was not authorized in the slicing run, so the contracts live here. Fetch a unit's dispatch prompt by reading `docs/plans/2026-10-13-escalation-packet-followups.md` with the Read tool, finding the `### Unit: epf-N` heading under `## Dispatch contracts`, and sending the interior of the six-backtick fenced block that follows it (the lines between the fences; nested fences are payloads) as the dispatch prompt. Its first line is the literal `Unit: epf-N`, and `node bin/contract-guard.js docs/plans/2026-10-13-escalation-packet-followups.md --unit=epf-N` finds the block. Commit subjects therefore end with the version, not an issue number.

**Slice state:**

| unit | dispatchable or held | reason |
|---|---|---|
| epf-1 | dispatchable | contract scores 7 |
| epf-2 | dispatchable | contract scores 7; dispatch after epf-1 PASS |
| epf-3 | dispatchable | contract scores 7 |
| epf-4 | dispatchable | contract scores 7 |
| epf-5 | dispatchable | contract scores 7 |
| epf-6 | dispatchable | contract scores 7; dispatch after epf-2 and epf-4 PASS |

**Intersection table** (shared files exclude the bump files and the paths `node bin/cli.js --update` changes):

| unit | shared files | depends on |
|---|---|---|
| epf-1 | `templates/persona-protocol.md`, `tests/adapter-protocol-parity.test.js`, `CONTEXT.md` | none |
| epf-2 | `templates/persona-protocol.md`, `tests/adapter-protocol-parity.test.js`, `CONTEXT.md` | epf-1 |
| epf-3 | none | none |
| epf-4 | none | none |
| epf-5 | none | none |
| epf-6 | none | epf-2, epf-4 |

epf-1 and epf-2 are stamped units and serialize (versions 0.31.160 then 0.31.161; each re-derives its version from HEAD). epf-3, epf-4 and epf-5 are independent of every other unit; the suggested order is epf-1, epf-2, epf-3, epf-4, epf-5, epf-6, with epf-6 last (its corrected AC3.3 needs epf-2's `// epf-2` probe, and it marks Open Question 1 resolved by epf-4).

**Suggested models** (implementer tier; reactive tagging, so only recorded FAIL history raises it above the project default `haiku`): epf-1 sonnet, epf-2 sonnet, epf-4 sonnet, epf-3 haiku, epf-5 haiku, epf-6 haiku. The sonnet tags rest on the spec's area-wide FAIL history, spot-verified against the FAIL records of `dash-ux-1`, `packet-brevity-1` and `examples-2` for file overlap. The orchestrator recomputes the Escalation ladder at dispatch; a tag can raise the tier, never lower it. The reviewer tier is decided at dispatch time by the orchestrator running `hooks/scripts/reviewer-tier.sh` over each unit's actual diff; no contract predicts it.

**Criteria scripts.** Every criterion is `bash docs/plans/epf-criteria/<script>` run from the repository root (they `cd` to the repository root themselves); `docs/plans/epf-criteria/lib.sh` holds the shared `vsec`, `vrun` and unit-commit helpers, and the committed scripts carry the spec's bash blocks verbatim except where a note below says otherwise. The scripts are committed with this slicing output and are read-only for every unit.

**G: the merge gate** (carried from "Shared criterion idioms"; the orchestrator runs it after PASS for epf-1 and epf-2, optional for the others). Five separate Bash calls, each with `timeout: 600000`: (1) `ls -1 .claude/reviewed | md5sum` on its own, note the hash; (2) `export CLAUDE_PROJECT_DIR="$(git rev-parse --show-toplevel)" REVIEWED_DIR_LEAK_GUARD_NESTED=1` then `vsec 1 60`, after `source docs/plans/epf-criteria/lib.sh`; (3) the same exports and `vsec 61 108`; (4) the same exports, `vsec 109 110`, then `vsec 111 999` (split into two calls if it nears the cap); (5) `ls -1 .claude/reviewed | md5sum` again, on its own; it must equal (1). Pass when every `vsec` exits 0 and the hashes match. The ranges cover 1 to `grep -c '^echo "== ' tests/validate.sh`, which is 115; no unit adds a section. A different hash in (5) means another agent wrote a marker during the run: re-run.

**Slicing notes** (replayed 2026-10-13 in scratch worktrees of e44e70c; all six contracts score 7 under `node bin/contract-score.js --rubric=v2`):
- Every `run:` was executed at the unedited tree (red, except the criteria each marked `check:`, which guard an invariant), after the edits applied by script (green), and under each stated mutation (killed). The spec's two `unverified` criteria (epf-4 AC4.4, epf-5 AC5.3) are now verified end to end. The cumulative result of all six units applied in order was also run through the four `vsec` ranges with the nested leak guard skipped: all four exited 0.
- The spec's `:608-610` in `templates/persona-protocol.md` is lines 609-611 at HEAD; the contract anchors on the text, not the numbers.
- epf-1's re-wrap keeps `never pick one for them` on one physical line: the 2026-10-01 plan's criterion (corrected by epf-6) greps it line by line, and a wrap through it makes that criterion fail.
- epf-4 TB5: the spec says "five `<p>` lines"; the literal input has four non-fold lines, so the contract pins the exact output (four `<p>` and one `<hr />`, no `<table`). TB8 uses a one-cell header `| h |` so that `| x \| y |` is a body row.
- AC1.6 and AC2.3 measure line length in bytes (`LC_ALL=C`), the stricter reading; the wrapped lines pass either way.
- Unit commits are found by subject scope (`^[a-z]+\(epf-N\): `), never by `--grep`, so a body line cannot match.
- epf-1 and epf-2 edit scribe-scope files (`CONTEXT.md`, `.claude/wiki/architecture.md`) inside the same single commit the spec requires; no separate scribe contract is written. After epf-6 passes, `scribe` closes items 1-14 in `.claude/agent-memory/scribe/project_epa2_completion.md` (see "Scribe update hint").

### Unit: epf-1

- Suggested model: `sonnet` (the spec suggests no cheaper than sonnet; packet-brevity-1 (read 2026-10-13) names `templates/persona-protocol.md` and the generated mirrors this unit edits, lean-2 names the P3 rule it must follow.)
- Depends on / blocked by: none
- Spec step: Step 1; closes S12, N2, N3, N4, N10 (an old-format marker with no fold or `decide:` line has no orchestrator rule; steps 1-5 overflow 80 columns; the template still says "pastes" and "prints the marker verbatim"; nothing pins the orchestrator wording).
- Constraints carried from the spec: examples-2 (probes line-wrapped), packet-brevity-1 (mirrors hand-edited), reviewer-changes-examples-lean-2 (P3 missed): mirrors change only through `--update --force-render`, and the version bump rides in the same commit.
- Reviewer tier: decided at dispatch time by the orchestrator running `hooks/scripts/reviewer-tier.sh` over the unit's actual diff.

``````
Unit: epf-1

## Objective
The orchestrator prints a marker that has no `---` fold line whole, with no pointer line, and asks Q1 with the fixed question `How should this escalation be resolved?` when the marker has no `decide:` line. Steps 1-5 of the escalation text fit in 80 columns, the template no longer says "pastes", and a parity check pins the new wording. Version 0.31.160, mirrors refreshed.

## Retrieval
Plan-file contract: read `docs/plans/2026-10-13-escalation-packet-followups.md`, section `### Unit: epf-1` (dispatch contracts); no tracker issue exists. Run each criterion from the repository root.

## Affected files
- `agents/orchestrator.md` (anchor: line matching `1. Print the marker's lines 1 through the`)
- `templates/persona-protocol.md` (anchor: line matching `**The prompt-confirmed decision write.** The orchestrator prints the`)
- `CONTEXT.md` (anchor: line matching `through the fold line and no further.`)
- `.claude/wiki/architecture.md` (anchor: line matching `the orchestrator prints only through the fold.`)
- `tests/adapter-protocol-parity.test.js` (anchor: line matching `if (failures) {`)
- `.claude-plugin/plugin.json`, `package.json` (anchor: line matching `"version": "0.31.159",`)
- `CHANGELOG.md` (anchor: line matching `## [Unreleased]`)

## Ordered edits
1. file: `agents/orchestrator.md` (step 1: the no-fold rule and 80-column wrap)
   anchor: line matching `1. Print the marker's lines 1 through the`
   indent: 0
   before:
```
1. Print the marker's lines 1 through the `---` fold line in chat
   **verbatim** — the card carries the packet path, the `run.sh` command
   and the viewer command — then exactly one pointer line:
   `Full record (criteria, notes): .claude/reviewed/<task-id>.escalated, same text in the packet's PACKET.md`.
   Never summarize the record. The card's `packet:` line already carries the
   viewer command `sh .claude/human-review/<task-id>/view.sh`; do not print it
   a second time. Re-read the
   marker with the **Read tool** (ungated) whenever the human comes back, which
   may be a later session, after a restart, or from their own terminal; the
   packet is untracked-but-persistent, so nothing about this assumes the human
   was available the moment escalation fired.
```
   after:
```
1. Print the marker's lines 1 through the `---` fold line in chat **verbatim**
   — the card carries the packet path, the `run.sh` command and the viewer
   command — then exactly one pointer line:
   `Full record (criteria, notes): .claude/reviewed/<task-id>.escalated, same text in the packet's PACKET.md`.
   Never summarize the record. A marker with no `---` fold line was written
   before the card format: print the whole marker verbatim instead, with no
   pointer line. The card's `packet:` line already carries the viewer command
   `sh .claude/human-review/<task-id>/view.sh`; do not print it a second time.
   Re-read the marker with the **Read tool** (ungated) whenever the human comes
   back, which may be a later session, after a restart, or from their own
   terminal; the packet is untracked-but-persistent, so nothing about this
   assumes the human was available the moment escalation fired.
```
2. file: `agents/orchestrator.md` (step 2: 80-column wrap, wording unchanged)
   anchor: line matching `2. Read`
   indent: 0
   before:
```
2. Read `CHANGES.md` in that packet directory **(if present)** with the
   Read tool, then reproduce it as your own message text, outside any code
   fence, so the chat renders its markdown — **verbatim, in full**, no
   summary, no excerpt, without the Read tool's line-number prefixes. A tool
   result alone is not printing it: the human sees that as raw text. It is the **literate
   change summary** this project's `reviewer` (if present) wrote at escalation
   time. Tell the human to read it **before the diff**: it walks the change in
   conceptual order, which a raw alphabetical diff does not. It is
   comprehension material only — the `.escalated` marker stays the
   authoritative record, and `CHANGES.md` never carries a decision. A unit with
   no bundle still has one, and there it is the whole human-facing payload.
```
   after:
```
2. Read `CHANGES.md` in that packet directory **(if present)** with the Read
   tool, then reproduce it as your own message text, outside any code fence, so
   the chat renders its markdown — **verbatim, in full**, no summary, no
   excerpt, without the Read tool's line-number prefixes. A tool result alone is
   not printing it: the human sees that as raw text. It is the **literate change
   summary** this project's `reviewer` (if present) wrote at escalation time.
   Tell the human to read it **before the diff**: it walks the change in
   conceptual order, which a raw alphabetical diff does not. It is comprehension
   material only — the `.escalated` marker stays the authoritative record, and
   `CHANGES.md` never carries a decision. A unit with no bundle still has one,
   and there it is the whole human-facing payload.
```
3. file: `agents/orchestrator.md` (step 4: 80-column wrap, wording unchanged)
   anchor: line matching `4. **Never run`
   indent: 0
   before:
```
4. **Never run `run.sh` or `view.sh` yourself and never pre-digest a result** — that would
   restore the automation the escalation exists to interrupt. You surface the
   command; the human runs it.
```
   after:
```
4. **Never run `run.sh` or `view.sh` yourself and never pre-digest a result**
   — that would restore the automation the escalation exists to interrupt. You
   surface the command; the human runs it.
```
4. file: `agents/orchestrator.md` (step 5: the generic Q1 rule and 80-column wrap)
   anchor: line matching `5. Make **one**`
   indent: 0
   before:
```
5. Make **one** `AskUserQuestion` call. Q1 is the route, with options
   `approve`, `reject`, `direct` and `decide later`.
   Q1's description is the text after `decide: ` on the card, verbatim. Q2 is the examples answer,
   asked **only if `EXAMPLES.md` exists**, with options labelled exactly
   `reviewed` and `skipped`; its description says it is recorded on approve
   only. **Relay the human's token verbatim**; never pick one for them and
   never infer one from what they said. A free-text answer is never
   interpreted as a route or a token: ask again. `examples: skipped` is a
   legitimate answer — do not push back on it, warn about it, or ask again.
   On approve, the body carries `examples: <token>` from Q2, or
   `examples: none-offered` when no `EXAMPLES.md` exists, and no `examples:`
   line if Q2 was left unanswered. For `reject` or `direct`, ask for the
   reason or the prescribed fix in one plain chat follow-up and use the
   human's words **verbatim**.
```
   after:
```
5. Make **one** `AskUserQuestion` call. Q1 is the route, with options `approve`,
   `reject`, `direct` and `decide later`. Q1's description is the text after
   `decide: ` on the card, verbatim. When the marker has no `decide: ` line,
   Q1's description is exactly `How should this escalation be resolved?`. Q2 is
   the examples answer, asked **only if `EXAMPLES.md` exists**, with options
   labelled exactly `reviewed` and `skipped`; its description says it is
   recorded on approve only. **Relay the human's token verbatim**;
   never pick one for them and never infer one from what they said. A free-text
   answer is never interpreted as a route or a token: ask again.
   `examples: skipped` is a legitimate answer — do not push back on it, warn
   about it, or ask again. On approve, the body carries `examples: <token>` from
   Q2, or `examples: none-offered` when no `EXAMPLES.md` exists, and no
   `examples:` line if Q2 was left unanswered. For `reject` or `direct`, ask for
   the reason or the prescribed fix in one plain chat follow-up and use the
   human's words **verbatim**.
```
5. file: `templates/persona-protocol.md` (N4 and N10: the stale "verbatim marker" and "pastes" wording)
   anchor: line matching `**The prompt-confirmed decision write.** The orchestrator prints the`
   indent: 0
   before:
```
**The prompt-confirmed decision write.** The orchestrator prints the
`.escalated` marker verbatim in chat, pastes `CHANGES.md` and `EXAMPLES.md`
verbatim as its own message text, outside any code fence, so they render, and asks
```
   after:
```
**The prompt-confirmed decision write.** The orchestrator prints marker lines 1 through the `---` fold line verbatim in chat (the whole marker when it has no fold line), reproduces `CHANGES.md` and `EXAMPLES.md`
verbatim as its own message text, outside any code fence, so they render, and asks
```
6. file: `CONTEXT.md`
   anchor: line matching `through the fold line and no further.`
   before: `prints marker lines 1 through the fold line and no further.`
   after: `prints marker lines 1 through the fold line and no further. A marker with no fold line is printed whole.`
7. file: `CONTEXT.md` (escalation card entry)
   anchor: line matching `(epa-4, 2026-10-12) — the fixed six-line top of an`
   indent: 0
   before:
```
(epa-4, 2026-10-12) — the fixed six-line top of an `.escalated` marker body,
  below line 1: `why:`, `would-be verdict:`, `look first:`, `decide:`, `run:`
  and `packet:`, in that order, one line each. A single `---` fold line
  separates it from the record. The orchestrator prints only marker lines 1
  through the fold, plus one pointer line to the full record; Q1's description
  is the card's `decide:` text. The card is part of the marker body, so
  `PACKET.md` carries it byte-for-byte.
```
   after:
```
(epa-4, 2026-10-12) — the fixed six-line top of an `.escalated` marker body,
  below line 1: `why:`, `would-be verdict:`, `look first:`, `decide:`, `run:`
  and `packet:`, in that order, one line each. A single `---` fold line
  separates it from the record. The orchestrator prints only marker lines 1
  through the fold, plus one pointer line to the full record; Q1's description
  is the card's `decide:` text, or a fixed generic question when the marker has
  no `decide:` line. The card is part of the marker body, so
  `PACKET.md` carries it byte-for-byte.
```
8. file: `.claude/wiki/architecture.md`
   anchor: line matching `the orchestrator prints only through the fold.`
   before: `the orchestrator prints only through the fold.`
   after: `the orchestrator prints only through the fold; a marker with no fold is printed whole.`
9. file: `tests/adapter-protocol-parity.test.js` (the durable pin (N2))
   anchor: line matching `if (failures) {`
   indent: 0
   before: `if (failures) {`
   after:
```
// epf-1: the orchestrator escalation steps also handle a marker written before the card format.
check('orchestrator escalation steps handle a marker with no fold line or no decide: line', () => {
  const flat = (rel) => fs.readFileSync(path.join(REPO_ROOT, rel), 'utf8').replace(/\s+/g, ' ');
  const foldRule = 'A marker with no `---` fold line was written before the card format: print the whole marker verbatim instead, with no pointer line.';
  const decideRule = "When the marker has no `decide: ` line, Q1's description is exactly `How should this escalation be resolved?`.";
  for (const rel of ['agents/orchestrator.md', '.claude/agents/orchestrator.md']) {
    const t = flat(rel);
    assert.ok(t.includes(foldRule), `${rel}: missing the no-fold-line rule`);
    assert.ok(t.includes(decideRule), `${rel}: missing the no-decide-line rule`);
  }
  assert.ok(flat('templates/persona-protocol.md').includes('prints marker lines 1 through the `---` fold line verbatim in chat (the whole marker when it has no fold line)'),
    'templates/persona-protocol.md: missing the whole-marker clause');
});

if (failures) {
```
10. file: `.claude-plugin/plugin.json` (version 0.31.160)
   anchor: line matching `"version": "0.31.159",`
   before: `"version": "0.31.159",`
   after: `"version": "0.31.160",`
11. file: `package.json` (version 0.31.160)
   anchor: line matching `"version": "0.31.159",`
   before: `"version": "0.31.159",`
   after: `"version": "0.31.160",`
12. file: `CHANGELOG.md`
   anchor: line matching `## [Unreleased]`
   indent: 0
   insert-after:
```

**Orchestrator prints an old-format marker whole (epf-1, 0.31.160).** `agents/orchestrator.md` (escalation steps 1 and 5) and `templates/persona-protocol.md` (the prompt-confirmed decision write): a marker with no `---` fold line is printed whole with no pointer line, and Q1's description is a fixed generic question when the marker has no `decide:` line; steps 1-5 are re-wrapped to 80 columns, and the template now says the orchestrator reproduces `CHANGES.md` and `EXAMPLES.md` instead of pasting them. `CONTEXT.md` (fold line, escalation card), `.claude/wiki/architecture.md` and a new `tests/adapter-protocol-parity.test.js` check agree. Mirrors refreshed by `node bin/cli.js --update --force-render`.
```
13. command: `node bin/cli.js --update --force-render`
   expect: 0
14. command: `git status --porcelain --untracked-files=no -- .claude | wc -l`
   expect: 0
   stdout: `15`
15. command: `git add agents/orchestrator.md templates/persona-protocol.md CONTEXT.md .claude/wiki/architecture.md tests/adapter-protocol-parity.test.js CHANGELOG.md package.json .claude-plugin/plugin.json && git add -u -- .claude && git commit -m "docs(epf-1): orchestrator prints a marker with no card whole (0.31.160)" -m "Co-Authored-By: Claude Sonnet 5.5 <noreply@anthropic.com>"`
   expect: 0
16. command: `git status --porcelain --untracked-files=no | wc -l`
   expect: 0
   stdout: `0`

## Do NOT touch
- `.claude/agents/orchestrator.md` and every other `.claude/` mirror: regenerate with `node bin/cli.js --update --force-render` only; a hand edit is a P2 violation (packet-brevity-1).
- `agents/orchestrator.md` step 3 and step 6 onward: byte-unchanged (the corrected epa AC4.6 compares step 6).
- `agents/reviewer.md`: epf-2 owns it.
- `adapters/`: neither port carries this orchestrator or "pastes" text.
- `tests/packet-view-script.test.sh`: epf-3 owns it; T10 there only reads steps 2 and 3.
- `docs/plans/`: epf-6 owns every plan edit, and `docs/plans/epf-criteria/` is read-only.
- `.claude/persona-config.json`: `--update` restamps its fileHashes; never hand-edit it.

## Acceptance criteria
1. run: `bash docs/plans/epf-criteria/epf1-ac1.sh`
   exit: 0
   stdout: empty
   mutation: skip edit 1; prints `MISSING fold rule: agents/orchestrator.md`, exit 1.
   proof: replayed by task-master in a scratch worktree of e44e70c: the edits applied by script, then this mutation; the stated exit and stdout were observed.
2. run: `bash docs/plans/epf-criteria/epf1-ac3.sh`
   exit: 0
   stdout: empty
   mutation: skip edit 5; prints `MISSING: templates/persona-protocol.md`, exit 1.
   proof: replayed by task-master in a scratch worktree of e44e70c: the edits applied by script, then this mutation; the stated exit and stdout were observed.
3. run: `bash docs/plans/epf-criteria/epf1-ac4.sh`
   exit: 0
   stdout: empty
   mutation: skip edit 8; prints `wiki`, exit 1.
   proof: replayed by task-master in a scratch worktree of e44e70c: the edits applied by script, then this mutation; the stated exit and stdout were observed.
4. run: `bash docs/plans/epf-criteria/epf1-ac5.sh`
   exit: 0
   stdout: empty
   mutation: skip edit 1; the new check fails against the unchanged orchestrator, exit 1.
   proof: replayed by task-master in a scratch worktree of e44e70c: the edits applied by script, then this mutation; the stated exit and stdout were observed.
5. run: `bash docs/plans/epf-criteria/epf1-ac6.sh`
   exit: 0
   stdout: empty
   mutation: skip edit 2; prints `1 over-80 lines in steps 1-5`, exit 1.
   proof: replayed by task-master in a scratch worktree of e44e70c: the edits applied by script, then this mutation; the stated exit and stdout were observed.
6. run: `bash docs/plans/epf-criteria/epf1-ac7.sh`
   exit: 0
   stdout: empty
   mutation: change a word of step 6 (run exactly one Bash call to run exactly one Bash command); prints `AC4.6 step 6 changed`, exit 1.
   check: green at e44e70c on purpose; it guards an invariant the edits must keep, so it is not red before the edit.
   proof: replayed by task-master in a scratch worktree of e44e70c: the edits applied by script, then this mutation; the stated exit and stdout were observed.
7. run: `bash docs/plans/epf-criteria/epf1-ac8.sh`
   exit: 0
   stdout: empty
   mutation: commit a change to `agents/reviewer.md` under this unit scope; prints `out of scope: agents/reviewer.md`, exit 1.
   proof: replayed by task-master in a scratch worktree of e44e70c: the edits applied by script, then this mutation; the stated exit and stdout were observed.
8. run: `bash -c '. docs/plans/epf-criteria/lib.sh; for c in $(ucommits epf-1); do bash hooks/scripts/version-stamp-check.sh "$c~1..$c"; done' | grep -c '^version-stamp-check: ok'`
   exit: 0
   stdout: `1`
   mutation: skip edit 10; the line no longer reads ok (the script reads only plugin.json), prints `0`, exit 1.
   proof: replayed by task-master in a scratch worktree of e44e70c: the edits applied by script, then this mutation; the stated exit and stdout were observed.
9. run: `bash docs/plans/epf-criteria/p3.sh epf-1`
   exit: 0
   stdout: empty
   mutation: skip edit 13; prints `update --dry-run rc!=0 (stale mirror)`, exit 1.
   proof: replayed by task-master in a scratch worktree of e44e70c: the edits applied by script, then this mutation; the stated exit and stdout were observed.
10. run: `bash docs/plans/epf-criteria/vtargeted.sh 'adapter protocol-port parity' 'packet viewer' 'persona-config fileHashes' 'version-stamp-check' 'protocol doc-drift'`
   exit: 0
   stdout: empty
   mutation: skip edit 13; the parity section fails against the stale mirror, prints `section group failed: adapter protocol-port parity`, exit 1.
   check: green at e44e70c on purpose; it guards an invariant the edits must keep, so it is not red before the edit.
   proof: replayed by task-master in a scratch worktree of e44e70c: the edits applied by script, then this mutation; the stated exit and stdout were observed.
11. run: `bash docs/plans/epf-criteria/range.sh epf-1 trailer`
   exit: 0
   stdout: `1`
   mutation: amend the commit without its trailer; prints `0`.
   proof: replayed by task-master in a scratch worktree of e44e70c: the edits applied by script, then this mutation; the stated exit and stdout were observed.
12. run: `bash docs/plans/epf-criteria/range.sh epf-1 tail agents/orchestrator.md templates/persona-protocol.md CONTEXT.md tests/adapter-protocol-parity.test.js`
   exit: 1
   stdout: `0`
   mutation: add a later commit touching `agents/orchestrator.md` with a subject outside this unit scope; prints `1`, exit 0.
   proof: replayed by task-master in a scratch worktree of e44e70c: the edits applied by script, then this mutation; the stated exit and stdout were observed.
13. run: `git status --porcelain --untracked-files=no | wc -l`
   exit: 0
   stdout: `0`
   mutation: leave one tracked file modified; prints `1`.
   check: green at e44e70c on purpose; it guards an invariant the edits must keep, so it is not red before the edit.
   proof: replayed by task-master in a scratch worktree of e44e70c: the edits applied by script, then this mutation; the stated exit and stdout were observed.

## Pre-resolved context
tdd: yes tests/adapter-protocol-parity.test.js
blast-radius: tests/packet-view-script.test.sh:94 tests/adapter-protocol-parity.test.js:203 (grep-derived readers of the edited prose; no other test reads steps 1-5)
commit-message: docs(epf-1): orchestrator prints a marker with no card whole (0.31.160)
trailer: -m "Co-Authored-By: Claude Sonnet 5.5 <noreply@anthropic.com>" is the last line of the commit message.
mirrors: after `node bin/cli.js --update --force-render` the command in edit 14 must print 15 (the 14 stamped mirrors plus `.claude/wiki/architecture.md`); any other count means STOP.
version: HEAD is 0.31.159; this unit sets 0.31.160 (patch +1). epf-2 then sets 0.31.161.
merge-gate: the orchestrator runs G (see the plan section "Shared criterion idioms") after PASS: the md5sum call as its own Bash call, then `vsec 1 60`, `vsec 61 108`, `vsec 109 110` and `vsec 111 999` with `REVIEWED_DIR_LEAK_GUARD_NESTED=1` in separate Bash calls of `timeout: 600000`, then the md5sum call again; the two hashes must match. Do not run G yourself.
tree: commit your own agent-memory notes in their own commit first; every command and criterion here assumes `git status --porcelain` is empty at the start.
diagnosis: none
review-packet:
~~~
unit: epf-1 (plan docs/plans/2026-10-13-escalation-packet-followups.md)
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

## Escalation
If any instruction cannot be followed exactly as written, STOP and report a spec gap; do not improvise.
``````

### Unit: epf-2

- Suggested model: `sonnet` (the spec suggests no cheaper than sonnet; examples-2 (read 2026-10-13) names the two ports and the parity test this unit edits.)
- Depends on / blocked by: epf-1
- Spec step: Step 2; closes S2, S7 (probe), S13, S14, N6 (parity probes lack three layout literals; the skip token is spelled two ways; the card block orphans the next paragraph; ragged wrapping).
- Constraints carried from the spec: examples-2: every probe literal stays on ONE physical line in both ports; packet-brevity-1 and lean-2 as for epf-1.
- Reviewer tier: decided at dispatch time by the orchestrator running `hooks/scripts/reviewer-tier.sh` over the unit's actual diff.

``````
Unit: epf-2

## Objective
The reviewer prose spells the skip token `examples: none - <one-line reason>` with an ASCII hyphen everywhere, the paragraph after the escalation card is a list item, every layout-anchor line is 80 columns or less in all four sources, and the parity test probes `**After:**`, the example heading, the `>` blockquote line and the `run.sh` and `view.sh` commands. Version 0.31.161, mirrors refreshed.

## Retrieval
Plan-file contract: read `docs/plans/2026-10-13-escalation-packet-followups.md`, section `### Unit: epf-2` (dispatch contracts); no tracker issue exists. Run each criterion from the repository root.

## Affected files
- `agents/reviewer.md` (anchor: line matching `table, one`)
- `templates/persona-protocol.md` (anchor: line matching `examples: none — <one-line reason>`)
- `adapters/codex/agents-md-fragment.md` (anchor: line matching `blockquote line naming the single place to look at first`)
- `adapters/cursor/rules/persona-protocol.mdc` (anchor: line matching `blockquote line naming the single place to look at first`)
- `CONTEXT.md` (anchor: line matching `examples: none — <one-line reason>`)
- `tests/adapter-protocol-parity.test.js` (anchor: line matching `commit: <sha at escalation>',  // epa-4: the fold`)
- `.claude-plugin/plugin.json`, `package.json` (anchor: line matching `"version": "0.31.160",`)
- `CHANGELOG.md` (anchor: line matching `## [Unreleased]`)

## Ordered edits
1. file: `agents/reviewer.md` (re-wrap the table row and the example paragraph; the ASCII hyphen in the skip token)
   anchor: line matching `table, one`
   indent: 0
   before:
```
  `| Where | What to check |` table, one `file:line` per row. A unit with no bundle
  still gets a `CHANGES.md`; there it carries the entire human-facing payload.
  It is deleted with the rest of the packet when you resolve the escalation.
- **`EXAMPLES.md` — the worked examples you write but never grade**: written
  into the packet directory in that same action whenever the change has an
  **observable behavioural consequence**. **3 to 5 worked examples**, each a
  **behavioural before/after** ("before this change, X did Y; after, X does
  Z"), grounded in `CHANGES.md` and the bundle alone, and about **consequence,
  not recall** — "what happens to X when Y is absent?", never "what is the new
  function called?" (recall is skimmable, which defeats the point). Each
  example is **2 to 4 lines under its heading**: the before/after statement and nothing else —
  no preamble, no scene-setting, no "why it matters" beyond the one-line
  consequence. **Layout:** each example is a `### <n>. <one-phrase title>`
  heading, then a `**Before:**` line and an `**After:**` line, plus at
  most one consequence line. Skip it when the change has no behavioural surface — pure docs,
  formatting, comments, pure renames — but log the skip: fill the record's
  `examples:` line, below the `---` fold, in the `.escalated` marker body,
  `examples: <count>` when you wrote it
  or `examples: none — <one-line reason>` when you did not, so a skip is a
```
   after:
```
  `| Where | What to check |` table, one `file:line` per row. A unit with no
  bundle still gets a `CHANGES.md`; there it carries the entire human-facing
  payload. It is deleted with the rest of the packet when you resolve the
  escalation.
- **`EXAMPLES.md` — the worked examples you write but never grade**: written
  into the packet directory in that same action whenever the change has an
  **observable behavioural consequence**. **3 to 5 worked examples**, each a
  **behavioural before/after** ("before this change, X did Y; after, X does
  Z"), grounded in `CHANGES.md` and the bundle alone, and about **consequence,
  not recall** — "what happens to X when Y is absent?", never "what is the new
  function called?" (recall is skimmable, which defeats the point). Each
  example is **2 to 4 lines under its heading**: the before/after statement
  and nothing else — no preamble, no scene-setting, no "why it matters" beyond
  the one-line consequence. **Layout:** each example is a
  `### <n>. <one-phrase title>` heading, then a `**Before:**` line and an
  `**After:**` line, plus at most one consequence line. Skip it when the change
  has no behavioural surface — pure docs, formatting, comments, pure renames —
  but log the skip: fill the record's `examples:` line, below the `---` fold,
  in the `.escalated` marker body, `examples: <count>` when you wrote it
  or `examples: none - <one-line reason>` when you did not, so a skip is a
```
2. file: `agents/reviewer.md` (the card follow-on becomes a list item)
   anchor: line matching `In the **same action**, snapshot the unit's bundle to`
   indent: 0
   before: `In the **same action**, snapshot the unit's bundle to`
   after:
```
- **Durable escalation packet**: in the **same action** that writes the marker,
  snapshot the unit's bundle to
```
3. file: `templates/persona-protocol.md`
   anchor: line matching `examples: none — <one-line reason>`
   before: `examples: none — <one-line reason>`
   after: `examples: none - <one-line reason>`
4. file: `CONTEXT.md`
   anchor: line matching `examples: none — <one-line reason>`
   before: `examples: none — <one-line reason>`
   after: `examples: none - <one-line reason>`
5. file: `adapters/codex/agents-md-fragment.md` (codex port: re-wrap the What-to-look-at-first lines)
   anchor: line matching `blockquote line naming the single place to look at first`
   indent: 0
   before:
```
`## What to look at first` with one `>` blockquote line naming the single place to look at first, then a
`| Where | What to check |` table, one `file:line` per row. A unit with
no bundle still gets one, and there it carries the entire human-facing payload.
```
   after:
```
`## What to look at first` with one `>` blockquote line naming the single place
to look at first, then a `| Where | What to check |` table, one `file:line` per
row. A unit with no bundle still gets one, and there it carries the entire
human-facing payload.
```
6. file: `adapters/codex/agents-md-fragment.md` (codex port: re-wrap the example layout lines)
   anchor: line matching `the point). Each example is 2 to 4 lines under its heading`
   indent: 0
   before:
```
the point). Each example is 2 to 4 lines under its heading: the before/after statement and
nothing else - no preamble, no scene-setting. **Layout:** each example is a
`### <n>. <one-phrase title>` heading, then a `**Before:**` line and an
`**After:**` line, plus at most one consequence line. **When needed:** written whenever
the change has an observable behavioural consequence; skipped when it has none
```
   after:
```
the point). Each example is 2 to 4 lines under its heading: the before/after
statement and nothing else - no preamble, no scene-setting. **Layout:** each
example is a `### <n>. <one-phrase title>` heading, then a `**Before:**` line
and an `**After:**` line, plus at most one consequence line. **When needed:**
written whenever the change has an observable behavioural consequence; skipped
when it has none
```
7. file: `adapters/cursor/rules/persona-protocol.mdc` (cursor port: re-wrap the What-to-look-at-first lines)
   anchor: line matching `blockquote line naming the single place to look at first`
   indent: 0
   before:
```
`## What to look at first` with one `>` blockquote line naming the single place to look at first, then a
`| Where | What to check |` table, one `file:line` per row. A unit with
no bundle still gets one, and there it carries the entire human-facing payload.
```
   after:
```
`## What to look at first` with one `>` blockquote line naming the single place
to look at first, then a `| Where | What to check |` table, one `file:line` per
row. A unit with no bundle still gets one, and there it carries the entire
human-facing payload.
```
8. file: `adapters/cursor/rules/persona-protocol.mdc` (cursor port: re-wrap the example layout lines)
   anchor: line matching `the point). Each example is 2 to 4 lines under its heading`
   indent: 0
   before:
```
the point). Each example is 2 to 4 lines under its heading: the before/after statement and
nothing else - no preamble, no scene-setting. **Layout:** each example is a
`### <n>. <one-phrase title>` heading, then a `**Before:**` line and an
`**After:**` line, plus at most one consequence line. **When needed:** written whenever
the change has an observable behavioural consequence; skipped when it has none
```
   after:
```
the point). Each example is 2 to 4 lines under its heading: the before/after
statement and nothing else - no preamble, no scene-setting. **Layout:** each
example is a `### <n>. <one-phrase title>` heading, then a `**Before:**` line
and an `**After:**` line, plus at most one consequence line. **When needed:**
written whenever the change has an observable behavioural consequence; skipped
when it has none
```
9. file: `tests/adapter-protocol-parity.test.js` (four probes, each tagged // epf-2)
   anchor: line matching `commit: <sha at escalation>',  // epa-4: the fold`
   indent: 0
   before:
```
  '\n---\ncommit: <sha at escalation>',  // epa-4: the fold, directly followed by commit:
];
```
   after:
```
  '\n---\ncommit: <sha at escalation>',  // epa-4: the fold, directly followed by commit:
  '**After:**',  // epf-2
  '### <n>. <one-phrase title>',  // epf-2
  'one `>` blockquote line',  // epf-2
  '`run.sh` and `view.sh` commands',  // epf-2: the prose probe; the view.sh block's own comments cannot satisfy it
];
```
10. file: `.claude-plugin/plugin.json` (version 0.31.161)
   anchor: line matching `"version": "0.31.160",`
   before: `"version": "0.31.160",`
   after: `"version": "0.31.161",`
11. file: `package.json` (version 0.31.161)
   anchor: line matching `"version": "0.31.160",`
   before: `"version": "0.31.160",`
   after: `"version": "0.31.161",`
12. file: `CHANGELOG.md`
   anchor: line matching `## [Unreleased]`
   indent: 0
   insert-after:
```

**Reviewer prose consistency and parity probes (epf-2, 0.31.161).** `agents/reviewer.md`, `templates/persona-protocol.md`, `CONTEXT.md` and both adapter ports: the skip token is spelled `examples: none - <one-line reason>` with an ASCII hyphen everywhere; the paragraph after the escalation card is a list item (`Durable escalation packet`), so it no longer renders as a loose paragraph; every layout-anchor line is 80 columns or less. `tests/adapter-protocol-parity.test.js` gains four probes (`**After:**`, the example heading, the `>` blockquote line, the `run.sh` and `view.sh` commands). Mirrors refreshed by `node bin/cli.js --update --force-render`.
```
13. command: `node bin/cli.js --update --force-render`
   expect: 0
14. command: `git status --porcelain --untracked-files=no -- .claude | wc -l`
   expect: 0
   stdout: `14`
15. command: `git add agents/reviewer.md templates/persona-protocol.md adapters/codex/agents-md-fragment.md adapters/cursor/rules/persona-protocol.mdc CONTEXT.md tests/adapter-protocol-parity.test.js CHANGELOG.md package.json .claude-plugin/plugin.json && git add -u -- .claude && git commit -m "docs(epf-2): reviewer prose consistency and parity probes (0.31.161)" -m "Co-Authored-By: Claude Sonnet 5.5 <noreply@anthropic.com>"`
   expect: 0
16. command: `git status --porcelain --untracked-files=no | wc -l`
   expect: 0
   stdout: `0`

## Do NOT touch
- `.claude/agents/reviewer.md` and every other `.claude/` mirror: regenerate with `node bin/cli.js --update --force-render` only; a hand edit is a P2 violation (packet-brevity-1).
- `agents/reviewer.md` between `<!-- escalated-card:begin -->` and `<!-- escalated-card:end -->`, and the `view.sh` block: byte-unchanged (six-copy identity checks read them).
- `agents/orchestrator.md`: epf-1 owns it.
- `bin/` and `hooks/`: no reader of the skip token changes; only `examples: none-offered` is machine-read.
- `tests/packet-view-script.test.sh`: epf-3 owns it.
- `docs/plans/`: epf-6 owns every plan edit, and `docs/plans/epf-criteria/` is read-only.
- `.claude/persona-config.json`: `--update` restamps its fileHashes; never hand-edit it.

## Acceptance criteria
1. run: `bash docs/plans/epf-criteria/epf2-ac1.sh`
   exit: 0
   stdout: empty
   mutation: skip edit 3; prints `EM DASH left: templates/persona-protocol.md`, exit 1.
   proof: replayed by task-master in a scratch worktree of e44e70c: the edits applied by script, then this mutation; the stated exit and stdout were observed.
2. run: `bash docs/plans/epf-criteria/epf2-ac2.sh`
   exit: 0
   stdout: empty
   mutation: skip edit 2; prints `line after card in agents/reviewer.md: In the **same action**, ...`, exit 1.
   proof: replayed by task-master in a scratch worktree of e44e70c: the edits applied by script, then this mutation; the stated exit and stdout were observed.
3. run: `bash docs/plans/epf-criteria/epf2-ac3.sh`
   exit: 0
   stdout: empty
   mutation: skip edit 1; prints `agents/reviewer.md: 3 anchor line(s) over 80 columns`, exit 1.
   proof: replayed by task-master in a scratch worktree of e44e70c: the edits applied by script, then this mutation; the stated exit and stdout were observed.
4. run: `bash docs/plans/epf-criteria/epf2-ac4.sh`
   exit: 0
   stdout: empty
   mutation: skip edit 9; prints `probe missing or untagged: '**After:**'`, exit 1.
   proof: replayed by task-master in a scratch worktree of e44e70c: the edits applied by script, then this mutation; the stated exit and stdout were observed.
5. run: `bash docs/plans/epf-criteria/epf2-ac5.sh`
   exit: 0
   stdout: empty
   mutation: change `<PASS|FAIL>` to `<PASS/FAIL>` in the codex card block; the parity test fails, exit 1.
   check: green at e44e70c on purpose; it guards an invariant the edits must keep, so it is not red before the edit.
   proof: replayed by task-master in a scratch worktree of e44e70c: the edits applied by script, then this mutation; the stated exit and stdout were observed.
6. run: `bash docs/plans/epf-criteria/epf2-ac6.sh`
   exit: 0
   stdout: empty
   mutation: commit a change to `agents/orchestrator.md` under this unit scope; prints `out of scope: agents/orchestrator.md`, exit 1.
   proof: replayed by task-master in a scratch worktree of e44e70c: the edits applied by script, then this mutation; the stated exit and stdout were observed.
7. run: `bash -c '. docs/plans/epf-criteria/lib.sh; for c in $(ucommits epf-2); do bash hooks/scripts/version-stamp-check.sh "$c~1..$c"; done' | grep -c '^version-stamp-check: ok'`
   exit: 0
   stdout: `1`
   mutation: skip edit 10; the line no longer reads ok (the script reads only plugin.json), prints `0`, exit 1.
   proof: replayed by task-master in a scratch worktree of e44e70c: the edits applied by script, then this mutation; the stated exit and stdout were observed.
8. run: `bash docs/plans/epf-criteria/p3.sh epf-2`
   exit: 0
   stdout: empty
   mutation: skip edit 13; prints `update --dry-run rc!=0 (stale mirror)`, exit 1.
   proof: replayed by task-master in a scratch worktree of e44e70c: the edits applied by script, then this mutation; the stated exit and stdout were observed.
9. run: `bash docs/plans/epf-criteria/vtargeted.sh 'adapter protocol-port parity' 'packet viewer' 'persona-config fileHashes' 'version-stamp-check' 'protocol doc-drift'`
   exit: 0
   stdout: empty
   mutation: change `<PASS|FAIL>` to `<PASS/FAIL>` in the codex card block; the parity section fails, prints `section group failed: adapter protocol-port parity`, exit 1.
   check: green at e44e70c on purpose; it guards an invariant the edits must keep, so it is not red before the edit.
   proof: replayed by task-master in a scratch worktree of e44e70c: the edits applied by script, then this mutation; the stated exit and stdout were observed.
10. run: `bash docs/plans/epf-criteria/range.sh epf-2 trailer`
   exit: 0
   stdout: `1`
   mutation: amend the commit without its trailer; prints `0`.
   proof: replayed by task-master in a scratch worktree of e44e70c: the edits applied by script, then this mutation; the stated exit and stdout were observed.
11. run: `bash docs/plans/epf-criteria/range.sh epf-2 tail agents/reviewer.md templates/persona-protocol.md adapters/codex/agents-md-fragment.md adapters/cursor/rules/persona-protocol.mdc CONTEXT.md tests/adapter-protocol-parity.test.js`
   exit: 1
   stdout: `0`
   mutation: add a later commit touching `agents/reviewer.md` with a subject outside this unit scope; prints `1`, exit 0.
   proof: replayed by task-master in a scratch worktree of e44e70c: the edits applied by script, then this mutation; the stated exit and stdout were observed.
12. run: `git status --porcelain --untracked-files=no | wc -l`
   exit: 0
   stdout: `0`
   mutation: leave one tracked file modified; prints `1`.
   check: green at e44e70c on purpose; it guards an invariant the edits must keep, so it is not red before the edit.
   proof: replayed by task-master in a scratch worktree of e44e70c: the edits applied by script, then this mutation; the stated exit and stdout were observed.

## Pre-resolved context
tdd: yes tests/adapter-protocol-parity.test.js
blast-radius: tests/adapter-protocol-parity.test.js:60 tests/packet-view-script.test.sh:20 (grep-derived readers of the edited prose: the probe array and the six-copy extractor; nothing machine-reads the skip token)
commit-message: docs(epf-2): reviewer prose consistency and parity probes (0.31.161)
trailer: -m "Co-Authored-By: Claude Sonnet 5.5 <noreply@anthropic.com>" is the last line of the commit message.
mirrors: after `node bin/cli.js --update --force-render` the command in edit 14 must print 14 (the 14 stamped mirrors); any other count means STOP.
order: dispatch only after epf-1 has a PASS marker and its commit is on the branch; this unit takes version 0.31.161 from 0.31.160 (patch +1). Every literal probe stays on ONE physical line (examples-2).
merge-gate: the orchestrator runs G (see the plan section "Shared criterion idioms") after PASS: the md5sum call as its own Bash call, then `vsec 1 60`, `vsec 61 108`, `vsec 109 110` and `vsec 111 999` with `REVIEWED_DIR_LEAK_GUARD_NESTED=1` in separate Bash calls of `timeout: 600000`, then the md5sum call again; the two hashes must match. Do not run G yourself.
tree: commit your own agent-memory notes in their own commit first; every command and criterion here assumes `git status --porcelain` is empty at the start.
diagnosis: none
review-packet:
~~~
unit: epf-2 (plan docs/plans/2026-10-13-escalation-packet-followups.md)
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
~~~

## Escalation
If any instruction cannot be followed exactly as written, STOP and report a spec gap; do not improvise.
``````

### Unit: epf-3

- Suggested model: `haiku` (the default tier: the unit is a test-only change whose payloads are written out literally and whose six mutations were replayed.)
- Depends on / blocked by: none
- Spec step: Step 3; closes S4, S5, S6 (the view.sh fallback order is not pinned; a dropped missing-file skip is not caught; the six copies are compared only with each other).
- Constraints carried from the spec: none recorded for this file.
- Reviewer tier: decided at dispatch time by the orchestrator running `hooks/scripts/reviewer-tier.sh` over the unit's actual diff.

``````
Unit: epf-3

## Objective
`tests/packet-view-script.test.sh` pins what it only implied: the six viewer copies equal the canonical viewer (T1b), a dropped missing-file skip is caught through stderr (T8), and the renderer fallback order glow, bat, batcat, rich, cat is pinned by O1-O4. All six mutations of the viewer copies are killed.

## Retrieval
Plan-file contract: read `docs/plans/2026-10-13-escalation-packet-followups.md`, section `### Unit: epf-3` (dispatch contracts); no tracker issue exists. Run each criterion from the repository root.

## Affected files
- `tests/packet-view-script.test.sh` (anchor: line matching `script="$tmp/ref"`)

## Ordered edits
1. file: `tests/packet-view-script.test.sh` (T1b: compare the copies with the canonical viewer)
   anchor: line matching `script="$tmp/ref"`
   indent: 0
   insert-after:
```
cat > "$tmp/canon" <<'VIEW_SH_CANONICAL'
#!/bin/sh
# Escalation packet viewer: renders CHANGES.md and EXAMPLES.md in colour when
# glow, bat or rich is installed, else prints them plain. Read-only.
dir=$(cd "$(dirname "$0")" && pwd)
for f in CHANGES.md EXAMPLES.md; do
  p="$dir/$f"
  [ -f "$p" ] || continue
  if command -v glow >/dev/null 2>&1 && glow "$p"; then :
  elif command -v bat >/dev/null 2>&1 && bat --paging=never -l md "$p"; then :
  elif command -v batcat >/dev/null 2>&1 && batcat --paging=never -l md "$p"; then :
  elif command -v rich >/dev/null 2>&1 && rich --markdown "$p"; then :
  else cat "$p"
  fi
done
exit 0
VIEW_SH_CANONICAL
if cmp -s "$tmp/ref" "$tmp/canon"; then pass "T1b copies equal the canonical viewer"
else bad "T1b copies differ from the canonical viewer"; fi
```
2. file: `tests/packet-view-script.test.sh` (runv keeps stderr)
   anchor: line matching `env -i PATH="$tmp/$1" "$sh_bin" "$pkt/view.sh")" || rc=$?`
   before: `"$sh_bin" "$pkt/view.sh")" || rc=$?`
   after: `"$sh_bin" "$pkt/view.sh" 2>"$tmp/err")" || rc=$?`
3. file: `tests/packet-view-script.test.sh` (T8 requires empty stderr)
   anchor: line matching `[ "$out" = "$(cat "$pkt/CHANGES.md")" ] && [ "$rc" = 0 ]`
   before: `[ "$out" = "$(cat "$pkt/CHANGES.md")" ] && [ "$rc" = 0 ] \`
   after: `[ "$out" = "$(cat "$pkt/CHANGES.md")" ] && [ "$rc" = 0 ] && [ ! -s "$tmp/err" ] \`
4. file: `tests/packet-view-script.test.sh`
   anchor: line matching `&& pass "T8 missing EXAMPLES.md skipped, rc 0"`
   before: `&& pass "T8 missing EXAMPLES.md skipped, rc 0" || bad "T8 missing EXAMPLES.md (rc=$rc)"`
   after: `&& pass "T8 missing EXAMPLES.md skipped, rc 0, stderr empty" || bad "T8 missing EXAMPLES.md (rc=$rc, stderr=$(cat "$tmp/err"))"`
5. file: `tests/packet-view-script.test.sh` (O1-O4: fallback order)
   anchor: line matching `&& pass "T7 rich --markdown used" || bad "T7 rich: $out"`
   indent: 0
   insert-after:
```

# O1-O4 - fallback order: with two renderers on PATH only the earlier one may run
cnt() { printf '%s\n' "$out" | grep -c "^$1:"; }
mkbin o1; stub o1 glow 0; stub o1 bat 0; runv o1
[ "$(cnt GLOW)" = 2 ] && [ "$(cnt BAT)" = 0 ] \
  && pass "O1 glow before bat" || bad "O1 glow before bat: $out"
mkbin o2; stub o2 bat 0; stub o2 batcat 0; runv o2
[ "$(cnt BAT)" = 2 ] && [ "$(cnt BATCAT)" = 0 ] \
  && pass "O2 bat before batcat" || bad "O2 bat before batcat: $out"
mkbin o3; stub o3 batcat 0; stub o3 rich 0; runv o3
[ "$(cnt BATCAT)" = 2 ] && [ "$(cnt RICH)" = 0 ] \
  && pass "O3 batcat before rich" || bad "O3 batcat before rich: $out"
mkbin o4; stub o4 rich 0; runv o4
[ "$(cnt RICH)" = 2 ] && ! printf '%s' "$out" | grep -q 'raw' \
  && pass "O4 rich before cat" || bad "O4 rich before cat: $out"
```
6. command: `git add tests/packet-view-script.test.sh && git commit -m "test(epf-3): view.sh golden copy, stderr check and fallback order" -m "Co-Authored-By: Claude Sonnet 5.5 <noreply@anthropic.com>"`
   expect: 0
7. command: `git status --porcelain --untracked-files=no | wc -l`
   expect: 0
   stdout: `0`

## Do NOT touch
- `agents/reviewer.md`, `templates/persona-protocol.md`, `adapters/` and `.claude/`: the viewer block itself is byte-fixed and is not edited here.
- `tests/validate.sh`: the test is already registered there (the `packet viewer` section); no section is added.
- `CHANGELOG.md`, `package.json` and `.claude-plugin/plugin.json`: a test-only change takes no version bump and no CHANGELOG entry (dash-scroll-1 and hyg-2 precedent).
- `docs/plans/`: epf-6 owns every plan edit, and `docs/plans/epf-criteria/` is read-only.

## Acceptance criteria
1. run: `bash docs/plans/epf-criteria/epf3-ac1.sh`
   exit: 0
   stdout: empty
   mutation: skip edit 5; prints `not OK: O1 `, exit 1.
   proof: replayed by task-master in a scratch worktree of e44e70c: the edits applied by script, then this mutation; the stated exit and stdout were observed.
2. run: `bash docs/plans/epf-criteria/epf3-ac2.sh`
   exit: 0
   stdout: `comment killed by T1b`
   mutation: skip edit 5; the glow-bat mutation is not caught by O1, prints `glow-bat: no FAIL O1`, exit 1.
   proof: replayed by task-master in a scratch worktree of e44e70c: the edits applied by script, then this mutation; the stated exit and stdout were observed.
3. run: `bash docs/plans/epf-criteria/epf3-ac3.sh`
   exit: 0
   stdout: empty
   mutation: commit a change to `tests/validate.sh` under this unit scope; prints `out of scope: tests/validate.sh`, exit 1.
   proof: replayed by task-master in a scratch worktree of e44e70c: the edits applied by script, then this mutation; the stated exit and stdout were observed.
4. run: `bash docs/plans/epf-criteria/vtargeted.sh 'packet viewer'`
   exit: 0
   stdout: empty
   mutation: make the test report `FAIL`; prints `section group failed: packet viewer`, exit 1.
   check: green at e44e70c on purpose; it guards an invariant the edits must keep, so it is not red before the edit.
   proof: replayed by task-master in a scratch worktree of e44e70c: the edits applied by script, then this mutation; the stated exit and stdout were observed.
5. run: `bash docs/plans/epf-criteria/range.sh epf-3 trailer`
   exit: 0
   stdout: `1`
   mutation: amend the commit without its trailer; prints `0`.
   proof: replayed by task-master in a scratch worktree of e44e70c: the edits applied by script, then this mutation; the stated exit and stdout were observed.
6. run: `bash docs/plans/epf-criteria/range.sh epf-3 tail tests/packet-view-script.test.sh`
   exit: 1
   stdout: `0`
   mutation: add a later commit touching `tests/packet-view-script.test.sh` with a subject outside this unit scope; prints `1`, exit 0.
   proof: replayed by task-master in a scratch worktree of e44e70c: the edits applied by script, then this mutation; the stated exit and stdout were observed.
7. run: `git status --porcelain --untracked-files=no | wc -l`
   exit: 0
   stdout: `0`
   mutation: leave one tracked file modified; prints `1`.
   check: green at e44e70c on purpose; it guards an invariant the edits must keep, so it is not red before the edit.
   proof: replayed by task-master in a scratch worktree of e44e70c: the edits applied by script, then this mutation; the stated exit and stdout were observed.

## Pre-resolved context
tdd: yes tests/packet-view-script.test.sh
blast-radius: tests/validate.sh:629 (the only caller; the test is hermetic and reads the six viewer copies without editing them)
commit-message: test(epf-3): view.sh golden copy, stderr check and fallback order
trailer: -m "Co-Authored-By: Claude Sonnet 5.5 <noreply@anthropic.com>" is the last line of the commit message.
order: epf-3 shares no file with epf-1, epf-2, epf-4 or epf-5; the T1b heredoc is the 15 viewer lines between the fences of the "Canonical packet viewer block" in docs/plans/2026-10-12-escalation-packet-aesthetics.md, copied byte for byte.
merge-gate: G is optional for this unit (a test-only change in a file already registered); the orchestrator runs the packet viewer section group only, which criterion 4 already does.
tree: commit your own agent-memory notes in their own commit first; every command and criterion here assumes `git status --porcelain` is empty at the start.
diagnosis: none
review-packet:
~~~
unit: epf-3 (plan docs/plans/2026-10-13-escalation-packet-followups.md)
changed files: <FILL: changed files>
commit: <FILL: commit SHA>
criterion 1: <FILL: exit and stdout>
criterion 2: <FILL: exit and stdout>
criterion 3: <FILL: exit and stdout>
criterion 4: <FILL: exit and stdout>
criterion 5: <FILL: exit and stdout>
criterion 6: <FILL: exit and stdout>
criterion 7: <FILL: exit and stdout>
~~~

## Escalation
If any instruction cannot be followed exactly as written, STOP and report a spec gap; do not improvise.
``````

### Unit: epf-4

- Suggested model: `sonnet` (the spec suggests no cheaper than sonnet; dash-ux-1 (read 2026-10-13) names `bin/microworld-dashboard/markdown-lite.js`, the file this unit edits.)
- Depends on / blocked by: none
- Spec step: Step 4; closes S3 (the dashboard `markdown-lite.js` renders no tables, so the CHANGES `| Where | What to check |` table shows as raw pipes; implementing it makes the follow-up issue unnecessary).
- Constraints carried from the spec: dash-ux-1 (escape-first XSS, sentinel splitting): cells go through `renderInline` only, the `escapeHtml(` count stays 5, tags carry no attributes. dash-ux-2/-4, dash-scroll-1, dash-rail-collapse-1: vacuous criteria; these fail against the old renderer.
- Reviewer tier: decided at dispatch time by the orchestrator running `hooks/scripts/reviewer-tier.sh` over the unit's actual diff.

``````
Unit: epf-4

## Objective
The dashboard renderer `markdown-lite.js` renders GFM pipe tables as `<table>` with `<thead>` and `<tbody>`, so the `| Where | What to check |` table in a CHANGES pane no longer shows as raw pipe text. A card or fold line never becomes a table. Cells are escaped only through `renderInline`, and the table XSS contexts are tested.

## Retrieval
Plan-file contract: read `docs/plans/2026-10-13-escalation-packet-followups.md`, section `### Unit: epf-4` (dispatch contracts); no tracker issue exists. Run each criterion from the repository root.

## Affected files
- `bin/microworld-dashboard/markdown-lite.js` (anchor: line matching `function renderMarkdown(input) {`)
- `bin/microworld-dashboard/index.html` (anchor: line matching `.doc-pane { border: 1px solid var(--gvx-bg-soft)`)
- `tests/microworld/dashboard-markdown-lite.test.js` (anchor: line matching `|blockquote)>`)

## Ordered edits
1. file: `bin/microworld-dashboard/markdown-lite.js` (table helpers; no new escape site)
   anchor: line matching `function renderMarkdown(input) {`
   indent: 0
   before: `function renderMarkdown(input) {`
   after:
```
// Tables. Cells are never escaped here: every cell goes through renderInline,
// the one escape site on the inline path, and the emitted tags carry no attributes.
function mdSplitRow(row) {
  let s = row.trim();
  if (s.startsWith('|')) s = s.slice(1);
  if (s.endsWith('|') && !s.endsWith('\\|')) s = s.slice(0, -1);
  const cells = [];
  let cur = '';
  for (let k = 0; k < s.length; k++) {
    if (s[k] === '\\' && s[k + 1] === '|') { cur += '|'; k++; }
    else if (s[k] === '|') { cells.push(cur.trim()); cur = ''; }
    else cur += s[k];
  }
  cells.push(cur.trim());
  return cells;
}

function mdIsDelimiterRow(row, width) {
  if (!row.includes('|')) return false;
  const cells = mdSplitRow(row);
  return cells.length === width && cells.every((c) => /^:?-+:?$/.test(c));
}

function renderMarkdown(input) {
```
2. file: `bin/microworld-dashboard/markdown-lite.js` (the table branch, after the list branches and before the paragraph branch)
   anchor: line matching `// Paragraph (non-empty line that's not special)`
   indent: 0
   before: `// Paragraph (non-empty line that's not special)`
   after:
```
// Table: a header row, then a delimiter row with the same cell count.
    if (trimmed.includes('|') && i + 1 < lines.length) {
      const head = mdSplitRow(trimmed);
      if (mdIsDelimiterRow(lines[i + 1], head.length)) {
        i += 2;
        let rows = '';
        while (i < lines.length && lines[i].trim() !== '' && lines[i].includes('|')) {
          const cells = mdSplitRow(lines[i]);
          let tr = '';
          for (let c = 0; c < head.length; c++) tr += '<td>' + renderInline(cells[c] || '') + '</td>';
          rows += '<tr>' + tr + '</tr>';
          i++;
        }
        html += '<table><thead><tr>' + head.map((c) => '<th>' + renderInline(c) + '</th>').join('') + '</tr></thead>' +
          (rows ? '<tbody>' + rows + '</tbody>' : '') + '</table>';
        continue;
      }
    }

    // Paragraph (non-empty line that's not special)
```
3. file: `bin/microworld-dashboard/index.html` (table CSS, theme tokens only)
   anchor: line matching `.doc-pane { border: 1px solid var(--gvx-bg-soft)`
   insert-after: `    .doc-pane table { border-collapse: collapse; margin: var(--space-2) 0; }`
4. file: `bin/microworld-dashboard/index.html`
   anchor: line matching `.doc-pane table { border-collapse: collapse;`
   insert-after: `    .doc-pane th, .doc-pane td { border: 1px solid var(--gvx-bg-soft); padding: var(--space-1) var(--space-2); text-align: left; vertical-align: top; }`
5. file: `tests/microworld/dashboard-markdown-lite.test.js` (ALLOWED_TAG gains the table tags)
   anchor: line matching `|blockquote)>`
   before: `|blockquote)>`
   after: `|blockquote|table|thead|tbody|tr|th|td)>`
6. file: `tests/microworld/dashboard-markdown-lite.test.js` (two table XSS contexts)
   anchor: line matching `{ name: 'ol item', wrap: (s) => '1. ' + s }`
   indent: 0
   before:
```
  { name: 'ol item', wrap: (s) => '1. ' + s }
];
```
   after:
```
  { name: 'ol item', wrap: (s) => '1. ' + s },
  { name: 'table header cell', wrap: (s) => '| ' + s + ' |\n|---|' },
  { name: 'table body cell', wrap: (s) => '| h |\n|---|\n| ' + s + ' |' }
];
```
7. file: `tests/microworld/dashboard-markdown-lite.test.js` (TB1-TB10)
   anchor: line matching `// Test exit on failures`
   indent: 0
   before: `// Test exit on failures`
   after:
```
// --- Tables (epf-4): exact output, and no card line ever becomes a table ---
const T_AB = '<table><thead><tr><th>a</th><th>b</th></tr></thead><tbody><tr><td>1</td><td>2</td></tr></tbody></table>';
const TABLE_CASES = [
  ['TB1 basic', '| Where | What to check |\n|---|---|\n| `a.js:1` | the guard |',
    '<table><thead><tr><th>Where</th><th>What to check</th></tr></thead><tbody><tr><td><code>a.js:1</code></td><td>the guard</td></tr></tbody></table>'],
  ['TB2 aligned', '| a | b |\n| :--- | ---: |\n| 1 | 2 |', T_AB],
  ['TB3 no outer pipes', 'a | b\n--- | ---\n1 | 2', T_AB],
  ['TB4 no delimiter', '| a | b |\n| 1 | 2 |', '<p>| a | b |</p><p>| 1 | 2 |</p>'],
  ['TB5 card', 'why: x\ncriteria checked: AC1 ; exceptions: none | none\nexamples: 3 | examples: none - x\n---\ncommit: abc',
    '<p>why: x</p><p>criteria checked: AC1 ; exceptions: none | none</p><p>examples: 3 | examples: none - x</p><hr /><p>commit: abc</p>'],
  ['TB6 width mismatch', '| a | b |\n|---|---|---|', '<p>| a | b |</p><p>|---|---|---|</p>'],
  ['TB7 ragged rows', '| a | b |\n|---|---|\n| 1 |\n| 1 | 2 | 3 |',
    '<table><thead><tr><th>a</th><th>b</th></tr></thead><tbody><tr><td>1</td><td></td></tr><tr><td>1</td><td>2</td></tr></tbody></table>'],
  ['TB8 escaped pipe', '| h |\n|---|\n| x \\| y |',
    '<table><thead><tr><th>h</th></tr></thead><tbody><tr><td>x | y</td></tr></tbody></table>'],
  ['TB9 ends at blank line', '| a | b |\n|---|---|\n| 1 | 2 |\n\nafter', T_AB + '<p>after</p>'],
  ['TB10 header only', '| a | b |\n|---|---|', '<table><thead><tr><th>a</th><th>b</th></tr></thead></table>']
];

TABLE_CASES.forEach(([label, input, expected]) => {
  check(label, () => {
    const out = renderMarkdown(input);
    assert(out === expected, `expected ${expected}, got ${out}`);
  });
});

// Test exit on failures
```
8. command: `git add bin/microworld-dashboard/markdown-lite.js bin/microworld-dashboard/index.html tests/microworld/dashboard-markdown-lite.test.js && git commit -m "feat(epf-4): dashboard markdown-lite renders pipe tables" -m "Co-Authored-By: Claude Sonnet 5.5 <noreply@anthropic.com>"`
   expect: 0
9. command: `git status --porcelain --untracked-files=no | wc -l`
   expect: 0
   stdout: `0`

## Do NOT touch
- `bin/microworld-dashboard/server.js` and the other `bin/microworld-dashboard/*.js` files: the renderer is injected verbatim by `server.js`, which needs no change.
- `bin/microworld-dashboard/markdown-lite.js` `escapeHtml(` call sites and `renderInline`: no new escape call, no change to the inline path (dash-ux-1 history: the count of `escapeHtml(` stays 5).
- `tests/validate.sh`: the markdown-lite test is already registered there; no section is added.
- `CHANGELOG.md`, `package.json` and `.claude-plugin/plugin.json`: no stamped path is touched, so no version bump and no CHANGELOG entry (dash-scroll-1 precedent).
- `docs/plans/`: epf-6 owns every plan edit, and `docs/plans/epf-criteria/` is read-only.

## Acceptance criteria
1. run: `bash docs/plans/epf-criteria/epf4-ac1.sh`
   exit: 0
   stdout: empty
   mutation: skip edit 2; the test run fails and the script prints `Test TB1 basic...` and the failing line, exit 1.
   proof: replayed by task-master in a scratch worktree of e44e70c: the edits applied by script, then this mutation; the stated exit and stdout were observed.
2. run: `bash docs/plans/epf-criteria/epf4-ac2.sh`
   exit: 0
   stdout: empty
   mutation: skip edit 2; prints `cells bypass renderInline`, exit 1.
   proof: replayed by task-master in a scratch worktree of e44e70c: the edits applied by script, then this mutation; the stated exit and stdout were observed.
3. run: `bash docs/plans/epf-criteria/epf4-ac3.sh`
   exit: 0
   stdout: `epf-4 mutations killed`
   mutation: skip edit 2; prints `unmutated test fails`, exit 1.
   proof: replayed by task-master in a scratch worktree of e44e70c: the edits applied by script, then this mutation; the stated exit and stdout were observed.
4. run: `bash docs/plans/epf-criteria/epf4-ac4.sh`
   exit: 0
   stdout: empty
   mutation: skip edits 3 and 4; prints `table CSS missing`, exit 1.
   proof: replayed by task-master in a scratch worktree of e44e70c: the edits applied by script, then this mutation; the stated exit and stdout were observed.
5. run: `bash docs/plans/epf-criteria/vtargeted.sh 'microworld dashboard'`
   exit: 0
   stdout: empty
   mutation: make table cells skip `renderInline` (the perl substitution of AC4.3 (b)); prints `section group failed: microworld dashboard`, exit 1.
   check: green at e44e70c on purpose; it guards an invariant the edits must keep, so it is not red before the edit.
   proof: replayed by task-master in a scratch worktree of e44e70c: the edits applied by script, then this mutation; the stated exit and stdout were observed.
6. run: `bash docs/plans/epf-criteria/range.sh epf-4 trailer`
   exit: 0
   stdout: `1`
   mutation: amend the commit without its trailer; prints `0`.
   proof: replayed by task-master in a scratch worktree of e44e70c: the edits applied by script, then this mutation; the stated exit and stdout were observed.
7. run: `bash docs/plans/epf-criteria/range.sh epf-4 tail bin/microworld-dashboard/markdown-lite.js bin/microworld-dashboard/index.html tests/microworld/dashboard-markdown-lite.test.js`
   exit: 1
   stdout: `0`
   mutation: add a later commit touching `bin/microworld-dashboard/markdown-lite.js` with a subject outside this unit scope; prints `1`, exit 0.
   proof: replayed by task-master in a scratch worktree of e44e70c: the edits applied by script, then this mutation; the stated exit and stdout were observed.
8. run: `git status --porcelain --untracked-files=no | wc -l`
   exit: 0
   stdout: `0`
   mutation: leave one tracked file modified; prints `1`.
   check: green at e44e70c on purpose; it guards an invariant the edits must keep, so it is not red before the edit.
   proof: replayed by task-master in a scratch worktree of e44e70c: the edits applied by script, then this mutation; the stated exit and stdout were observed.

## Pre-resolved context
tdd: yes tests/microworld/dashboard-markdown-lite.test.js
blast-radius: bin/microworld-dashboard/server.js:92 bin/microworld-dashboard/index.html:130 tests/microworld/dashboard-client.test.js:243 tests/microworld/dashboard-decisions-client.test.js:114 (grep-derived consumers of the injected renderer)
commit-message: feat(epf-4): dashboard markdown-lite renders pipe tables
trailer: -m "Co-Authored-By: Claude Sonnet 5.5 <noreply@anthropic.com>" is the last line of the commit message.
xss: cells go through `renderInline` only, the count of `escapeHtml(` stays 5, and the emitted tags carry no attributes; the adjacency and cross-product suites also run in the table header and body contexts (edit 6).
tb5: the card case has four paragraph lines and one `<hr />` (the plan text says five; the five input lines are the literal input, so the exact output is pinned).
tb8: the escaped pipe case uses a one-cell header `| h |` so the body row `| x \| y |` is a table row; the expected cell text is `x | y`.
order: epf-4 shares no file with epf-1, epf-2, epf-3 or epf-5. epf-6 runs after this unit.
merge-gate: G is optional for this unit (a self-contained dashboard renderer change); criterion 5 runs every `microworld dashboard` section group.
tree: commit your own agent-memory notes in their own commit first; every command and criterion here assumes `git status --porcelain` is empty at the start.
diagnosis: none
review-packet:
~~~
unit: epf-4 (plan docs/plans/2026-10-13-escalation-packet-followups.md)
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
~~~

## Escalation
If any instruction cannot be followed exactly as written, STOP and report a spec gap; do not improvise.
``````

### Unit: epf-5

- Suggested model: `haiku` (the default tier: the function and the three checks are written out literally.)
- Depends on / blocked by: none
- Spec step: Step 5; closes S8 (`parseProtocolSections` splits on `## ` inside fenced code blocks).
- Constraints carried from the spec: none recorded for these two files; the criteria were replayed in a scratch worktree, including the end-to-end mutation run.
- Reviewer tier: decided at dispatch time by the orchestrator running `hooks/scripts/reviewer-tier.sh` over the unit's actual diff.

``````
Unit: epf-5

## Objective
`parseProtocolSections` in `bin/cli.js` ignores a `## ` line inside a fenced code block (a CommonMark backtick or tilde fence, opener indented up to 3 spaces, closer of the same character and at least as long), is exported, and still joins back to the input byte for byte. Three new checks F1-F3 in `tests/protocol-cross-references.test.js` pin the fixtures, the live-template round trip, and the invariant that neither template has a fenced `## ` line.

## Retrieval
Plan-file contract: read `docs/plans/2026-10-13-escalation-packet-followups.md`, section `### Unit: epf-5` (dispatch contracts); no tracker issue exists. Run each criterion from the repository root.

## Affected files
- `bin/cli.js` (anchor: line matching `function parseProtocolSections(text) {`)
- `tests/protocol-cross-references.test.js` (anchor: line matching `if (failures) {`)

## Ordered edits
1. file: `bin/cli.js` (fence-aware parser)
   anchor: line matching `function parseProtocolSections(text) {`
   indent: 0
   before:
```
// Splits the canonical protocol into its leading header comment (which is NOT
// a section) plus one entry per `## ` heading, in template order. Joining the
// preamble and every section text with '\n' reproduces the file byte-for-byte.
function parseProtocolSections(text) {
  const preamble = [];
  const sections = [];
  for (const line of text.split('\n')) {
    if (line.startsWith('## ')) {
      sections.push({ header: line.slice(3).trim(), lines: [line] });
    } else if (sections.length) {
      sections[sections.length - 1].lines.push(line);
    } else {
      preamble.push(line);
    }
  }
  return { preamble: preamble.join('\n'), sections: sections.map((s) => ({ header: s.header, text: s.lines.join('\n') })) };
}
```
   after:
```
// Splits the canonical protocol into its leading header comment (which is NOT
// a section) plus one entry per `## ` heading, in template order. A `## ` line
// inside a fenced code block (CommonMark backtick or tilde fences) starts no section.
// Joining the preamble and every section text with '\n' reproduces the file
// byte-for-byte.
function parseProtocolSections(text) {
  const preamble = [];
  const sections = [];
  let fence = null; // { ch, len } while inside a fenced code block
  for (const line of text.split('\n')) {
    let isHeader = false;
    if (fence) {
      const close = /^ {0,3}(`{3,}|~{3,})[ \t]*$/.exec(line);
      if (close && close[1][0] === fence.ch && close[1].length >= fence.len) fence = null;
    } else {
      const open = /^ {0,3}(`{3,}|~{3,})/.exec(line);
      if (open) fence = { ch: open[1][0], len: open[1].length };
      else isHeader = line.startsWith('## ');
    }
    if (isHeader) {
      sections.push({ header: line.slice(3).trim(), lines: [line] });
    } else if (sections.length) {
      sections[sections.length - 1].lines.push(line);
    } else {
      preamble.push(line);
    }
  }
  return { preamble: preamble.join('\n'), sections: sections.map((s) => ({ header: s.header, text: s.lines.join('\n') })) };
}
```
2. file: `bin/cli.js` (export it)
   anchor: line matching `  selectProtocolSections,`
   insert-after: `  parseProtocolSections,`
3. file: `tests/protocol-cross-references.test.js` (F1, F2, F3)
   anchor: line matching `if (failures) {`
   indent: 0
   before: `if (failures) {`
   after:
~~~~
// epf-5: a `## ` line inside a fenced code block must not start a section.
check('F1 fenced ## line stays inside its section', () => {
  const cases = [
    ['pre\n## A\n```\n## not a header\n```\n## B\nx', ['A', 'B']],
    ['pre\n## A\n~~~\n## not a header\n~~~\n## B', ['A', 'B']],
    ['pre\n## A\n````\n```\n## still fenced\n````\n## B', ['A', 'B']],
    ['pre\n## A\n  ```sh\n## inside an indented fence\n  ```\n## B', ['A', 'B']],
  ];
  for (const [t, want] of cases) {
    const r = cli.parseProtocolSections(t);
    assert.deepStrictEqual(r.sections.map((s) => s.header), want, `headers for ${JSON.stringify(t)}`);
    assert.strictEqual([r.preamble, ...r.sections.map((s) => s.text)].join('\n'), t, `round-trip for ${JSON.stringify(t)}`);
  }
});

const LIVE_TEMPLATES = ['templates/persona-protocol.md', 'templates/persona-protocol-slim.md'];

check('F2 live templates round-trip byte-for-byte', () => {
  for (const rel of LIVE_TEMPLATES) {
    const text = fs.readFileSync(path.join(REPO_ROOT, rel), 'utf8');
    const r = cli.parseProtocolSections(text);
    assert.strictEqual([r.preamble, ...r.sections.map((s) => s.text)].join('\n'), text, `${rel}: round-trip differs`);
  }
});

check(`F3 no ## line inside a fence in ${LIVE_TEMPLATES.join(' or ')}`, () => {
  for (const rel of LIVE_TEMPLATES) {
    const text = fs.readFileSync(path.join(REPO_ROOT, rel), 'utf8');
    const naive = (text.match(/^## /gm) || []).length;
    assert.strictEqual(cli.parseProtocolSections(text).sections.length, naive, `${rel}: a ## line sits inside a fence`);
  }
});

if (failures) {
~~~~
4. command: `git add bin/cli.js tests/protocol-cross-references.test.js && git commit -m "feat(epf-5): parseProtocolSections ignores ## lines inside fenced code blocks" -m "Co-Authored-By: Claude Sonnet 5.5 <noreply@anthropic.com>"`
   expect: 0
5. command: `git status --porcelain --untracked-files=no | wc -l`
   expect: 0
   stdout: `0`

## Do NOT touch
- `templates/persona-protocol.md` and `templates/persona-protocol-slim.md`: neither has a `## ` line inside a fence, so rendering is unchanged (AC5.3 (c): `node bin/cli.js --update --dry-run` exits 0).
- `tests/adapter-protocol-parity.test.js`, `tests/cli-backfill.test.js` and the protocol-doc-drift test: their naive `## ` splitters stay correct because F3 pins the invariant; do not edit them.
- `tests/validate.sh`: the cross-reference test is already registered there; no section is added.
- `CHANGELOG.md`, `package.json` and `.claude-plugin/plugin.json`: `bin/` is not a stamped path, so no version bump and no CHANGELOG entry.
- `docs/plans/`: epf-6 owns every plan edit, and `docs/plans/epf-criteria/` is read-only.

## Acceptance criteria
1. run: `bash docs/plans/epf-criteria/epf5-ac1.sh`
   exit: 0
   stdout: empty
   mutation: skip edit 2; prints `not exported`, exit 1.
   proof: replayed by task-master in a scratch worktree of e44e70c: the edits applied by script, then this mutation; the stated exit and stdout were observed.
2. run: `bash docs/plans/epf-criteria/epf5-ac2.sh`
   exit: 0
   stdout: empty
   mutation: skip edit 3; prints `F1 not OK`, exit 1.
   proof: replayed by task-master in a scratch worktree of e44e70c: the edits applied by script, then this mutation; the stated exit and stdout were observed.
3. run: `bash docs/plans/epf-criteria/epf5-ac3.sh`
   exit: 0
   stdout: `epf-5 mutations killed`
   mutation: skip edit 1; prints `unmutated test fails`, exit 1.
   proof: replayed by task-master in a scratch worktree of e44e70c: the edits applied by script, then this mutation; the stated exit and stdout were observed.
4. run: `bash docs/plans/epf-criteria/epf5-ac4.sh`
   exit: 0
   stdout: empty
   mutation: commit a change to `tests/validate.sh` under this unit scope; prints `out of scope: tests/validate.sh`, exit 1.
   proof: replayed by task-master in a scratch worktree of e44e70c: the edits applied by script, then this mutation; the stated exit and stdout were observed.
5. run: `bash docs/plans/epf-criteria/vtargeted.sh 'protocol cross-references' 'bin/cli.js' 'adapter protocol-port parity' 'protocol doc-drift'`
   exit: 0
   stdout: empty
   mutation: put a `## ` line inside the card fence of the template (the perl substitution of AC5.3 (b)); F3 fails, prints `section group failed: protocol cross-references`, exit 1.
   check: green at e44e70c on purpose; it guards an invariant the edits must keep, so it is not red before the edit.
   proof: replayed by task-master in a scratch worktree of e44e70c: the edits applied by script, then this mutation; the stated exit and stdout were observed.
6. run: `bash docs/plans/epf-criteria/range.sh epf-5 trailer`
   exit: 0
   stdout: `1`
   mutation: amend the commit without its trailer; prints `0`.
   proof: replayed by task-master in a scratch worktree of e44e70c: the edits applied by script, then this mutation; the stated exit and stdout were observed.
7. run: `bash docs/plans/epf-criteria/range.sh epf-5 tail bin/cli.js tests/protocol-cross-references.test.js`
   exit: 1
   stdout: `0`
   mutation: add a later commit touching `bin/cli.js` with a subject outside this unit scope; prints `1`, exit 0.
   proof: replayed by task-master in a scratch worktree of e44e70c: the edits applied by script, then this mutation; the stated exit and stdout were observed.
8. run: `git status --porcelain --untracked-files=no | wc -l`
   exit: 0
   stdout: `0`
   mutation: leave one tracked file modified; prints `1`.
   check: green at e44e70c on purpose; it guards an invariant the edits must keep, so it is not red before the edit.
   proof: replayed by task-master in a scratch worktree of e44e70c: the edits applied by script, then this mutation; the stated exit and stdout were observed.

## Pre-resolved context
tdd: yes tests/protocol-cross-references.test.js
blast-radius: bin/cli.js:736 bin/cli.js:1028 bin/cli.js:1057 (the three callers of parseProtocolSections; each reads the real templates, which have no fenced ## line)
commit-message: feat(epf-5): parseProtocolSections ignores ## lines inside fenced code blocks
trailer: -m "Co-Authored-By: Claude Sonnet 5.5 <noreply@anthropic.com>" is the last line of the commit message.
order: epf-5 shares no file with epf-1 to epf-4 and runs independently; the F3 invariant keeps the naive splitters elsewhere correct.
merge-gate: G is optional for this unit; criterion 5 runs the four affected section groups, and `node bin/cli.js --update --dry-run` exiting 0 is part of criterion 3.
tree: commit your own agent-memory notes in their own commit first; every command and criterion here assumes `git status --porcelain` is empty at the start.
diagnosis: none
review-packet:
~~~
unit: epf-5 (plan docs/plans/2026-10-13-escalation-packet-followups.md)
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
~~~

## Escalation
If any instruction cannot be followed exactly as written, STOP and report a spec gap; do not improvise.
``````

### Unit: epf-6

- Suggested model: `haiku` (the default tier: documentation-only edits whose new text is written out literally.)
- Depends on / blocked by: epf-2, epf-4
- Spec step: Step 6; closes S1, S7 (AC3.2/AC3.3), S9, S10, S11, N1, N5 (seven defective criteria in the epa plan and one stale criterion in the 2026-10-01 plan).
- Constraints carried from the spec: none recorded; plan-only edits.
- Reviewer tier: decided at dispatch time by the orchestrator running `hooks/scripts/reviewer-tier.sh` over the unit's actual diff.

``````
Unit: epf-6

## Objective
The seven defective criteria of `docs/plans/2026-10-12-escalation-packet-aesthetics.md` (AC1.3, AC2.2, AC2.3, AC3.2, AC3.3, AC4.4, AC4.6) and the stale criterion in `docs/plans/2026-10-01-in-session-escalation-decision.md` are corrected in place, each with an `erratum` note; an Errata section lists the seven, and Open Question 1 and R4 are marked resolved by epf-4. Every corrected run line passes and fails under its own mutation.

## Retrieval
Plan-file contract: read `docs/plans/2026-10-13-escalation-packet-followups.md`, section `### Unit: epf-6` (dispatch contracts); no tracker issue exists. Run each criterion from the repository root.

## Affected files
- `docs/plans/2026-10-12-escalation-packet-aesthetics.md` (anchor: line matching `## Open Questions`)
- `docs/plans/2026-10-01-in-session-escalation-decision.md` (anchor: line matching `orchestrator gap in $f`)

## Ordered edits
1. file: `docs/plans/2026-10-12-escalation-packet-aesthetics.md` (AC1.3: corrected run line and erratum)
   anchor: line matching `**AC1.3** (prefix-stripping instruction)`
   indent: 0
   before:
```
- **AC1.3** (prefix-stripping instruction)
  - run: `for f in agents/orchestrator.md .claude/agents/orchestrator.md; do tr -s ' \n' ' ' < $f | grep -qF "without the Read tool's line-number prefixes" || exit 1; done`
```
   after:
```
- **AC1.3** (prefix-stripping instruction)
  - run: `for f in agents/orchestrator.md .claude/agents/orchestrator.md; do [ "$(tr -s ' \n' ' ' < $f | grep -oF "without the Read tool's line-number prefixes" | wc -l)" -eq 2 ] || exit 1; done`
  - erratum (2026-10-13, epf-6): a presence check (`grep -qF`) is vacuous for step 3; the count of the prefix clause must be 2 (steps 2 and 3).
```
2. file: `docs/plans/2026-10-12-escalation-packet-aesthetics.md` (AC2.2: corrected run line and erratum)
   anchor: line matching `**AC2.2** (content rules unchanged`
   indent: 0
   before:
```
- **AC2.2** (content rules unchanged: no load-bearing string lost)
  - run: `B="$F^"; for f in agents/reviewer.md templates/persona-protocol.md adapters/codex/agents-md-fragment.md adapters/cursor/rules/persona-protocol.mdc; do for s in 'Comprehension material only' '## Background' '## What this change is for' '## Walkthrough' '## What to look at first' 'not one subsection per file' 'soft cap 120 lines' '3 to 5' 'consequence' 'never graded by the reviewer' 'examples: none' 'nothing else'; do a=$(git show "$B:$f" | tr -s ' \n' ' ' | grep -oiF -- "$s" | wc -l); b=$(tr -s ' \n' ' ' < "$f" | grep -oiF -- "$s" | wc -l); [ "$b" -ge "$a" ] || { echo "LOST $f :: $s"; exit 1; }; done; done`
```
   after:
```
- **AC2.2** (content rules unchanged: no load-bearing string lost)
  - run: `B="$F^"; for f in agents/reviewer.md templates/persona-protocol.md adapters/codex/agents-md-fragment.md adapters/cursor/rules/persona-protocol.mdc; do for s in 'Comprehension material only' '## Background' '## What this change is for' '## Walkthrough' '## What to look at first' 'not one subsection per file' 'soft cap 120 lines' '3 to 5' 'one-line consequence' 'never graded by the reviewer' 'examples: none' 'nothing else'; do a=$(git show "$B:$f" | tr -s ' \n' ' ' | grep -oiF -- "$s" | wc -l); b=$(tr -s ' \n' ' ' < "$f" | grep -oiF -- "$s" | wc -l); [ "$b" -ge "$a" ] || { echo "LOST $f :: $s"; exit 1; }; done; done`
  - erratum (2026-10-13, epf-6): the monotone count for the bare word `consequence` is weak; `one-line consequence` pins the rule's own phrase.
```
3. file: `docs/plans/2026-10-12-escalation-packet-aesthetics.md` (AC2.3: corrected run line and erratum)
   anchor: line matching `**AC2.3** (contradiction removed)`
   indent: 0
   before:
```
- **AC2.3** (contradiction removed)
  - run: `for f in agents/reviewer.md templates/persona-protocol.md .claude/agents/reviewer.md .claude/persona-protocol.md; do ! tr -s ' \n' ' ' < $f | grep -qF 'no new tool, no rendering'; done && tr -s ' \n' ' ' < agents/reviewer.md | grep -qF 'plain markdown, no HTML'`
```
   after:
```
- **AC2.3** (contradiction removed)
  - run: `for f in agents/reviewer.md templates/persona-protocol.md .claude/agents/reviewer.md .claude/persona-protocol.md; do ! tr -s ' \n' ' ' < $f | grep -qF 'no new tool, no rendering' || exit 1; done && tr -s ' \n' ' ' < agents/reviewer.md | grep -qF 'plain markdown, no HTML'`
  - erratum (2026-10-13, epf-6): the `for` loop's exit status was only the last iteration's, so an early hit passed; each iteration now ends in `|| exit 1`.
```
4. file: `docs/plans/2026-10-12-escalation-packet-aesthetics.md` (AC3.2: corrected run line and erratum)
   anchor: line matching `**AC3.2** (registered in the merge gate)`
   indent: 0
   before:
```
- **AC3.2** (registered in the merge gate)
  - run: `[ "$(grep -c 'tests/packet-view-script.test.sh' tests/validate.sh)" -ge 2 ]`
```
   after:
```
- **AC3.2** (registered in the merge gate)
  - run: `grep -qx 'if bash tests/packet-view-script.test.sh; then' tests/validate.sh`
  - erratum (2026-10-13, epf-6): the count of the filename in `tests/validate.sh` was met by the `echo` lines; the registration is the `if` line.
```
5. file: `docs/plans/2026-10-12-escalation-packet-aesthetics.md` (AC3.3: corrected run line and erratum)
   anchor: line matching `**AC3.3** (ports probed)`
   indent: 0
   before:
```
- **AC3.3** (ports probed)
  - run: `node tests/adapter-protocol-parity.test.js && grep -qF "'view.sh'" tests/adapter-protocol-parity.test.js`
```
   after:
```
- **AC3.3** (ports probed)
  - run: `node tests/adapter-protocol-parity.test.js && grep -F '// epf-2' tests/adapter-protocol-parity.test.js | grep -qF 'and `view.sh` commands'`
  - erratum (2026-10-13, epf-6): the old probe `view.sh` was met by the viewer block's own comments in both ports; the epf-2 probe `run.sh` and `view.sh` commands is prose only.
```
6. file: `docs/plans/2026-10-12-escalation-packet-aesthetics.md` (AC4.4: corrected run line and erratum)
   anchor: line matching `**AC4.4** (approve carries notes`
   indent: 0
   before:
```
- **AC4.4** (approve carries notes under the exact anchor)
  - run: `for f in agents/reviewer.md templates/persona-protocol.md .claude/agents/reviewer.md .claude/persona-protocol.md; do grep -qF 'under the exact `Non-blocking notes:` anchor' $f || { echo $f; exit 1; }; done && grep -qF 'exactly `Non-blocking notes:`' agents/reviewer.md`
```
   after:
```
- **AC4.4** (approve carries notes under the exact anchor)
  - run: `for f in agents/reviewer.md templates/persona-protocol.md .claude/agents/reviewer.md .claude/persona-protocol.md; do grep -qF 'under the exact `Non-blocking notes:` anchor' $f || { echo $f; exit 1; }; done && for f in templates/persona-protocol.md .claude/persona-protocol.md; do [ "$(grep -cF 'under the exact `Non-blocking notes:` anchor' $f)" -ge 2 ] || { echo "prose sentence lost: $f"; exit 1; }; done && grep -qF 'exactly `Non-blocking notes:`' agents/reviewer.md`
  - erratum (2026-10-13, epf-6): the template table row alone satisfied the old loop; the prose sentence must also appear (two occurrences in each template file).
```
7. file: `docs/plans/2026-10-12-escalation-packet-aesthetics.md` (AC4.6: corrected run line and erratum)
   anchor: line matching `**AC4.6** (line 1 and step 6 untouched)`
   indent: 0
   before:
```
- **AC4.6** (line 1 and step 6 untouched)
  - run: `[ "$(git diff -U0 "$F^" "$L" -- agents/reviewer.md templates/persona-protocol.md adapters/ | grep -cE '^[-+].*ESCALATE-TO-HUMAN <task-id> <UTC ISO-8601 timestamp> trigger:')" -eq 0 ] && git show "$F^:agents/orchestrator.md" | awk '/^6\. Make the \*\*prompt-confirmed/,/^7\. /' > "${a:=$(mktemp)}" && awk '/^6\. Make the \*\*prompt-confirmed/,/^7\. /' agents/orchestrator.md > "${b:=$(mktemp)}" && [ -s "$a" ] && cmp -s "$a" "$b"`
```
   after:
```
- **AC4.6** (line 1 and step 6 untouched)
  - run: `a=$(mktemp); b=$(mktemp); [ "$(git diff -U0 "$F^" "$L" -- agents/reviewer.md templates/persona-protocol.md adapters/ | grep -cE '^[-+].*ESCALATE-TO-HUMAN <task-id> <UTC ISO-8601 timestamp> trigger:')" -eq 0 ] && git show "$F^:agents/orchestrator.md" | awk '/^6\. Make the \*\*prompt-confirmed/,/^7\. /' > "$a" && awk '/^6\. Make the \*\*prompt-confirmed/,/^7\. /' agents/orchestrator.md > "$b" && [ -s "$a" ] && cmp -s "$a" "$b"`
  - erratum (2026-10-13, epf-6): the old `${a:=$(mktemp)}` inside a pipeline assigned in a subshell, so `$a` was empty and `cmp` always returned 1; the temp files are created up front.
```
8. file: `docs/plans/2026-10-12-escalation-packet-aesthetics.md` (Errata section before Open Questions)
   anchor: line matching `## Open Questions`
   indent: 0
   before: `## Open Questions`
   after:
```
## Errata (2026-10-13, epf-6)

Seven acceptance criteria above were defective as written. Each now carries the corrected `run:` line and an `erratum` sub-bullet; git keeps the originals.

- AC1.3: a presence check (`grep -qF`) is vacuous for step 3; the count of the prefix clause must be 2 (steps 2 and 3).
- AC2.2: the monotone count for the bare word `consequence` is weak; `one-line consequence` pins the rule's own phrase.
- AC2.3: the `for` loop's exit status was only the last iteration's, so an early hit passed; each iteration now ends in `|| exit 1`.
- AC3.2: the count of the filename in `tests/validate.sh` was met by the `echo` lines; the registration is the `if` line.
- AC3.3: the old probe `view.sh` was met by the viewer block's own comments in both ports; the epf-2 probe `run.sh` and `view.sh` commands is prose only.
- AC4.4: the template table row alone satisfied the old loop; the prose sentence must also appear (two occurrences in each template file).
- AC4.6: the old `${a:=$(mktemp)}` inside a pipeline assigned in a subshell, so `$a` was empty and `cmp` always returned 1; the temp files are created up front.

## Open Questions
```
9. file: `docs/plans/2026-10-12-escalation-packet-aesthetics.md` (Open Question 1 resolved)
   anchor: line matching `from the user-approved design, so it was not chosen. Originates from`
   indent: 0
   before:
```
   from the user-approved design, so it was not chosen. Originates from
   CHK6.
2. **RESOLVED 2026-10-12.** Which of the Fable review's candidate marker
```
   after:
```
   from the user-approved design, so it was not chosen. Originates from
   CHK6. Resolved 2026-10-13 by epf-4 (table support in markdown-lite.js).
2. **RESOLVED 2026-10-12.** Which of the Fable review's candidate marker
```
10. file: `docs/plans/2026-10-12-escalation-packet-aesthetics.md` (R4 resolved)
   anchor: line matching `- **R4 — Dashboard tables render as pipe text.**`
   indent: 0
   before:
```
- **R4 — Dashboard tables render as pipe text.** This is deferred, see Open
  Question 1.
```
   after:
```
- **R4 — Dashboard tables render as pipe text.** This is deferred, see Open
  Question 1. Resolved 2026-10-13 by epf-4 (table support in markdown-lite.js).
```
11. file: `docs/plans/2026-10-01-in-session-escalation-decision.md` (the stale phrase (the orchestrator now says run.sh or view.sh))
   anchor: line matching `grep -q 'Never run `run.sh` yourself' "$f"`
   indent: 0
   before:
```
grep -q 'Never run `run.sh` yourself' "$f"
```
   after:
```
grep -q 'Never run `run.sh`' "$f"
```
12. file: `docs/plans/2026-10-01-in-session-escalation-decision.md` (mark the line as corrected)
   anchor: line matching `orchestrator gap in $f`
   before: `echo "orchestrator gap in $f"; exit 1; }; done`
   after: `echo "orchestrator gap in $f"; exit 1; }; done # erratum 2026-10-13 (epf-6)`
13. command: `git add docs/plans/2026-10-12-escalation-packet-aesthetics.md docs/plans/2026-10-01-in-session-escalation-decision.md && git commit -m "docs(epf-6): correct the defective epa plan criteria and mark OQ1 resolved" -m "Co-Authored-By: Claude Sonnet 5.5 <noreply@anthropic.com>"`
   expect: 0
14. command: `git status --porcelain --untracked-files=no | wc -l`
   expect: 0
   stdout: `0`

## Do NOT touch
- `docs/plans/2026-10-13-escalation-packet-followups.md` and `docs/plans/epf-criteria/`: the spec and its criteria scripts are read-only here.
- `agents/`, `templates/`, `adapters/`, `bin/`, `hooks/` and `tests/`: this unit edits two plan files only, so no version bump and no CHANGELOG entry.
- `CHANGELOG.md`, `package.json` and `.claude-plugin/plugin.json`: no stamped path is touched.
- `.claude/agent-memory/scribe/project_epa2_completion.md`: the scribe closes items 1-14 after this unit passes; it is not part of this unit.

## Acceptance criteria
1. run: `bash docs/plans/epf-criteria/epf6-ac1.sh`
   exit: 0
   stdout: empty
   mutation: skip edit 7; prints `AC4.6 exits non-zero`, exit 1.
   proof: replayed by task-master in a scratch worktree of e44e70c: the edits applied by script, then this mutation; the stated exit and stdout were observed.
2. run: `bash docs/plans/epf-criteria/epf6-ac2.sh`
   exit: 0
   stdout: `AC4.6 killed`
   mutation: skip edit 3; the AC2.3 mutation survives, prints `AC2.3 survived its mutation`, exit 1.
   proof: replayed by task-master in a scratch worktree of e44e70c: the edits applied by script, then this mutation; the stated exit and stdout were observed.
3. run: `bash docs/plans/epf-criteria/epf6-ac3.sh`
   exit: 0
   stdout: empty
   mutation: skip edit 12; prints `no erratum comment`, exit 1.
   proof: replayed by task-master in a scratch worktree of e44e70c: the edits applied by script, then this mutation; the stated exit and stdout were observed.
4. run: `bash docs/plans/epf-criteria/epf6-ac4.sh`
   exit: 0
   stdout: empty
   mutation: skip edit 8; prints `no Errata section`, exit 1.
   proof: replayed by task-master in a scratch worktree of e44e70c: the edits applied by script, then this mutation; the stated exit and stdout were observed.
5. run: `bash docs/plans/epf-criteria/range.sh epf-6 trailer`
   exit: 0
   stdout: `1`
   mutation: amend the commit without its trailer; prints `0`.
   proof: replayed by task-master in a scratch worktree of e44e70c: the edits applied by script, then this mutation; the stated exit and stdout were observed.
6. run: `bash docs/plans/epf-criteria/range.sh epf-6 tail docs/plans/2026-10-12-escalation-packet-aesthetics.md docs/plans/2026-10-01-in-session-escalation-decision.md`
   exit: 1
   stdout: `0`
   mutation: add a later commit touching `docs/plans/2026-10-12-escalation-packet-aesthetics.md` with a subject outside this unit scope; prints `1`, exit 0.
   proof: replayed by task-master in a scratch worktree of e44e70c: the edits applied by script, then this mutation; the stated exit and stdout were observed.
7. run: `git status --porcelain --untracked-files=no | wc -l`
   exit: 0
   stdout: `0`
   mutation: leave one tracked file modified; prints `1`.
   check: green at e44e70c on purpose; it guards an invariant the edits must keep, so it is not red before the edit.
   proof: replayed by task-master in a scratch worktree of e44e70c: the edits applied by script, then this mutation; the stated exit and stdout were observed.

## Pre-resolved context
tdd: no documentation-only edits to two plan files; the corrected criteria are themselves checked by criteria 1 and 2
blast-radius: none
commit-message: docs(epf-6): correct the defective epa plan criteria and mark OQ1 resolved
trailer: -m "Co-Authored-By: Claude Sonnet 5.5 <noreply@anthropic.com>" is the last line of the commit message.
order: dispatch only after epf-2 (its `// epf-2` probe makes the corrected AC3.3 pass) and epf-4 (this unit marks Open Question 1 resolved) have PASS markers and their commits are on the branch.
payloads: the AC blocks in edits 1 to 7 are the header line and the `- run:` line copied from the plan; replace exactly those two lines. The new run lines are written out in full in each edit and must be copied exactly.
merge-gate: G is not needed (plan-only change); criterion 2 re-runs the corrected criteria under their mutations.
tree: commit your own agent-memory notes in their own commit first; every command and criterion here assumes `git status --porcelain` is empty at the start.
diagnosis: none
review-packet:
~~~
unit: epf-6 (plan docs/plans/2026-10-13-escalation-packet-followups.md)
changed files: <FILL: changed files>
commit: <FILL: commit SHA>
criterion 1: <FILL: exit and stdout>
criterion 2: <FILL: exit and stdout>
criterion 3: <FILL: exit and stdout>
criterion 4: <FILL: exit and stdout>
criterion 5: <FILL: exit and stdout>
criterion 6: <FILL: exit and stdout>
criterion 7: <FILL: exit and stdout>
~~~

## Escalation
If any instruction cannot be followed exactly as written, STOP and report a spec gap; do not improvise.
``````
