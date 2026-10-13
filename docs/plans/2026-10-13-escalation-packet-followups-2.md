# Escalation packet follow-ups, round 2 (epfb-1..epfb-5): the epf carry-forward items a-j

Status: FINAL (spec-master, 2026-10-13). **Five dispatchable units**, so this is
the **fast path**: the nine-element dispatch contracts are in the last section
of this file, and `task-master` is not needed.
Baseline: HEAD 9827b96, version 0.31.161.

## Goal

Close the carry-forward list a-j in the "epf closure" section of
`.claude/agent-memory/scribe/project_epa2_completion.md`. Every item is fixed
by a unit, shown already closed, or recorded as a non-goal with a reason (see
the inventory). Goal clauses map to criteria as follows: b → epfb-1 criterion 1;
c → epfb-1 criterion 2; e → epfb-1 criterion 3; d → epfb-2 criteria 1-2;
f → epfb-3 criteria 1-3; g → epfb-4 criteria 1-3; h → epfb-5 criterion 1;
i → the "Contract hygiene" rule below plus every contract's stated stdout;
a and j → no criterion (closed / non-goal).

## Context

### Item inventory (every carry-forward item → its disposition)

| # | Item (scribe note, epf closure) | Disposition |
|---|---|---|
| a | CONTEXT.md escalation card entry lacked the no-fold clause | **Already closed** by the epf scribe pass (9827b96). No unit. |
| b | `templates/persona-protocol.md` ~609 is a ~200-column line | epfb-1. Measured: line 609 is 211 bytes, and line 610 of the same paragraph is 82. Both are re-flowed to 80 or less; mirrors regenerate; version bump and CHANGELOG (P3). |
| c | `agents/reviewer.md:333` "per the bullet after next" points at the wrong bullet | epfb-1. Measured: after next is the `EXAMPLES.md` bullet (:364); the target is "Resolving a standing escalation" (:418). The phrase lives only in `agents/reviewer.md` (and its generated mirror): no port or template carries it, so there is no four-copy hand-sync. |
| d | No validate.sh-run test pins the hyphen-only skip token or the list item after the card | epfb-2: checks EB1 and EB2 in `tests/adapter-protocol-parity.test.js` (run by validate.sh section "adapter protocol-port parity"). |
| e | "Durable escalation packet" in reviewer.md restates the glossary's "Escalation packet" | epfb-1, **decided: leave the persona and template prose unchanged; register the heading as the same term in the glossary entry** (see Clarifications). |
| f | markdown-lite: the table body absorbs following pipe-containing list items, headings and fences; mdSplitRow misparses an escaped backslash before a trailing pipe; no vm-load test of the injected client script | epfb-3. The "briefing and auditor panes now render tables too" sub-note is informational; it needs no action, because the panes call the same `renderMarkdown`, which VM1 exercises. |
| g | parseProtocolSections: an inline code span opens a fence; no unclosed-fence fixture; a trailing `\r` blocks the closer | epfb-4 (check F4) |
| h | `tests/packet-view-script.test.sh:113` O4 `grep -q raw` can match the mktemp suffix | epfb-5. Measured: the same unanchored grep sits at T4 (:83) and T5 (:88), and all three FAIL when `TMPDIR` contains `raw` (reproduced 2026-10-13). All three are fixed. |
| i | Contract wording defects (several-line stdout, `range.sh` prints `1 `, Sonnet trailers on haiku runs) | Not a code fix. The **Contract hygiene** rule below, applied to this plan's contracts. |
| j | One full validate.sh exited 1 under ~5 concurrent runs (not reproduced) | **Non-goal**: a diagnose-only note (see Risks R6). No unit. |

### Contract hygiene (item i), binding on every contract in this plan

1. Each criterion's `stdout:` line is the script's literal output on success,
   byte for byte, including trailing spaces. `range.sh <unit> trailer` prints
   `1 ` (a 1 then one space), so its contracts say that. A script that prints
   several lines on success is listed with every line. None in this plan does.
2. The commit trailer names the model the implementer **actually ran on**
   (`Claude Haiku 5.5`, `Claude Sonnet 5.5` or `Claude Opus 5.5`). Each contract
   writes its suggested tier into the commit command, and says next to the
   command to substitute the real one. `range.sh trailer` checks only the
   trailer's shape, so a wrong name there is a review note, not a criterion
   failure.
3. Every `run:` was executed here: red at 9827b96 (except criteria marked
   `check:`), green in a prototype worktree with all five units committed in
   order, and the mutation scripts killed every stated mutation.

### Prior FAIL history (Implementer-tier ratchet input)

- No `.fail` record exists for any epa-* or epf-* unit (enumerated 2026-10-13).
- In the same files: `packet-brevity-1` FAILed for hand-editing the mirrors, and
  `reviewer-changes-examples-lean-2` FAILed for a missed P3 bump. epfb-1 touches
  that surface, so it is suggested at `sonnet`, following the epf-1/epf-2
  precedent. `dash-ux-1` (escape-first XSS) is why epfb-3 keeps the `escapeHtml(`
  count and the attribute-free tags as criteria.
- The `bin/marker-audit.sh . --notes --surface=<path>` sweep (2026-10-13) returned
  the same population for every surface checked: 24 `NOTE[spec]` and 53
  `untagged` lines. None names an epfb step (the prefix is new). Filtered for
  this plan's topics (markdown, table, fence, parseProtocol, view.sh, raw, skip
  token, Durable, escalation card, epf), one line matches: epa-2's "markdown-lite
  has no table support". epf-4 already closed it. **Disposition:** no note
  changes this plan. The sweep is best-effort, because the records are
  gitignored, per-clone state.

### Measured facts (2026-10-13, HEAD 9827b96)

