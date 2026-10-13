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