- `.claude-plugin/plugin.json` and `package.json` are both at 0.31.161, so epfb-1 takes 0.31.162.
- `tests/validate.sh` has 115 sections. No unit adds a section.
- `escapeHtml(` occurs 5 times in `bin/microworld-dashboard/markdown-lite.js`.
- `node bin/cli.js --update --force-render` after the epfb-1 edits changes `.claude/agents/reviewer.md`, `.claude/persona-protocol.md`, the fileHashes config and the version-stamp lines of other mirrors, all inside the epf `MIRROR_RE`.
- `tests/microworld/dashboard-decisions-client.test.js` already vm-loads markdown-lite.js, but only as one input to the decisions client. No test checks that the injected `<script>` body is the source verbatim, or that it defines a working `renderMarkdown` global (VM1 does both).
- `server.js` injects the source with `String.prototype.replace(string, string)`, so a `$&` or `` $` `` in markdown-lite.js would be mangled. VM1 compares the injected body to the source, so it catches that too.
- A Bash command whose text names the fileHashes config file, or a template line that holds the decision path, is refused by `harness-integrity-gate.sh` / `human-decision-gate.sh`. Both refusals happened while this plan was being written. The contracts therefore stage mirrors with `git add -u -- .claude`, and the criteria live in script files.

## Clarifications
1. Functional scope & success criteria: Clear
2. Domain entities / data model: Clear
3. User interaction flow: Clear
4. Non-functional attributes (perf, security, scale): Partial
5. External dependencies & integrations: Clear
6. Edge cases / failure handling: Partial
7. Technical constraints & tradeoffs: Partial
8. Terminology consistency: Partial
9. Completion / acceptance signals: Partial

- 2026-10-13 Non-functional attributes: Q Can the markdown-lite changes reopen the dash-ux-1 XSS class? → A (self-resolved): no. The fix adds no escape site (the `escapeHtml(` count stays 5, epfb-3 criterion 2) and no tag attributes. Cells still go only through `renderInline`, and the existing adjacency and cross-product XSS suites keep running.
- 2026-10-13 Edge cases / failure handling: Q What ends a table body? → A (self-resolved): a blank line, a line with no `|`, or a line that starts another block (a fence opener, an ATX heading, `---`/`***`/`___`, `> `, `- `, `* `, `N. `). This uses the same tests renderMarkdown already applies, in a new `mdStartsBlock`. A pipe-containing paragraph line still continues the body, as in GFM.
- 2026-10-13 Edge cases / failure handling: Q What does `\\` mean in a table row? → A (self-resolved): an escaped backslash. It yields one literal `\` in the cell and does not escape the next `|`. `\|` still yields a literal `|`. The trailing pipe is decided by the scanner (an unescaped `|` as the last character), not by `endsWith('\\|')`. Side effect: a cell holding `C:\\x` shows `C:\x`.
- 2026-10-13 Edge cases / failure handling: Q What is an unclosed fence in parseProtocolSections? → A (self-resolved): CommonMark semantics. The fence runs to the end of the text, so later `## ` lines start no section. F4 pins this. F3 already fails if a live template ever has an unclosed fence, because the fence-aware count would then fall short of the naive count.
- 2026-10-13 Technical constraints & tradeoffs: Q Should items b, c and e be one stamped unit or three? → A (self-resolved): one. Each stamped unit takes a version bump, a CHANGELOG entry and a mirror refresh, and three would serialize on `package.json`, `plugin.json` and `CHANGELOG.md`. d goes to its own unit (epfb-2, test-only, unstamped), so the file sets stay disjoint.
- 2026-10-13 Technical constraints & tradeoffs: Q Where do the item-d tests go? → A (self-resolved): `tests/adapter-protocol-parity.test.js`, which validate.sh already runs. A new test file would add a validate.sh section and change the G range arithmetic.
- 2026-10-13 Terminology consistency: Q Item e: change reviewer.md's "Durable escalation packet" to point at the glossary, or leave it? → A (self-resolved): **leave the prose; fix it in the glossary.** "Durable escalation packet" is also the template's heading (`templates/persona-protocol.md:451`), it is pinned by epf2-ac2 and by the new EB2, and persona prompts do not read CONTEXT.md, so a "see the glossary" pointer would help no agent. Precedent: the epf scribe pass registered "old-format marker" as an alias inside the **fold line** entry. epfb-1 adds one sentence to the **Escalation packet** entry naming the heading as the same term.
- 2026-10-13 Completion / acceptance signals: Q What closes item j? → A (self-resolved): nothing in this plan. It is a non-goal with a diagnose-only note (R6), because it was never reproduced and G passed clean at HEAD.

## Risks / dependencies

- R1: The five units share no file (see the intersection table in the dispatch preamble). epfb-1 is the only stamped unit. The suggested order is epfb-1 to epfb-5, but any order works. EB1/EB2 (epfb-2) read files that epfb-1 edits, and epfb-1's edits keep both properties (verified in the prototype).
- R2: epfb-1 regenerates mirrors with `node bin/cli.js --update --force-render`, never by hand (packet-brevity-1). If epfb-4 lands first, rendering is identical: the fence-aware parser and F3 keep the template split unchanged (`--update --dry-run` rc 0 in the prototype).
- R3: Criteria are scripts in `docs/plans/epfb-criteria/` (committed with this plan, read-only for every unit). They source the existing `docs/plans/epf-criteria/lib.sh` and reuse its generic `p3.sh`, `scope.sh`, `range.sh` and `vtargeted.sh`. Unit commits are found by subject scope `^[a-z]+\(epfb-N\): `.
- R4: `p3.sh` needs an empty `git status --porcelain`. Commit your own agent-memory notes first.
- R5: Do not paste criteria as Bash text. Run `bash docs/plans/epfb-criteria/<script>` (see the gate fact in Measured facts).
- R6 (item j, non-goal, diagnose-only): one run of validate.sh exited 1 under about 5 concurrent runs and was not reproduced, and G passed clean at HEAD. No unit. If it recurs, record which `vsec` range failed and its first `FAIL` line, and whether another validate.sh was running. Suspects to check first: sections that write fixed paths outside `mktemp` (shared across concurrent runs), and section 101's nested run plus the `.claude/reviewed` listing it hashes (another agent's marker write changes the hash). Open a dedicated spec only with a reproduction in hand.

## Constitution check (.claude/constitution.md v1.1.0)
- P1 "Verify, don't assume": satisfied. Every criterion was run red at 9827b96 and green in a prototype worktree with the five units committed in order. The three mutation scripts killed every stated mutation there.
- P2 "Prefer deterministic scripts over LLM re-derivation": satisfied. Mirrors change only through `node bin/cli.js --update --force-render`, and criteria are committed scripts.
- P3 "Version-stamp discipline": satisfied. epfb-1 (template and agents/reviewer.md) bumps both version files and adds a CHANGELOG entry in its one commit, checked by `p3.sh epfb-1` and the version-stamp-check criterion. epfb-2 to epfb-5 touch only `tests/` and `bin/`, which are unstamped.
- P4 "Optional personas degrade gracefully" (SHOULD): satisfied. No persona-presence wording changes.
- P5 "`tests/validate.sh` is the merge gate": satisfied. No section is added. Each unit runs its affected section groups through `vtargeted.sh`, and the orchestrator runs G (the epf procedure, 115 sections) after epfb-1.

## Steps

### Step 1: epfb-1, escalation prose follow-ups (items b, c, e)
**Affected files:** `templates/persona-protocol.md` (the "prompt-confirmed decision write" paragraph, :609-610), `agents/reviewer.md` (:333), `CONTEXT.md` (the **Escalation packet** entry), `CHANGELOG.md`, `package.json`, `.claude-plugin/plugin.json`, plus the generated mirrors.
**Acceptance:** `epfb1-ac1.sh` (the paragraph is ≤80 bytes per line in the template and the mirror; the epf-1 sentence survives); `epfb1-ac2.sh`; `epfb1-ac3.sh`; `p3.sh epfb-1`; version-stamp-check; scope; targeted sections; trailer; tail.

### Step 2: epfb-2, skip-token and card-follow-on tests (item d)
**Affected files:** `tests/adapter-protocol-parity.test.js`.
**Acceptance:** `epfb2-ac1.sh` (EB1 and EB2 OK); `epfb2-ac2.sh` (em-dash mutation → FAIL EB1; column-0 mutation → FAIL EB2); scope; targeted; trailer; tail.

### Step 3: epfb-3, markdown-lite table body, escaped backslash, vm-load test (item f)
**Affected files:** `bin/microworld-dashboard/markdown-lite.js`, `tests/microworld/dashboard-markdown-lite.test.js`.
**Acceptance:** `epfb3-ac1.sh` (TB11-TB17 and VM1 ok); `epfb3-ac2.sh` (escape count 5, no table-tag attributes, ALLOWED_TAG unchanged; `check:`); `epfb3-ac3.sh` (mutations: old renderer, unguarded loop, `</script>` literal); scope; targeted; trailer; tail.

### Step 4: epfb-4, parseProtocolSections fence edge cases (item g)
**Affected files:** `bin/cli.js` (the two fence regexes in `parseProtocolSections`), `tests/protocol-cross-references.test.js`.
**Acceptance:** `epfb4-ac1.sh`; `epfb4-ac2.sh` (F1-F4 OK); `epfb4-ac3.sh` (old opener → FAIL F4; old closer → FAIL F4; dry-run rc 0); scope; targeted; trailer; tail.

### Step 5: epfb-5, anchor the viewer test's raw-text greps (item h)
**Affected files:** `tests/packet-view-script.test.sh` (T4 :83, T5 :88, O4 :113).
**Acceptance:** `epfb5-ac1.sh` (no unanchored `grep -q 'raw'`; the test passes with `TMPDIR` containing `raw` and with the default); scope; targeted; trailer; tail.

## Open Questions

None blocking. Every decision was self-resolved and recorded in Clarifications.
The user may overrule any of them. The one most worth a look is item e's
"leave the prose, add a glossary alias" call.

## Self-check
- CHK1: Does every carry-forward item a-j map to a unit, a verified closure or a stated non-goal? — PASS (inventory: a closed, j non-goal, i rule, b/c/e/d/f/g/h units)
- CHK2: Do the five units have disjoint file sets? — PASS (intersection table; only epfb-1 touches the stamped files and mirrors)
- CHK3: Is item e's decision stated, and does it say which option? — PASS (Clarifications, Terminology: leave the prose, add a glossary alias)
- CHK4: Is each new criterion non-vacuous at HEAD? — PASS (all red at 9827b96 except epfb3-ac2, which is marked `check:`; the mutation scripts exit 3 at HEAD with `no-unit-commit`)
- CHK5: Do the contracts' `stdout:` lines match the scripts' literal output, including `range.sh`'s `1 `? — PASS (item i rule 1; observed in the prototype)
- CHK6: Does every contract tell the implementer to name the model it actually ran on in the trailer? — PASS (rule 2; each commit command carries the substitution note)
- CHK7: Is the CRLF case covered on both the closer and the header? — PASS (F4 case 2: `## A\r` → header `A` through `.trim()`, closer `` ```\r `` closes)
- CHK8: Does the item-h fix cover every site of the same defect, not just O4? — FAIL (missing): the first draft named only O4 — revised in place (T4 and T5 are also fixed, and epfb5-ac1 counts zero unanchored greps)
- CHK9: Was the item-b re-wrap going to leave the paragraph's other over-80 line? — FAIL (missing): line 610 is 82 bytes — revised in place (epfb1-ac1 checks the whole paragraph; lines 609-610 are re-flowed)
- CHK10: Does every contract reach 7/7 under `contract-guard`? — FAIL (ambiguous): the first draft scored 3-5/7 (edit-item shape, review packet, `diagnosis: none`, a pointer-only Do NOT touch bullet) — revised in place (all five now `contract-guard: haiku … score=7/7`)
- CHK11 (replay, packet-brevity-1 [vacuous]): Does epfb1-ac1 fail when only the mirror keeps the long line? — PASS (it loops over the template and `.claude/persona-protocol.md`; `p3.sh` also fails on a stale mirror)
- CHK12 (replay, dash-ux-2 / dash-ux-4 / dash-scroll-1 [vacuous]): Does epfb3-ac1 fail on the old renderer? — PASS (epfb3-ac3 (a), killed in the prototype)
- CHK13 (replay, gh348-4 / gh360 [vacuous] on bin/cli.js): Does epfb4-ac2 fail under each old regex separately? — PASS (epfb4-ac3 (a) and (b))
- CHK14 (replay, gh-303 / gh339 [vacuous] on CONTEXT.md): Is epfb1-ac3 entry-scoped? — PASS (the awk stops at the next column-0 `**term**`)

Glossary drift (prose mode, advisory): lens 1, none. Lens 2: "Durable
escalation packet" is a synonym of **Escalation packet**, resolved by epfb-1's
alias sentence. Lens 3: "skip token" (`examples: none - <reason>`) is used
without its own entry, and is left as a scribe suggestion, not a unit.

## Scribe update hint
After all five units PASS, mark items a-j closed in the "epf closure" section of
`.claude/agent-memory/scribe/project_epa2_completion.md`, naming the closing unit
for each (inventory table). Leave j as an open diagnose-only note (R6). Consider
a **skip token** glossary entry (lens 3 above).

## Dispatch contracts (spec-master, fast path, 2026-10-13)

Five dispatchable units; none held. **Retrieval contract.** No tracker issue
exists for these units (fast path). Fetch a unit's dispatch prompt by reading
`docs/plans/2026-10-13-escalation-packet-followups-2.md` with the Read tool,
finding the `### Unit: epfb-N` heading, and sending the interior of the
six-backtick fenced block that follows it as the dispatch prompt (nested fences
are payloads). Its first line is the literal `Unit: epfb-N`, and
`node bin/contract-guard.js docs/plans/2026-10-13-escalation-packet-followups-2.md --unit=epfb-N`
finds the block. Commit subjects end with the version (epfb-1) or nothing, never
an issue number.

**Intersection table** (shared files exclude the bump files and the generated mirrors):

| unit | files | shared with | depends on |
|---|---|---|---|
| epfb-1 | `templates/persona-protocol.md`, `agents/reviewer.md`, `CONTEXT.md`, `CHANGELOG.md`, `package.json`, `.claude-plugin/plugin.json`, mirrors | none | none |
| epfb-2 | `tests/adapter-protocol-parity.test.js` | none | none |
| epfb-3 | `bin/microworld-dashboard/markdown-lite.js`, `tests/microworld/dashboard-markdown-lite.test.js` | none | none |
| epfb-4 | `bin/cli.js`, `tests/protocol-cross-references.test.js` | none | none |
| epfb-5 | `tests/packet-view-script.test.sh` | none | none |

**Suggested models** (the orchestrator recomputes the Escalation ladder at
dispatch, and a tag can raise the tier, never lower it): epfb-1 `sonnet`
(FAIL history on this surface: packet-brevity-1, lean-2); epfb-2 to epfb-5
`haiku` (every edit is written out literally). All five contracts score 7/7
under `node bin/contract-score.js --rubric=v2`, and `contract-guard` returns
`haiku` for all five (verified 2026-10-13). epfb-1's `sonnet` suggestion rests
on FAIL history alone, so the orchestrator may run it on `haiku` if it judges
that history stale. The reviewer tier is decided at dispatch by
`hooks/scripts/reviewer-tier.sh` over the actual diff.

**G** (the merge gate, from the epf plan, unchanged): the orchestrator runs it
after epfb-1 PASSes. It is optional for the others. Run five separate Bash
calls with `timeout: 600000`: `ls -1 .claude/reviewed | md5sum` on its own; then
`source docs/plans/epf-criteria/lib.sh; export CLAUDE_PROJECT_DIR="$(git rev-parse --show-toplevel)" REVIEWED_DIR_LEAK_GUARD_NESTED=1`
with `vsec 1 60`, then `vsec 61 108`, then `vsec 109 110` and `vsec 111 999`;
finally the md5sum again, which must match the first.

**Verification record:** every `run:` below was executed at 9827b96 (red,
except the `check:` ones) and in a scratch worktree of 9827b96. In the worktree
the criteria were committed, and the five units' edits were applied by script
and committed in order as `docs(epfb-1)`, `test(epfb-2)` … `test(epfb-5)` (green).
The three mutation scripts printed their "mutations killed" line there. The
targeted section groups for all five units ran in 22 s, rc 0.

### Unit: epfb-1

- Suggested model: `sonnet` (stamped unit with mirror refresh; FAIL history on this surface)
- Depends on / blocked by: none
- Spec step: Step 1; closes items b, c, e.

``````
Unit: epfb-1

## Objective
Re-flow the "prompt-confirmed decision write" paragraph in `templates/persona-protocol.md` to 80 bytes or less per line (item b). Make `agents/reviewer.md`'s ESCALATE paragraph name the "Resolving a standing escalation" bullet instead of "the bullet after next" (item c). Add one sentence to the **Escalation packet** glossary entry in `CONTEXT.md` naming the protocol heading **Durable escalation packet** as the same term (item e; the persona and template prose stay unchanged). Regenerate the mirrors, bump the patch version to 0.31.162 and add a CHANGELOG entry, all in one commit.

## Retrieval
Plan-file contract: read `docs/plans/2026-10-13-escalation-packet-followups-2.md`, section `### Unit: epfb-1`; no tracker issue exists. Run each criterion from the repository root.

## Affected files
- `templates/persona-protocol.md` (anchor: line matching `**The prompt-confirmed decision write.**`)
- `agents/reviewer.md` (anchor: line matching `resolves it, per the bullet after next.`)
- `CONTEXT.md` (anchor: line matching `the **packet viewer** (epa-3).`)
- `.claude-plugin/plugin.json`, `package.json` (anchor: line matching `"version": "0.31.161",`)
- `CHANGELOG.md` (anchor: line matching `## [Unreleased]`)
- generated by edit 7 only: the `.claude/` mirrors (`.claude/agents/*.md`, `.claude/persona-protocol.md`, `.claude/persona-protocol-slim.md`, `.claude/protocol-digest.md` and the fileHashes config)

## Ordered edits
1. file: `templates/persona-protocol.md` (re-flow two lines into four; the lines after them are unchanged)
   anchor: line matching `**The prompt-confirmed decision write.**`
   indent: 0
   before:
```
**The prompt-confirmed decision write.** The orchestrator prints marker lines 1 through the `---` fold line verbatim in chat (the whole marker when it has no fold line), reproduces `CHANGES.md` and `EXAMPLES.md`
verbatim as its own message text, outside any code fence, so they render, and asks
```
   after:
```
**The prompt-confirmed decision write.** The orchestrator prints marker lines
1 through the `---` fold line verbatim in chat (the whole marker when it has
no fold line), reproduces `CHANGES.md` and `EXAMPLES.md` verbatim as its own
message text, outside any code fence, so they render, and asks
```
2. file: `agents/reviewer.md` (the ESCALATE-TO-HUMAN paragraph's pointer)
   anchor: line matching `resolves it, per the bullet after next.`
   indent: 2
   before:
```
  re-dispatch naming the unit resolves it, per the bullet after next.
```
   after:
```
  re-dispatch naming the unit resolves it, per the "Resolving a standing
  escalation" bullet below.
```
3. file: `CONTEXT.md` (the **Escalation packet** entry)
   anchor: line matching `the **packet viewer** (epa-3).`
   indent: 2
   before:
```
  `view.sh`, the **packet viewer** (epa-3).
```
   after:
```
  `view.sh`, the **packet viewer** (epa-3). The protocol's own heading for
  it, **Durable escalation packet** (`agents/reviewer.md` and the template),
  names this same term, not a second concept.
```
4. file: `.claude-plugin/plugin.json` (version 0.31.162)
   anchor: line matching `"version": "0.31.161",`
   before: `"version": "0.31.161",`
   after: `"version": "0.31.162",`
5. file: `package.json` (version 0.31.162)
   anchor: line matching `"version": "0.31.161",`
   before: `"version": "0.31.161",`
   after: `"version": "0.31.162",`
6. file: `CHANGELOG.md`
   anchor: line matching `## [Unreleased]`
   indent: 0
   insert-after:
```

**Escalation prose follow-ups (epfb-1, 0.31.162).** `templates/persona-protocol.md`: the prompt-confirmed decision write paragraph is re-flowed to 80 columns (its first line was 211). `agents/reviewer.md`: the ESCALATE-TO-HUMAN paragraph names the "Resolving a standing escalation" bullet instead of "the bullet after next". `CONTEXT.md`: the **Escalation packet** entry names the protocol heading **Durable escalation packet** as the same term. Mirrors refreshed by `node bin/cli.js --update --force-render`.
```
7. command: `node bin/cli.js --update --force-render`
   expect: 0
8. command: `git add templates/persona-protocol.md agents/reviewer.md CONTEXT.md CHANGELOG.md package.json .claude-plugin/plugin.json && git add -u -- .claude && git commit -m "docs(epfb-1): escalation prose follow-ups (0.31.162)" -m "Co-Authored-By: Claude Sonnet 5.5 <noreply@anthropic.com>"` (if you are not running on Sonnet, write the model you actually run on in the trailer: Haiku or Opus)
   expect: 0
9. command: `git status --porcelain --untracked-files=no | wc -l`
   expect: 0
   stdout: `0`

## Do NOT touch
- `adapters/codex/agents-md-fragment.md` and `adapters/cursor/rules/persona-protocol.mdc`: neither carries the item b or item c text; they need no edit.
- `.claude/agents/reviewer.md`, `.claude/persona-protocol.md` and every other `.claude/` mirror: only edit 7 writes them; a hand edit is a P2 violation (packet-brevity-1).
- `templates/persona-protocol.md` outside the two lines of edit 1: its other over-80 lines are out of scope.
- `agents/reviewer.md` headings `- **Durable escalation packet**:` and `- **Resolving a standing escalation ...**`: unchanged (item e is fixed in the glossary, not the persona).
- `tests/`, `bin/` and `docs/plans/`: other units own them, and `docs/plans/epfb-criteria/` is read-only.

## Acceptance criteria
1. run: `bash docs/plans/epfb-criteria/epfb1-ac1.sh`
   exit: 0
   stdout: empty
   mutation: skip edit 1; prints `2 over-80 lines: templates/persona-protocol.md`, exit 1.
2. run: `bash docs/plans/epfb-criteria/epfb1-ac2.sh`
   exit: 0
   stdout: empty
   mutation: skip edit 2; prints `stale pointer: agents/reviewer.md`, exit 1.
3. run: `bash docs/plans/epfb-criteria/epfb1-ac3.sh`
   exit: 0
   stdout: empty
   mutation: skip edit 3; prints `alias sentence missing from the entry`, exit 1.
4. run: `bash docs/plans/epf-criteria/p3.sh epfb-1`
   exit: 0
   stdout: empty
   mutation: skip edit 7 (stale mirror); prints `update --dry-run rc!=0 (stale mirror)`, exit 1.
5. run: `bash -c '. docs/plans/epf-criteria/lib.sh; for c in $(ucommits epfb-1); do bash hooks/scripts/version-stamp-check.sh "$c~1..$c"; done' | grep -c '^version-stamp-check: ok'`
   exit: 0
   stdout: `1`
   mutation: skip edit 4; the check reads only plugin.json, so the line no longer reads ok; prints `0`, exit 1.
6. run: `bash docs/plans/epf-criteria/scope.sh epfb-1 '(templates/persona-protocol\.md|agents/reviewer\.md|CONTEXT\.md|CHANGELOG\.md|package\.json|\.claude-plugin/plugin\.json)' mirrors`
   exit: 0
   stdout: empty
   mutation: also commit a change to `tests/validate.sh`; prints `out of scope: tests/validate.sh`, exit 1.
7. run: `bash docs/plans/epf-criteria/vtargeted.sh 'adapter protocol-port parity' 'protocol cross-references' 'protocol doc-drift' 'packet viewer'`
   exit: 0
   stdout: empty
   check: green at 9827b96 on purpose; it guards invariants the edits must keep.
   mutation: hand-edit `.claude/agents/reviewer.md` only, changing one byte inside the card block; prints `section group failed: adapter protocol-port parity`, exit 1.
8. run: `bash docs/plans/epf-criteria/range.sh epfb-1 trailer`
   exit: 0
   stdout: `1 ` (the digit 1 followed by one space)
   mutation: amend the commit without its trailer; prints `0 `.
9. run: `bash docs/plans/epf-criteria/range.sh epfb-1 tail templates/persona-protocol.md agents/reviewer.md CONTEXT.md`
   exit: 1
   stdout: `0`
   mutation: add a later commit touching `CONTEXT.md` outside this unit's scope; prints `1`, exit 0.

## Pre-resolved context
tdd: no templates/persona-protocol.md (prose and version edits; the criteria scripts are the tests)
blast-radius: tests/adapter-protocol-parity.test.js:286 docs/plans/epf-criteria/epf1-ac3.sh:6 (both read the template paragraph flattened and pass on the re-flow, verified); the reviewer sentence and the glossary entry are read by no test.
commit-message: docs(epfb-1): escalation prose follow-ups (0.31.162)
trailer: the trailer names the model you actually ran on; the contract's Sonnet is the suggested tier, not a requirement.
version: if `.claude-plugin/plugin.json` is no longer at 0.31.161 when you start, STOP and report (another stamped unit landed first).
merge-gate: the orchestrator runs G after PASS.
tree: commit your own agent-memory notes in their own commit first; `p3.sh` requires `git status --porcelain` to be empty.
measured: "after next" from the ESCALATE bullet is the `EXAMPLES.md` bullet; the intended target is the "Resolving a standing escalation" bullet further down.
diagnosis: none
review-packet:
~~~
unit: epfb-1 (plan docs/plans/2026-10-13-escalation-packet-followups-2.md)
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
~~~

## Escalation
If any instruction cannot be followed exactly as written, STOP and report a spec gap; do not improvise.
``````

### Unit: epfb-2

- Suggested model: `haiku`
- Depends on / blocked by: none
- Spec step: Step 2; closes item d.

``````
Unit: epfb-2

## Objective
Add checks EB1 and EB2 to `tests/adapter-protocol-parity.test.js` (run by validate.sh). EB1 pins the ASCII-hyphen skip token `examples: none - <one-line reason>` (no em dash) in all seven prose copies. EB2 pins that the first non-blank line after `<!-- escalated-card:end -->` in `agents/reviewer.md` and its mirror is the `- **Durable escalation packet**: ` list item.

## Retrieval
Plan-file contract: read `docs/plans/2026-10-13-escalation-packet-followups-2.md`, section `### Unit: epfb-2`; no tracker issue exists. Run each criterion from the repository root.

## Affected files
- `tests/adapter-protocol-parity.test.js` (anchor: line matching `if (failures) {`, which occurs once)

## Ordered edits
1. file: `tests/adapter-protocol-parity.test.js` (EB1 and EB2, inserted before the summary block)
   anchor: line matching `if (failures) {`
   indent: 0
   before:
```
if (failures) {
```
   after:
```
// epfb-2: the skip token keeps its ASCII hyphen in every prose copy, and the
// reviewer's escalation card is followed by a list item, never a column-0 paragraph.
check('EB1 skip token is `examples: none - <one-line reason>` with an ASCII hyphen in every prose copy', () => {
  const files = ['agents/reviewer.md', 'templates/persona-protocol.md', '.claude/agents/reviewer.md',
    '.claude/persona-protocol.md', 'CONTEXT.md', 'adapters/codex/agents-md-fragment.md',
    'adapters/cursor/rules/persona-protocol.mdc'];
  for (const rel of files) {
    const t = fs.readFileSync(path.join(REPO_ROOT, rel), 'utf8');
    assert.ok(!t.includes('examples: none \u2014'), `${rel}: em-dash skip token`);
    assert.ok(t.includes('examples: none - <one-line reason>'), `${rel}: no ASCII-hyphen skip token`);
  }
});

check('EB2 the line after the reviewer escalation card is the Durable escalation packet list item', () => {
  for (const rel of ['agents/reviewer.md', '.claude/agents/reviewer.md']) {
    const lines = fs.readFileSync(path.join(REPO_ROOT, rel), 'utf8').split('\n');
    const end = lines.indexOf('<!-- escalated-card:end -->');
    assert.ok(end >= 0, `${rel}: no escalated-card:end line`);
    const next = lines.slice(end + 1).find((l) => l.trim() !== '');
    assert.ok(next !== undefined && next.startsWith('- **Durable escalation packet**: '),
      `${rel}: line after the card is not the list item: ${next}`);
  }
});

if (failures) {
```
2. command: `git add tests/adapter-protocol-parity.test.js && git commit -m "test(epfb-2): pin the ASCII skip token and the list item after the card" -m "Co-Authored-By: Claude Haiku 5.5 <noreply@anthropic.com>"` (if you are not running on Haiku, write the model you actually run on in the trailer)
   expect: 0
3. command: `git status --porcelain --untracked-files=no | wc -l`
   expect: 0
   stdout: `0`

## Do NOT touch
- `agents/reviewer.md`, `templates/persona-protocol.md`, `CONTEXT.md` and the two ports: the tests pin their current text; epfb-1 owns the prose edits.
- `tests/validate.sh`: the parity test is already registered; no section is added.
- `CHANGELOG.md`, `package.json` and `.claude-plugin/plugin.json`: `tests/` is unstamped.
- `docs/plans/epfb-criteria/`: read-only.

## Acceptance criteria
1. run: `bash docs/plans/epfb-criteria/epfb2-ac1.sh`
   exit: 0
   stdout: empty
   mutation: skip edit 1; prints `EB1 not OK`, exit 1.
2. run: `bash docs/plans/epfb-criteria/epfb2-ac2.sh`
   exit: 0
   stdout: `epfb-2 mutations killed`
   mutation: delete the EB1 block; the em-dash mutation still fails the card-identity check but no `FAIL EB1` line appears, so it prints `(a) no FAIL EB1`, exit 1.
3. run: `bash docs/plans/epf-criteria/scope.sh epfb-2 'tests/adapter-protocol-parity\.test\.js'`
   exit: 0
   stdout: empty
   mutation: also commit `CONTEXT.md`; prints `out of scope: CONTEXT.md`, exit 1.
4. run: `bash docs/plans/epf-criteria/vtargeted.sh 'adapter protocol-port parity'`
   exit: 0
   stdout: empty
   mutation: change `none - <one-line reason>` to an em dash in `agents/reviewer.md`; prints `section group failed: adapter protocol-port parity`, exit 1.
5. run: `bash docs/plans/epf-criteria/range.sh epfb-2 trailer`
   exit: 0
   stdout: `1 ` (the digit 1 followed by one space)
   mutation: amend without the trailer; prints `0 `.
6. run: `bash docs/plans/epf-criteria/range.sh epfb-2 tail tests/adapter-protocol-parity.test.js`
   exit: 1
   stdout: `0`
   mutation: a later out-of-scope commit on the file; prints `1`, exit 0.

## Pre-resolved context
tdd: yes tests/adapter-protocol-parity.test.js (EB1 and EB2 pass on arrival: they pin invariants epf-2 established, and criterion 2 proves they are not vacuous)
blast-radius: tests/adapter-protocol-parity.test.js:30 (the `check` helper; `assert`, `fs`, `path` and `REPO_ROOT` are already defined at the top of the file); test-only.
commit-message: test(epfb-2): pin the ASCII skip token and the list item after the card
trailer: the trailer names the model you actually ran on.
tree: start from an empty `git status --porcelain`.
diagnosis: none
review-packet:
~~~
unit: epfb-2 (plan docs/plans/2026-10-13-escalation-packet-followups-2.md)
changed files: <FILL: changed files>
commit: <FILL: commit SHA>
criterion 1: <FILL: exit and stdout>
criterion 2: <FILL: exit and stdout>
criterion 3: <FILL: exit and stdout>
criterion 4: <FILL: exit and stdout>
criterion 5: <FILL: exit and stdout>
criterion 6: <FILL: exit and stdout>
~~~

## Escalation
If any instruction cannot be followed exactly as written, STOP and report a spec gap; do not improvise.
``````

### Unit: epfb-3

- Suggested model: `haiku`
- Depends on / blocked by: none
- Spec step: Step 3; closes item f.

``````
Unit: epfb-3

## Objective
In `bin/microworld-dashboard/markdown-lite.js`, a table body stops at a line that opens another block (fence, ATX heading, rule, blockquote, list item) even if it contains `|`. `mdSplitRow` treats `\\` as an escaped backslash, so `| a \\|` is the one cell `a \` and its trailing pipe closes the row. New tests TB11-TB17, plus a vm-load test VM1 of the injected client script, pin both in `tests/microworld/dashboard-markdown-lite.test.js`. `escapeHtml(` still occurs exactly 5 times, and no tag gains an attribute.

## Retrieval
Plan-file contract: read `docs/plans/2026-10-13-escalation-packet-followups-2.md`, section `### Unit: epfb-3`; no tracker issue exists. Run each criterion from the repository root.

## Affected files
- `bin/microworld-dashboard/markdown-lite.js` (anchors: line matching `function mdSplitRow(row) {`; the table-body `while` line)
- `tests/microworld/dashboard-markdown-lite.test.js` (anchor: line matching `['TB10 header only',`)

## Ordered edits
1. file: `bin/microworld-dashboard/markdown-lite.js` (mdSplitRow rewrite and new mdStartsBlock)
   anchor: line matching `function mdSplitRow(row) {`
   indent: 0
   before:
~~~~
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
~~~~
   after:
~~~~
// A backslash escapes a following `|` or `\\`; an unescaped `|` that ends the
// row closes it and adds no empty cell.
function mdSplitRow(row) {
  let s = row.trim();
  if (s.startsWith('|')) s = s.slice(1);
  const cells = [];
  let cur = '';
  let endedOnPipe = false;
  for (let k = 0; k < s.length; k++) {
    endedOnPipe = false;
    if (s[k] === '\\' && (s[k + 1] === '|' || s[k + 1] === '\\')) { cur += s[k + 1]; k++; }
    else if (s[k] === '|') { cells.push(cur.trim()); cur = ''; endedOnPipe = true; }
    else cur += s[k];
  }
  if (!endedOnPipe) cells.push(cur.trim());
  return cells;
}

// True when a line opens another block (fence, heading, rule, blockquote or
// list item), so a table body stops before it even if it contains a `|`.
function mdStartsBlock(trimmed) {
  return trimmed.startsWith('```') || /^#+\s/.test(trimmed) || trimmed === '---' || trimmed === '***' ||
    trimmed === '___' || trimmed.startsWith('> ') || trimmed.startsWith('- ') || trimmed.startsWith('* ') ||
    /^\d+\.\s/.test(trimmed);
}
~~~~
2. file: `bin/microworld-dashboard/markdown-lite.js` (the table-body loop stops at a block start)
   anchor: line matching `while (i < lines.length && lines[i].trim() !== '' && lines[i].includes('|')) {`
   indent: 8
   before:
~~~~
        while (i < lines.length && lines[i].trim() !== '' && lines[i].includes('|')) {
~~~~
   after:
~~~~
        while (i < lines.length && lines[i].trim() !== '' && lines[i].includes('|') && !mdStartsBlock(lines[i].trim())) {
~~~~
3. file: `tests/microworld/dashboard-markdown-lite.test.js` (TB11-TB17 and VM1)
   anchor: line matching `['TB10 header only',`
   indent: 0
   before:
~~~~
  ['TB10 header only', '| a | b |\n|---|---|', '<table><thead><tr><th>a</th><th>b</th></tr></thead></table>']
];
~~~~
   after:
~~~~
  ['TB10 header only', '| a | b |\n|---|---|', '<table><thead><tr><th>a</th><th>b</th></tr></thead></table>'],
  ['TB11 list item ends the body', '| a | b |\n|---|---|\n| 1 | 2 |\n- item | x', T_AB + '<ul><li>item | x</li></ul>'],
  ['TB12 heading ends the body', '| a | b |\n|---|---|\n| 1 | 2 |\n# h | x', T_AB + '<h1>h | x</h1>'],
  ['TB13 fence ends the body', '| a | b |\n|---|---|\n| 1 | 2 |\n```text | info\nq | r\n```', T_AB + '<pre><code>q | r</code></pre>'],
  ['TB14 blockquote ends the body', '| a | b |\n|---|---|\n| 1 | 2 |\n> q | r', T_AB + '<blockquote><p>q | r</p></blockquote>'],
  ['TB15 ordered item ends the body', '| a | b |\n|---|---|\n| 1 | 2 |\n1. one | two', T_AB + '<ol><li>one | two</li></ol>'],
  ['TB16 escaped backslash before the closing pipe', '| h |\n|---|\n| a \\\\|',
    '<table><thead><tr><th>h</th></tr></thead><tbody><tr><td>a \\</td></tr></tbody></table>'],
  ['TB17 escaped backslash then escaped pipe', '| h |\n|---|\n| x \\\\\\| y |',
    '<table><thead><tr><th>h</th></tr></thead><tbody><tr><td>x \\| y</td></tr></tbody></table>']
];

// epfb-3: the page loads markdown-lite.js as an injected classic <script>, not via require().
check('VM1 injected client script is markdown-lite.js verbatim and defines a working renderMarkdown global', () => {
  const vm = require('vm');
  const fs = require('fs');
  const path = require('path');
  const dir = path.join(__dirname, '../../bin/microworld-dashboard');
  const src = fs.readFileSync(path.join(dir, 'markdown-lite.js'), 'utf8');
  const html = fs.readFileSync(path.join(dir, 'index.html'), 'utf8').replace('/* __MARKDOWN_LITE_SOURCE__ */', src);
  const injected = [...html.matchAll(/<script>([\s\S]*?)<\/script>/g)].map((m) => m[1])
    .find((s) => s.includes('function renderMarkdown('));
  assert(injected === src, 'the injected <script> body is not markdown-lite.js verbatim');
  const sandbox = {};
  vm.createContext(sandbox);
  vm.runInContext(injected, sandbox);
  assert(typeof sandbox.renderMarkdown === 'function', 'renderMarkdown is not a page global');
  const out = sandbox.renderMarkdown(TABLE_CASES[0][1]);
  assert(out === TABLE_CASES[0][2], `vm render of TB1: ${out}`);
});
~~~~
4. command: `git add bin/microworld-dashboard/markdown-lite.js tests/microworld/dashboard-markdown-lite.test.js && git commit -m "fix(epfb-3): markdown-lite table body stops at block starts; escaped backslash in cells" -m "Co-Authored-By: Claude Haiku 5.5 <noreply@anthropic.com>"` (if you are not running on Haiku, write the model you actually run on in the trailer)
   expect: 0
5. command: `git status --porcelain --untracked-files=no | wc -l`
   expect: 0
   stdout: `0`

## Do NOT touch
- `bin/microworld-dashboard/markdown-lite.js` functions `renderInline` and `escapeHtml`: the escape-first model allows exactly one escape site on the inline path (dash-ux-1); add no `escapeHtml(` call anywhere.
- `bin/microworld-dashboard/server.js` and `bin/microworld-dashboard/index.html`: VM1 reads them and needs no change.
- `tests/microworld/dashboard-markdown-lite.test.js` blocks `ALLOWED_TAG`, `CONTEXTS` and the cross-product: they are the XSS invariants; criterion 2 pins `ALLOWED_TAG` byte for byte.
- `tests/validate.sh`, `CHANGELOG.md`, `package.json`, `.claude-plugin/plugin.json`: no section is added, and `bin/` and `tests/` are unstamped.
- `docs/plans/epfb-criteria/`: read-only.

## Acceptance criteria
1. run: `bash docs/plans/epfb-criteria/epfb3-ac1.sh`
   exit: 0
   stdout: empty
   mutation: skip edit 3; prints `TB11 not ok`, exit 1.
2. run: `bash docs/plans/epfb-criteria/epfb3-ac2.sh`
   exit: 0
   stdout: empty
   check: green at 9827b96 on purpose; it guards the XSS invariants the edits must keep.
   mutation: wrap a table cell in `escapeHtml(`; prints `escapeHtml( count 6, want 5`, exit 1.
3. run: `bash docs/plans/epfb-criteria/epfb3-ac3.sh`
   exit: 0
   stdout: `epfb-3 mutations killed`
   mutation: skip edit 2; TB11 fails in the unmutated worktree, so it prints `unmutated test fails`, exit 1.
4. run: `bash docs/plans/epf-criteria/scope.sh epfb-3 '(bin/microworld-dashboard/markdown-lite\.js|tests/microworld/dashboard-markdown-lite\.test\.js)'`
   exit: 0
   stdout: empty
   mutation: also commit `bin/microworld-dashboard/server.js`; prints `out of scope: bin/microworld-dashboard/server.js`, exit 1.
5. run: `bash docs/plans/epf-criteria/vtargeted.sh 'markdown-lite' 'decisions client'`
   exit: 0
   stdout: empty
   mutation: skip edit 2 but keep edit 3; prints `section group failed: markdown-lite`, exit 1.
6. run: `bash docs/plans/epf-criteria/range.sh epfb-3 trailer`
   exit: 0
   stdout: `1 ` (the digit 1 followed by one space)
   mutation: amend without the trailer; prints `0 `.
7. run: `bash docs/plans/epf-criteria/range.sh epfb-3 tail bin/microworld-dashboard/markdown-lite.js tests/microworld/dashboard-markdown-lite.test.js`
   exit: 1
   stdout: `0`
   mutation: a later out-of-scope commit on either file; prints `1`, exit 0.

## Pre-resolved context
tdd: yes tests/microworld/dashboard-markdown-lite.test.js (TB11, TB12, TB13, TB14, TB15, TB16 and TB17 fail before edits 1-2; VM1 passes on arrival and is proven by criterion 3's `</script>` mutation)
blast-radius: bin/microworld-dashboard/server.js:93 (injects the source into the page) tests/microworld/dashboard-decisions-client.test.js:162 (also vm-loads the source; stays green, verified); `renderMarkdown` is the only export, and the briefing, auditor-findings and packet panes call it as a page global.
commit-message: fix(epfb-3): markdown-lite table body stops at block starts; escaped backslash in cells
trailer: the trailer names the model you actually ran on.
tree: start from an empty `git status --porcelain`.
measured: before the fix, `| a \\|` keeps the trailing pipe (`endsWith('\\|')` is true) and renders the cell as `a \|`.
diagnosis: none
review-packet:
~~~
unit: epfb-3 (plan docs/plans/2026-10-13-escalation-packet-followups-2.md)
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

### Unit: epfb-4

- Suggested model: `haiku`
- Depends on / blocked by: none
- Spec step: Step 4; closes item g.

``````
Unit: epfb-4

## Objective
In `parseProtocolSections` (`bin/cli.js`), a run of three or more backticks followed by another backtick on the same line (an inline code span) no longer opens a fence (CommonMark: a backtick fence's info string has no backtick). A closer with a trailing `\r` (CRLF text) now closes its fence. New check F4 in `tests/protocol-cross-references.test.js` pins both, plus an unclosed fence (it runs to the end of the text) and a tilde fence whose info string holds backticks, each with a byte-for-byte round trip.

## Retrieval
Plan-file contract: read `docs/plans/2026-10-13-escalation-packet-followups-2.md`, section `### Unit: epfb-4`; no tracker issue exists. Run each criterion from the repository root.

## Affected files
- `bin/cli.js` (two regex lines inside `function parseProtocolSections(text) {`)
- `tests/protocol-cross-references.test.js` (anchor: line matching `const LIVE_TEMPLATES = [`)

## Ordered edits
1. file: `bin/cli.js` (a closer may end in `\r`)
   anchor: line matching `const close = /^ {0,3}(`
   indent: 6
   before:
~~~~
      const close = /^ {0,3}(`{3,}|~{3,})[ \t]*$/.exec(line);
~~~~
   after:
~~~~
      const close = /^ {0,3}(`{3,}|~{3,})[ \t\r]*$/.exec(line);
~~~~
2. file: `bin/cli.js` (a backtick opener's rest of line holds no backtick)
   anchor: line matching `const open = /^ {0,3}(`
   indent: 6
   before:
~~~~
      const open = /^ {0,3}(`{3,}|~{3,})/.exec(line);
~~~~
   after:
~~~~
      const open = /^ {0,3}(`{3,}(?=[^`]*$)|~{3,})/.exec(line);
~~~~
3. file: `tests/protocol-cross-references.test.js` (F4, inserted before the LIVE_TEMPLATES constant)
   anchor: line matching `const LIVE_TEMPLATES = [`
   indent: 0
   before:
~~~~
const LIVE_TEMPLATES = ['templates/persona-protocol.md', 'templates/persona-protocol-slim.md'];
~~~~
   after:
~~~~
// epfb-4: an inline code span opens no fence, a CRLF closer closes one, and an
// unclosed fence runs to the end of the text (CommonMark).
check('F4 fence edge cases: inline code span, CRLF closer, unclosed fence, tilde info string', () => {
  const cases = [
    ['pre\n## A\n```x``` is inline code\n## B', ['A', 'B']],
    ['pre\r\n## A\r\n```\r\n## not a header\r\n```\r\n## B\r\n', ['A', 'B']],
    ['pre\n## A\n```\n## swallowed\n## also swallowed', ['A']],
    ['pre\n## A\n~~~ `tilde info may hold backticks`\n## not a header\n~~~\n## B', ['A', 'B']],
  ];
  for (const [t, want] of cases) {
    const r = cli.parseProtocolSections(t);
    assert.deepStrictEqual(r.sections.map((s) => s.header), want, `headers for ${JSON.stringify(t)}`);
    assert.strictEqual([r.preamble, ...r.sections.map((s) => s.text)].join('\n'), t, `round-trip for ${JSON.stringify(t)}`);
  }
});

const LIVE_TEMPLATES = ['templates/persona-protocol.md', 'templates/persona-protocol-slim.md'];
~~~~
4. command: `git add bin/cli.js tests/protocol-cross-references.test.js && git commit -m "fix(epfb-4): parseProtocolSections ignores inline code spans and accepts CRLF closers" -m "Co-Authored-By: Claude Haiku 5.5 <noreply@anthropic.com>"` (if you are not running on Haiku, write the model you actually run on in the trailer)
   expect: 0
5. command: `git status --porcelain --untracked-files=no | wc -l`
   expect: 0
   stdout: `0`

## Do NOT touch
- `templates/persona-protocol.md` and `templates/persona-protocol-slim.md`: rendering is unchanged (criterion 3 (c): `node bin/cli.js --update --dry-run` exits 0).
- `bin/cli.js` outside the two regex lines: leave the rest of the parser and its comment unchanged.
- `tests/adapter-protocol-parity.test.js` and `tests/cli-backfill.test.js`: their naive splitters stay correct because F3 pins the invariant.
- `tests/validate.sh`, `CHANGELOG.md`, `package.json`, `.claude-plugin/plugin.json`: no section is added, and `bin/` is unstamped.
- `docs/plans/epfb-criteria/`: read-only.

## Acceptance criteria
1. run: `bash docs/plans/epfb-criteria/epfb4-ac1.sh`
   exit: 0
   stdout: empty
   mutation: skip edit 2; prints ``headers "pre\n## A\n```x``` is inline code\n## B"``, exit 1.
2. run: `bash docs/plans/epfb-criteria/epfb4-ac2.sh`
   exit: 0
   stdout: empty
   mutation: skip edit 3; prints `F4 not OK`, exit 1.
3. run: `bash docs/plans/epfb-criteria/epfb4-ac3.sh`
   exit: 0
   stdout: `epfb-4 mutations killed`
   mutation: skip edit 1; F4 case 2 fails in the unmutated worktree, so it prints `unmutated test fails`, exit 1.
4. run: `bash docs/plans/epf-criteria/scope.sh epfb-4 '(bin/cli\.js|tests/protocol-cross-references\.test\.js)'`
   exit: 0
   stdout: empty
   mutation: also commit `templates/persona-protocol.md`; prints `out of scope: templates/persona-protocol.md`, exit 1.
5. run: `bash docs/plans/epf-criteria/vtargeted.sh 'protocol cross-references' 'bin/cli.js' 'adapter protocol-port parity' 'protocol doc-drift'`
   exit: 0
   stdout: empty
   check: green at 9827b96 on purpose; it guards invariants the edits must keep.
   mutation: put a `## ` line inside the card fence of the template; prints `section group failed: protocol cross-references`, exit 1.
6. run: `bash docs/plans/epf-criteria/range.sh epfb-4 trailer`
   exit: 0
   stdout: `1 ` (the digit 1 followed by one space)
   mutation: amend without the trailer; prints `0 `.
7. run: `bash docs/plans/epf-criteria/range.sh epfb-4 tail bin/cli.js tests/protocol-cross-references.test.js`
   exit: 1
   stdout: `0`
   mutation: a later out-of-scope commit on `bin/cli.js`; prints `1`, exit 0.

## Pre-resolved context
tdd: yes tests/protocol-cross-references.test.js (F4 cases 1 and 2 fail before edits 1-2; cases 3 and 4 pin current behaviour)
blast-radius: bin/cli.js:719 (`parseProtocolSections`; its callers read the live templates, which have no inline-code fence line and no CRLF; `--update --dry-run` exits 0 after the change, verified)
commit-message: fix(epfb-4): parseProtocolSections ignores inline code spans and accepts CRLF closers
trailer: the trailer names the model you actually ran on.
tree: start from an empty `git status --porcelain`.
measured: before the fix, a line starting with a backtick run and holding a closing backtick run opens a fence that never closes, so the next `## ` heading is swallowed; a backtick closer followed by `\r` fails `[ \t]*$`, so a CRLF fence never closes.
diagnosis: none
review-packet:
~~~
unit: epfb-4 (plan docs/plans/2026-10-13-escalation-packet-followups-2.md)
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

### Unit: epfb-5

- Suggested model: `haiku`
- Depends on / blocked by: none
- Spec step: Step 5; closes item h.

``````
Unit: epfb-5

## Objective
In `tests/packet-view-script.test.sh`, the three "no raw text" checks (T4, T5, O4) match only the fixture's raw heading lines (`# changes raw`, `# examples raw`), as whole lines. A `mktemp` path that contains `raw` can no longer fail them, and the test passes when `TMPDIR` contains `raw`.

## Retrieval
Plan-file contract: read `docs/plans/2026-10-13-escalation-packet-followups-2.md`, section `### Unit: epfb-5`; no tracker issue exists. Run each criterion from the repository root.

## Affected files
- `tests/packet-view-script.test.sh` (three lines: T4, T5 and O4)

## Ordered edits
1. file: `tests/packet-view-script.test.sh` (T4)
   anchor: line matching `grep -c '^GLOW:')" = 2 ]`
   indent: 0
   before:
~~~~
[ "$(printf '%s\n' "$out" | grep -c '^GLOW:')" = 2 ] && ! printf '%s' "$out" | grep -q 'raw' && [ "$rc" = 0 ] \
~~~~
   after:
~~~~
[ "$(printf '%s\n' "$out" | grep -c '^GLOW:')" = 2 ] && ! printf '%s\n' "$out" | grep -qxE '# (changes|examples) raw' && [ "$rc" = 0 ] \
~~~~
2. file: `tests/packet-view-script.test.sh` (T5)
   anchor: line matching `grep -c '^BAT:--paging=never -l md ')" = 2 ]`
   indent: 0
   before:
~~~~
[ "$(printf '%s\n' "$out" | grep -c '^BAT:--paging=never -l md ')" = 2 ] && ! printf '%s' "$out" | grep -q 'raw' \
~~~~
   after:
~~~~
[ "$(printf '%s\n' "$out" | grep -c '^BAT:--paging=never -l md ')" = 2 ] && ! printf '%s\n' "$out" | grep -qxE '# (changes|examples) raw' \
~~~~
3. file: `tests/packet-view-script.test.sh` (O4)
   anchor: line matching `[ "$(cnt RICH)" = 2 ]`
   indent: 0
   before:
~~~~
[ "$(cnt RICH)" = 2 ] && ! printf '%s' "$out" | grep -q 'raw' \
~~~~
   after:
~~~~
[ "$(cnt RICH)" = 2 ] && ! printf '%s\n' "$out" | grep -qxE '# (changes|examples) raw' \
~~~~
4. command: `git add tests/packet-view-script.test.sh && git commit -m "test(epfb-5): anchor the viewer test's raw-text checks to whole fixture lines" -m "Co-Authored-By: Claude Haiku 5.5 <noreply@anthropic.com>"` (if you are not running on Haiku, write the model you actually run on in the trailer)
   expect: 0
5. command: `git status --porcelain --untracked-files=no | wc -l`
   expect: 0
   stdout: `0`

## Do NOT touch
- `tests/packet-view-script.test.sh` outside the three lines: the fixture lines (`# changes raw`, `# examples raw`) and the stubs stay as they are.
- `templates/persona-protocol.md`, `agents/reviewer.md` and the other `view.sh` copies: the viewer itself is correct.
- `tests/validate.sh`, `CHANGELOG.md`, `package.json`, `.claude-plugin/plugin.json`: no section, no bump.
- `docs/plans/epfb-criteria/`: read-only.

## Acceptance criteria
1. run: `bash docs/plans/epfb-criteria/epfb5-ac1.sh`
   exit: 0
   stdout: empty
   mutation: skip edits 1-3; prints `3 unanchored raw greps`, exit 1 (skipping only edit 3 prints `1 unanchored raw greps`).
2. run: `bash docs/plans/epf-criteria/scope.sh epfb-5 'tests/packet-view-script\.test\.sh'`
   exit: 0
   stdout: empty
   mutation: also commit `tests/validate.sh`; prints `out of scope: tests/validate.sh`, exit 1.
3. run: `bash docs/plans/epf-criteria/vtargeted.sh 'packet viewer'`
   exit: 0
   stdout: empty
   check: green at 9827b96 on purpose; it guards the rest of the viewer suite.
   mutation: change O4's `[ "$(cnt RICH)" = 2 ]` to `= 3`; prints `section group failed: packet viewer`, exit 1.
4. run: `bash docs/plans/epf-criteria/range.sh epfb-5 trailer`
   exit: 0
   stdout: `1 ` (the digit 1 followed by one space)
   mutation: amend without the trailer; prints `0 `.
5. run: `bash docs/plans/epf-criteria/range.sh epfb-5 tail tests/packet-view-script.test.sh`
   exit: 1
   stdout: `0`
   mutation: a later out-of-scope commit on the file; prints `1`, exit 0.

## Pre-resolved context
tdd: yes tests/packet-view-script.test.sh (reproduced 2026-10-13: with `TMPDIR` set to a directory named `rawtmp`, T4, T5 and O4 FAIL at 9827b96)
blast-radius: tests/packet-view-script.test.sh:69 (the fixture writes `# changes raw` and `# examples raw` as the first lines; the cat fallback prints them, so the anchored pattern still detects a fallthrough to cat); test-only.
commit-message: test(epfb-5): anchor the viewer test's raw-text checks to whole fixture lines
trailer: the trailer names the model you actually ran on.
tree: start from an empty `git status --porcelain`.
measured: the stub renderers echo the packet path, which lies under `mktemp -d`; an unanchored `grep -q 'raw'` matches `raw` anywhere in that path.
diagnosis: none
review-packet:
~~~
unit: epfb-5 (plan docs/plans/2026-10-13-escalation-packet-followups-2.md)
changed files: <FILL: changed files>
commit: <FILL: commit SHA>
criterion 1: <FILL: exit and stdout>
criterion 2: <FILL: exit and stdout>
criterion 3: <FILL: exit and stdout>
criterion 4: <FILL: exit and stdout>
criterion 5: <FILL: exit and stdout>
~~~

## Escalation
If any instruction cannot be followed exactly as written, STOP and report a spec gap; do not improvise.
``````
