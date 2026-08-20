# Microworld dashboard — usability revision

Status: FINAL (spec-master, 2026-08-18)
Slug: `dashboard-usability-revision`
Published: `[spec]` issue **#406** (`ready-for-agent`) — PRD view only; this
document is the canonical artifact and the units' retrieval target.
Units: 5 (≤5 → fast path; **no `task-master` handoff**, dispatch contracts inline below)

---

## Goal

Close the three usability defects the human operator named against the
microworld dashboard (`bin/microworld-dashboard/`), as sharpened by the
Fable-model usability critique:

1. **Separate review artifacts from plan/spec artifacts in the left rail**,
   each under its own labelled section with type-identifying row prefixes and
   entry counts — replacing the current "Working Bundles" / "Escalation
   Packets" / "Decisions" (four indistinguishable sub-kinds) structure.
2. **Render markdown as markdown** in every pane whose content is a
   *document*, while leaving every pane whose content is *verbatim text*
   (clipboard-destined commands, paste-back blocks, line-numbered source
   excerpts, captured stdout/stderr) byte-for-byte unchanged.
3. **Default the escalation-decision `by` field from `USER_NAME`**, fixing
   both the cold-start blank and the per-view-switch wipe, while keeping the
   value the user actually saw/edited as the one that lands in the DECISION
   file — never a server-side attribution.

Every clause above maps to at least one unit criterion; see the
Goal-clause → criterion map at the end of the Steps section.

---

## Context

### Current state (re-derived against the tree at authoring time, 2026-08-18)

All line numbers below were verified directly, not carried over from the
critique. Four of the critique's incidental claims were **corrected** in the
process — see "Corrections to the critique's premises".

| Fact | Anchor |
|---|---|
| Left rail builder | `bin/microworld-dashboard/index.html:210-276` (`renderLeftRail`) |
| "Working Bundles" header | `index.html:227` |
| "Escalation Packets" header | `index.html:240` |
| "Decisions" umbrella header + 4 row kinds | `index.html:281-309` (`renderDecisionsLeftRail`) |
| Row-kind prefixes today | escalation `Escalation: ` (`:286`), briefing **none** (`:292`), findings `Findings: ` (`:298`), pending-review `Pending review: ` (`:304`), packet bundle **none** (`:245`) |
| Section-header CSS class | `.bundle-section-header` (`index.html:88`), `text-transform: uppercase` (visual only; DOM text is as authored) |
| Auto-select (inverted urgency) | `index.html:1056-1087` — `init()` picks `bundles[0]` whenever `bundles.length > 0`; `autoSelectDecisionView()` runs **only** in the `else` branch |
| Form state | `escalationForm` initialised `by: ''` at `index.html:142`; wiped to `''` again by `resetDecisionForms()` at `index.html:315-318`, called from `selectDecisionView()` (`:324`) and `autoSelectDecisionView()` (`:1086`) |
| `#escalationBy` render + listener | `index.html:616` (renders `value="${escapeHtml(escalationForm.by)}"`), `:647` (`change` listener) |
| Page `escapeHtml` | `index.html:1048-1054` — **DOM-dependent** (`document.createElement('div')`); escapes `& < >` via `textContent`/`innerHTML`, then `"` and `'` by regex |
| Verbatim-source injection pattern | `server.js:81-89`; placeholders `/* __FEEDBACK_BLOCK_SOURCE__ */` (`index.html:116`) and `/* __DECISION_BLOCK_SOURCE__ */` (`index.html:123`) |
| `GET /api/context` | `server.js:125-136`, currently returns `{ sha }` only; 500 when `git rev-parse HEAD` throws |
| Client's only `/api/context` fetch today | `index.html:1282-1283`, **inside `doCopyFeedback`** — lazy, not in `init()` |
| Server-side `by` default | `server.js:285` — `const { taskId, route, escalationTimestamp, by = '', reason = '', quiz } = data;` |
| `GET /api/source` response shape | `source.js:165-172` returns `{ success, lines, startLine, endLine, totalLines }`; `server.js:169` emits the whole object |
| Server-side line cap | `source.js:10` `MAX_LINES = 400`, applied at `:163` |
| Dual-env module precedent | `decision-block.js` — zero `require(`, guarded `module.exports` tail (`:220-222`) |
| Client test harness | `tests/dashboard-decisions-client.test.js:73-134` — extracts the inline module via `/<script type="module">([\s\S]*?)<\/script>/`, `vm.runInContext`s `feedback-block.js` then `decision-block.js` then the module, against a stub DOM; returns `{ leftRailHtml, contentHtml, fetchCalls, contentArea, leftRail, elementsById }` |
| Merge gate | `bash tests/validate.sh`, prints `All checks passed.` at `tests/validate.sh:663`; per-suite lines are `OK   tests/<name>` (three spaces), registration block shape at `:573-635` |

### The six **document panes** (get markdown rendering)

| # | Site | Anchor today |
|---|---|---|
| D1 | Escalation `CHANGES.md` body | `index.html:583` |
| D2 | Escalation `PACKET.md` body | `index.html:589` |
| D3 | Escalation `QUIZ.md` body | `index.html:593` |
| D4 | `QUIZ-ANSWERS.md` lazy reveal | `index.html:695` (`loadQuizAnswerKey`) |
| D5 | Briefing / plan-doc excerpt | `index.html:741` (`loadBriefingExcerpt`) |
| D6 | Milestone findings `finding.body` | `index.html:760` |

### The **verbatim panes** (must NOT change)

| # | Site | Anchor today |
|---|---|---|
| V1 | Composed escalation-decision command | `index.html:620` |
| V2 | Findings paste-back block | `index.html:764` |
| V3 | Pending-review **defer** command | `index.html:806` |
| V4 | Pending-review **skip** command | `index.html:812` |
| V5 | Source-code excerpt pane (`loadExcerpt`) | `index.html:415`, `:1171-1202` |
| V6 | Notebook stdout/stderr cells | `renderNotebook` / cell render path |

### Corrections to the critique's premises

1. **`/api/source` already returns `totalLines`** (`source.js:171`, passed
   through verbatim by `server.js:169`). A *truthful* truncation marker
   therefore needs **no server change** — the client computes
   `totalLines > endLine`. Do not "fix" the silent cutoff by raising
   `endLine`: `MAX_LINES = 400` is a server-side hard cap, so a larger
   request returns no more lines.
2. **The page's `escapeHtml` is DOM-dependent** (`index.html:1049` calls
   `document.createElement`). `markdown-lite.js` must ship its **own** pure,
   DOM-free escape or it cannot be `require`d by a CommonJS unit test at all.
   The critique's "every text span passes through `escapeHtml()`" is correct
   in intent but not satisfiable by reusing the page function.
3. **The client already fetches `/api/context`**, but lazily inside
   `doCopyFeedback` (`index.html:1282`), not in `init()`. Adding an `init()`
   fetch introduces a new failure surface: `/api/context` 500s when
   `git rev-parse HEAD` throws (non-git project root), which would break
   client init for every user in that state. The `init()` fetch must be
   non-fatal.
4. **`tests/dashboard-decisions-client.test.js` hard-asserts the current
   header strings** — Test (a) at `:160-167` requires `Working Bundles`,
   `Escalation Packets` **and** `Decisions` to be present; Test (b) at `:194`
   requires `Decisions` to be **absent** when empty. The IA change breaks
   these; updating them is in-scope blast radius the critique did not name.

### Prior-defect history (durable, from `.claude/reviewed/`)

This surface has a heavy FAIL record. Three failure modes recur and are
designed against explicitly in the criteria below:

- **gh320 D4 — "tested code is not shipped code."** `feedback-block.js` was
  unit-tested while the shipped client re-implemented the same logic inline,
  making three acceptance criteria vacuous with respect to shipped
  behaviour, and letting the two implementations silently diverge. This is
  the single highest risk in Unit 2; U2-C2 is a direct counter-measure.
- **gh318 defect 1-7 / gh319 D4 — string-grep criteria that structurally
  cannot detect broken JS.** Seven defects survived a green suite because
  the criteria grepped the served HTML. Every rendering criterion here
  asserts *rendered output* through the `vm` harness, never source-text
  presence.
- **380 (2-FAIL cap) — type confusion.** A guard gated on
  `typeof value === 'string'` was bypassed by passing an array. U1 requires
  non-string inputs to `renderMarkdown` to fail closed, tested explicitly.

Also relevant: **379** (a byte-identity test made the merge gate flaky via a
live `new Date()` on both sides — keep new assertions deterministic), and
**gh323** (a docs unit FAILed for a false claim about live re-render that a
single grep would have refuted — Unit 5's criteria are claim-anchored, not
existence-greps).

No `.fail` record exists for any unit in this plan (these are new units);
the records above belong to prior work on the same files and are carried as
risk, not as re-scoping evidence.

---

## Clarifications

1. Functional scope & success criteria: Clear
2. Domain entities / data model: Partial
3. User interaction flow: Partial
4. Non-functional attributes (perf, security, scale): Partial
5. External dependencies & integrations: Clear
6. Edge cases / failure handling: Missing
7. Technical constraints & tradeoffs: Clear
8. Terminology consistency: Partial
9. Completion / acceptance signals: Partial

- 2026-08-18 Domain entities / data model: Q Is the "document pane" vs
  "verbatim pane" split enumerable against the actual tree, or is it a
  design intention with fuzzy edges? → A (self-resolved): enumerable and
  now enumerated exhaustively — six document sites (D1-D6) and six verbatim
  sites (V1-V6), each pinned to a current line anchor in Context. The
  critique named five verbatim sites; `renderPendingReviewView` contributes
  **two** distinct command panes (defer `:806`, skip `:812`), not one.
- 2026-08-18 Domain entities / data model: Q Which escape function does
  `markdown-lite.js` use, given it must be unit-testable under CommonJS? →
  A (self-resolved): its own private, DOM-free escape covering
  `& < > " '`. It must never reference the page's `escapeHtml`
  (`index.html:1048`, DOM-dependent) — doing so would make the module
  un-`require`-able, which is the property U1-C2 pins.
- 2026-08-18 User interaction flow: Q Does the "Microworlds" section header
  carry an entry count, given the critique specified counts only for
  "Review" and "Plans & Specs"? → A (self-resolved): yes — all three
  headers carry a count. An asymmetric two-of-three rule has no user-facing
  justification and would make the header-set assertion (U3-C2) encode an
  arbitrary exception. Deviation from the critique's literal text, taken
  deliberately.
- 2026-08-18 User interaction flow: Q What is the full auto-select priority
  order, given the critique named only "an open escalation should win"? →
  A (self-resolved): minimal change — escalations are promoted above
  working bundles; everything else keeps today's relative order. Resulting
  order: escalations → working bundles → briefings → findings →
  pending review. Only the one inversion the critique named is corrected;
  no other touchpoint is re-ranked.
- 2026-08-18 User interaction flow: Q Do briefing rows and working-bundle
  rows need a type prefix? → A (self-resolved): no. The critique scopes
  "each with a type-identifying prefix" to Review's four kinds, which share
  a section; briefings and working bundles are each alone in their own
  section, so the header already carries the type and a prefix would be
  redundant churn.
- 2026-08-18 Non-functional attributes: Q Is a truthful "truncated at line
  N" marker achievable client-side, or does it need a server change? →
  A (self-resolved): achievable client-side — `/api/source` already returns
  `totalLines` (`source.js:171`), emitted verbatim by `server.js:169`. No
  server change. U2-C5 pins both directions so the marker can never be a
  false claim (the gh323 failure mode).
- 2026-08-18 Non-functional attributes: Q What is the XSS boundary, given
  there is no sanitize step? → A (self-resolved): escape-first is the whole
  mechanism — every text span is escaped **before** the renderer wraps it in
  a fixed, renderer-generated tag set, so raw inline HTML in the markdown
  source can never reach the page as markup. Link `href`s are additionally
  restricted to `http:`/`https:`/relative. U1-C3 tests the boundary and
  U1-C4 mutation-proves the escape call is load-bearing.
- 2026-08-18 Edge cases / failure handling: Q What happens when the new
  `init()` fetch of `/api/context` fails? The critique does not say. →
  A (self-resolved): non-fatal. The fetch is wrapped so a non-OK response or
  a thrown error leaves `defaultBy = ''` and never prevents the rail or
  content area from rendering. Without this, a non-git project root (where
  `/api/context` 500s today) would blank the entire dashboard — a strictly
  worse regression than the blank field being fixed. Pinned by U4-C6.
- 2026-08-18 Edge cases / failure handling: Q What must `renderMarkdown` do
  with a non-string argument (`null`, `undefined`, a number, an array)? The
  critique does not say, and this is the exact class that took unit 380 to
  the 2-FAIL cap. → A (self-resolved): fail closed — return a string, never
  throw, and never emit markup derived from a non-string's coercion.
  `renderMarkdown(['<img src=x onerror=alert(1)>'])` must not produce
  `<img`. Pinned by U1-C3.
- 2026-08-18 Terminology consistency: Q Does the new vocabulary drift from
  `CONTEXT.md`? → A (self-resolved): yes, in three advisory ways, all routed
  to Unit 5 rather than silently absorbed. See the Ubiquitous-language
  section below.
- 2026-08-18 Completion / acceptance signals: Q Are the critique's three
  draft acceptance criteria sufficient as written? → A (self-resolved): no,
  three gaps closed. (i) AC-2 had no single-implementation proof, the exact
  gh320 D4 failure mode — added as U2-C2 (sentinel-stub injection). (ii)
  AC-1's "no header text 'Decisions' anywhere" is over-broad: the strings
  `data-decision-kind`, `data-decision-key`, `decision-item` and
  `decisionCopyBtn` legitimately remain in the rail markup, so the check is
  scoped to extracted `.bundle-section-header` text (U3-C2/C5). (iii) AC-3
  did not pin the per-view-switch wipe, which is half of the operator's
  actual complaint — added as U4-C3.
- 2026-08-18 Completion / acceptance signals: Q How is the literal `&` in
  the header "Plans & Specs" encoded, given a test asserts the exact string?
  → A (self-resolved): written bare (`Plans & Specs`) in the template
  literal, matching how every other header and separator in this file is
  authored (e.g. the raw `·` at `index.html:759`). Pinned explicitly so an
  implementer writing `&amp;` does not silently fail U3-C2.

### Ubiquitous-language check (prose mode, advisory — never blocks)

Glossary read: `/home/sebas/AntiSlop/CONTEXT.md`.

- **Lens 1 (glossary term used with a different meaning).** Anchor: design
  bullet "IA (note 1)", section header `Review`. `CONTEXT.md` uses "review"
  throughout in the *verdict-process* sense (the `reviewer` persona, the
  PASS marker, pending review). The rail section means "artifacts awaiting
  a human's attention", which spans escalations, packet bundles, findings
  and pending-review flags — a broader, different sense. Accepted anyway:
  no shorter label carries the meaning, and Unit 5 records the UI sense
  explicitly so the two do not silently merge.
- **Lens 2 (new synonym for an already-defined term).** Anchor: row prefix
  `Packet: <unit>`. `CONTEXT.md:861` defines **Escalation packet**, and the
  **Bundle source** entry defines `"packet"` as a field value, not as a
  standalone noun. `Packet:` is a new short synonym for the canonical
  **escalation packet**. Accepted as a UI-space abbreviation (the full term
  does not fit a rail row); flagged for Unit 5. Separately: `CONTEXT.md` has
  **no** entry for "briefing" at all, despite `decisions.js`/`index.html`
  using it as the name for `docs/plans/*.md` entries — a pre-existing gap
  the new section header "Plans & Specs" makes more visible.
- **Lens 3 (load-bearing new domain term with no glossary entry).** Three,
  all routed to Unit 5 for `scribe`: **markdown-lite renderer** (the
  vendored dependency-free module), **document pane** vs **verbatim pane**
  (the load-bearing distinction that governs which panes may be
  transformed), and the three-section rail IA itself
  (`Review` / `Plans & Specs` / `Microworlds`).

---

## Risks / dependencies

- **R1 — Tested-but-not-shipped divergence (highest).** Precedent: gh320 D4,
  where `feedback-block.js` was unit-tested while the page re-implemented it
  inline, voiding three criteria. Mitigation: U2-C2 injects a **stub**
  `renderMarkdown` returning a sentinel and asserts the sentinel appears at
  all six document sites — a test that only passes if the page genuinely
  calls the injected global. U2-C3 additionally asserts the served page body
  no longer contains the placeholder comment.
- **R2 — Over-application of markdown to verbatim panes.** Rendering V1-V4
  would corrupt clipboard-destined text that downstream tooling parses
  (`decision-block.js`'s composed DECISION bodies, the pending-review
  `defer:`/`skip:` commands). Mitigation: negative control in the same test
  pass as U2-C2, plus V1-V6 enumerated by anchor above.
- **R3 — String-grep criteria that cannot see broken JS.** Precedent: gh318
  (7 defects through a green suite), gh319 D4 (a whole DOM harness defined
  and never called). Mitigation: every rendering criterion runs the client
  under `vm` and asserts rendered output.
- **R4 — Legacy test assertions block the IA change.** `tests/dashboard-
  decisions-client.test.js:160-167` and `:194` pin the exact headers being
  replaced. Mitigation: named in U3's affected files and ordered edits;
  U3-C9 requires replacement rather than deletion.
- **R5 — Shared test harness contention.** Units 2, 3 and 4 all extend
  `renderClient` in `tests/dashboard-decisions-client.test.js` (U2 adds
  markdown-lite injection + an optional stub; U4 adds `contextData` +
  a failure mode). Dispatch is one unit at a time, so this serialises
  naturally; each unit's dispatch contract names the harness change it owns.
- **R6 — New failure surface from the `init()` context fetch.** See the
  Edge-cases clarification; pinned by U4-C6.
- **R7 — Flaky merge gate.** Precedent: 379, where two live `new Date()`
  evaluations straddling a millisecond made `validate.sh` intermittently
  red. No criterion in this plan compares two independently-derived
  timestamps; fixtures are static.
- **R8 — Sequencing.** U2 depends on U1 (the module must exist). U5 depends
  on U1-U4 having landed (its prose describes their shipped result). U3 and
  U4 are mutually independent and independent of U1/U2.
- **Non-dependency (verified):** no file in this plan has a `bin/cli.js
  --update` script-driven path, and none is version-stamped — see the
  Constitution check.

---

## Constitution check (.claude/constitution.md v1.0.0)

- P1 "Verify, don't assume": satisfied — every current-state claim in
  Context was re-derived against the working tree at authoring time (not
  carried from the critique), and four of the critique's premises were
  corrected as a result. No unit's acceptance criteria rest on an
  existence-grep alone; U1-C4 and U2-C2 are explicit mutation/negative
  controls.
- P2 "Prefer deterministic scripts over LLM re-derivation": satisfied — no
  file touched by this plan has a script-driven path.
  `bin/microworld-dashboard/*`, `tests/*`, and `CONTEXT.md` are outside
  `--update`/`--wire-graph-mcp`/`--wire-arxiv-mcp`/`fileHashes`.
- P3 "Version-stamp discipline": satisfied by non-application — no
  version-stamped file (`agents/*.md`, `templates/`) is touched. Verified
  against convention: the two most recent dashboard-only commits (`417ad35`,
  `0779929`) touched `index.html` alone and bumped no version. U5-C5 pins
  that `plugin.json` and `CHANGELOG.md` stay consistent either way.
- P4 "Optional personas degrade gracefully": not applicable — no shared
  persona prose is touched.
- P5 "`tests/validate.sh` is the merge gate": satisfied — every unit carries
  `bash tests/validate.sh` exits 0 and prints `All checks passed.`, and U1
  additionally registers its new suite inside `validate.sh` following the
  existing block shape at `:573-635`, verified non-vacuous by the presence
  of the `OK   tests/dashboard-markdown-lite.test.js` line in the output.

---

## Steps

### Step 1 — `markdown-lite.js`: the vendored renderer (module only, no wiring)

**Affected files**
- `bin/microworld-dashboard/markdown-lite.js` (new)
- `tests/dashboard-markdown-lite.test.js` (new)
- `tests/validate.sh` (register the new suite)

**Design**
Dual-environment single implementation, same shape as `decision-block.js`:
zero `require(`, zero `document.` access, a guarded
`if (typeof module !== 'undefined' && module.exports) { module.exports = { renderMarkdown }; }`
tail so it is both CommonJS-requirable and injectable verbatim as a page
global.

Escape-first is the entire XSS mechanism. Every text span passes through the
module's own private, DOM-free `escapeHtml` (covering `&`, `<`, `>`, `"`,
`'`) **before** the renderer wraps it in a fixed, renderer-generated tag set.
There is no sanitize pass and none is needed: raw inline HTML in the source
can never reach the page as markup because it is escaped before any tag is
emitted.

Supported constructs (minimum): headings (`#`..`######`), bold, italic,
inline code, fenced code blocks, unordered and ordered lists, blockquotes,
links, horizontal rule, paragraphs.

Links: `href` restricted to `http:`, `https:`, or a relative target. Anything
else (notably `javascript:`) renders as plain text with no anchor emitted at
all. Emitted anchors carry `rel="noopener noreferrer" target="_blank"`.

Non-string input fails closed: returns a string, never throws, and never
emits markup derived from coercing a non-string.

**Acceptance criteria**
- **U1-C1** `node tests/dashboard-markdown-lite.test.js` exits 0.
- **U1-C2** `git grep -n 'require(\|document\.' bin/microworld-dashboard/markdown-lite.js`
  prints no lines and exits 1 (module purity — the property that makes the
  module both requirable and injectable; mirrors the check the 379 review
  ran against `decision-block.js`).
- **U1-C3** The suite contains, and passes, at least these cases:
  - `renderMarkdown('# H')` output contains `<h1>H</h1>`
  - `renderMarkdown('**b**')` contains `<strong>b</strong>`
  - `renderMarkdown('*i*')` contains `<em>i</em>`
  - `` renderMarkdown('`c`') `` contains `<code>c</code>`
  - a fenced block produces `<pre><code>`
  - `renderMarkdown('- a\n- b')` produces exactly one `<ul>` containing two `<li>`
  - `renderMarkdown('> q')` produces `<blockquote>`
  - `renderMarkdown('---')` produces `<hr`
  - `renderMarkdown('plain')` produces `<p>`
  - `renderMarkdown('<img src=x onerror=alert(1)>')` output contains no `<img`
  - `renderMarkdown('[a](javascript:alert(1))')` output contains neither
    `javascript:` nor `href=`
  - `renderMarkdown('[a](https://x.test/p)')` output contains
    `href="https://x.test/p"`, `rel="noopener noreferrer"`, `target="_blank"`
  - `renderMarkdown('[a](./rel/path.md)')` output contains `href="./rel/path.md"`
  - `renderMarkdown('a & b " c \' d <e>')` output contains `&amp;`, `&lt;`,
    `&gt;` and contains no bare `<e>`
  - each of `renderMarkdown(null)`, `renderMarkdown(undefined)`,
    `renderMarkdown(42)`, `renderMarkdown(['<img src=x onerror=alert(1)>'])`
    returns a string, does not throw, and contains no `<img`
- **U1-C4 (mutation proof — the criterion must not be vacuous)** With the
  escape call removed from the module's text-span path,
  `node tests/dashboard-markdown-lite.test.js` exits non-zero. The reviewer
  performs this revert-and-rerun and restores the file afterwards.
- **U1-C5** `bash tests/validate.sh` exits 0, prints `All checks passed.`,
  and its output contains the line `OK   tests/dashboard-markdown-lite.test.js`.

---

### Step 2 — Wire markdown into the six document panes

**Affected files**
- `bin/microworld-dashboard/index.html` (six render sites, one new
  `<script>` placeholder, one new CSS rule)
- `bin/microworld-dashboard/server.js` (one injection line, mirroring `:85-89`)
- `tests/dashboard-decisions-client.test.js` (harness: inject
  `markdown-lite.js`; accept an optional `markdownStub`; new cases)
- `tests/dashboard-client.test.js` (served-page assertion, U2-C3)

**Ordered design**
1. Add `<script>/* __MARKDOWN_LITE_SOURCE__ */</script>` to `index.html`
   alongside the two existing placeholders (`:116`, `:123`), ahead of the
   module script.
2. Add the matching `fs.readFileSync` + `html.replace` pair in `server.js`
   next to `:85-89`.
3. Add the `.doc-pane` CSS rule: proportional font (no
   `font-family: monospace`), `word-break: normal`, **no** `max-height`.
   `.excerpt-pane` (`index.html:81`) and `.excerpt-line` (`:82`) are
   untouched.
4. Switch D1-D6 from `escapeHtml(...)`-as-final-render to
   `renderMarkdown(...)` inside a `.doc-pane` container.
   - D5 (`loadBriefingExcerpt`) and D4 (`loadQuizAnswerKey`) currently map
     each line to its own `.excerpt-line` div. They must instead
     `lines.join('\n')` and render the result as **one** document — a
     per-line render would break every multi-line construct.
   - D5 and D4 additionally emit a truncation marker when
     `data.totalLines > data.endLine`, using the exact text
     `Truncated at line <endLine> of <totalLines>`. When
     `totalLines <= endLine`, no marker is emitted.
5. V1-V6 are not touched.

**Acceptance criteria**
- **U2-C1** `node tests/dashboard-decisions-client.test.js` exits 0.
- **U2-C2 (single-implementation proof — closes the gh320 D4 failure mode)**
  The suite contains a case that runs `renderClient` with a **stub**
  `renderMarkdown = (s) => 'MDSENTINEL:' + String(s)` installed as the
  sandbox global *instead of* the real `markdown-lite.js` source, and in a
  single pass asserts:
  - `MDSENTINEL:` appears in the rendered output of each of D1, D2, D3, D4,
    D5 and D6 (six distinct assertions), **and**
  - `MDSENTINEL:` appears in the rendered output of none of V1, V2, V3, V4.
  A page that re-implemented rendering inline instead of calling the
  injected global fails the first half; a page that over-applied rendering
  fails the second half.
- **U2-C3 (the injection is real, end to end)** In `tests/dashboard-client.test.js`,
  the body of `GET /?t=<token>` contains the literal `function renderMarkdown`
  and does **not** contain `__MARKDOWN_LITE_SOURCE__` (the placeholder was
  consumed). Additionally
  `git grep -c '__MARKDOWN_LITE_SOURCE__' bin/microworld-dashboard/index.html`
  = 1 and `git grep -c 'markdown-lite.js' bin/microworld-dashboard/server.js` = 1.
- **U2-C4 (real renderer, at a real site)** With the real `markdown-lite.js`
  injected (no stub), a fixture whose `finding.body` is `**bold**` renders
  `<strong>bold</strong>` in the D6 pane, while the V2 paste-back pane in the
  same render — which embeds the same `finding.body` via
  `composeDecisionBlock('milestone-findings-response', ...)` — still contains
  the literal `**bold**` and no `<strong>`. One assertion pair, both
  directions, same render.
- **U2-C5 (truncation marker is truthful, both directions)**
  - `/api/source` stub returns `{ lines: [...], startLine: 1, endLine: 400, totalLines: 1200 }`
    → the D5 pane output contains the exact string `Truncated at line 400 of 1200`.
  - stub returns `{ lines: [...], startLine: 1, endLine: 120, totalLines: 120 }`
    → the D5 pane output contains no occurrence of `Truncated at line`.
- **U2-C6 (document, not per-line)** With the real renderer and a stub
  returning `lines: ['- a', '- b']`, the D5 pane output contains exactly one
  `<ul>` and contains no `class="excerpt-line"`.
- **U2-C7 (verbatim panes structurally untouched)** The `.excerpt-pane` CSS
  rule still contains `max-height: 200px` and the `.excerpt-line` rule still
  contains `word-break: break-all`; the new `.doc-pane` rule contains
  `word-break: normal`, contains no `max-height`, and contains no
  `font-family: monospace`.
- **U2-C8** `node tests/dashboard-client.test.js` exits 0;
  `bash tests/validate.sh` exits 0 and prints `All checks passed.`

---

### Step 3 — Left-rail information architecture

**Affected files**
- `bin/microworld-dashboard/index.html` (`renderLeftRail` `:210-276`,
  `renderDecisionsLeftRail` `:281-309`, `init`/`autoSelectDecisionView`
  `:1056-1087`)
- `tests/dashboard-decisions-client.test.js` (replace the legacy header
  assertions at `:160-167` and `:194`; add the new cases)

**Design**
Three top-level sections, in this document order, each rendered only when
non-empty, each header emitted as
`<div class="bundle-section-header">…</div>` and each carrying a count:

| Order | Header text | Contents | Row prefix |
|---|---|---|---|
| 1 | `Review (N)` | escalations, `source: "packet"` bundles, findings, pending review | `Escalation: `, `Packet: `, `Findings: `, `Pending review: ` |
| 2 | `Plans & Specs (N)` | briefings (`docs/plans/*.md`) | none — the header carries the type |
| 3 | `Microworlds (N)` | `source: "working"` bundles | none — the header carries the type |

`N` is that section's exact entry count. `Plans & Specs` is written with a
bare `&` in the template literal. The word "Decisions" disappears from all
rendered header text; the `data-decision-kind` / `data-decision-key`
attributes, the `decision-item` class and the `decisionCopyBtn` id all
remain (they are wiring, not user-facing labels).

Auto-select: `init()` selects an open escalation ahead of a working bundle.
Full priority order — escalations → working bundles → briefings → findings →
pending review. No other touchpoint is re-ranked.

**Acceptance criteria** (all rendering assertions via the `vm` harness)
- **U3-C1** `node tests/dashboard-decisions-client.test.js` exits 0.
- **U3-C2 (header set, exact and ordered)** With a fixture of 1 escalation,
  1 packet bundle, 1 findings, 1 pending-review, 1 briefing and 1 working
  bundle, extracting every match of
  `/<div class="bundle-section-header">([^<]*)<\/div>/g` from `leftRailHtml`
  in document order yields exactly
  `['Review (4)', 'Plans & Specs (1)', 'Microworlds (1)']`
  (deep-equal on the array — this single assertion covers presence,
  ordering, counts and the absence of any extra header).
- **U3-C3 (row containment by offset)** In that same `leftRailHtml`: the
  offsets of the escalation, packet-bundle, findings and pending-review rows
  all fall between the offset of the `Review (4)` header and that of the
  `Plans & Specs (1)` header; the briefing row's offset falls between
  `Plans & Specs (1)` and `Microworlds (1)`; the working-bundle row's offset
  falls after `Microworlds (1)`.
- **U3-C4 (type prefixes)** In that same render, the escalation row's title
  text begins `Escalation: `, the packet-bundle row's begins `Packet: `, the
  findings row's begins `Findings: `, the pending-review row's begins
  `Pending review: `.
- **U3-C5 ("Decisions" gone as a label)** The extracted header array from
  U3-C2 contains no element equal to `Decisions`, and
  `git grep -c '>Decisions<' bin/microworld-dashboard/index.html` finds no
  match (exit 1). Scoped deliberately to rendered header text — the
  `data-decision-*` attributes and `decision-item` class are expected to
  remain and must not be renamed.
- **U3-C6 (empty sections)** With `decisionsData` all-empty and one working
  bundle, the extracted header array is exactly `['Microworlds (1)']`. With
  both `bundlesData` and `decisionsData` empty, the array is `[]` and the
  existing empty-state text still renders.
- **U3-C7 (inverted urgency fixed, with regression guard)** With
  `bundlesData: [oneWorkingBundle]` **and** `decisionsData` carrying one
  escalation, `contentHtml` after init contains `<h2>Escalation: ` and does
  not contain the working bundle's `unit` string inside an `<h2>`. With the
  same `bundlesData` and zero escalations, `contentHtml` contains the
  working bundle's `unit` inside an `<h2>` exactly as today.
- **U3-C8 (legacy assertions replaced, not deleted)**
  `git grep -c 'Escalation Packets' tests/dashboard-decisions-client.test.js`
  and `git grep -c 'Working Bundles' tests/dashboard-decisions-client.test.js`
  each find no match (exit 1), and U3-C2 and U3-C6 both exist and pass — the
  coverage those assertions provided is carried by the new ones rather than
  dropped.
- **U3-C9** `bash tests/validate.sh` exits 0 and prints `All checks passed.`

---

### Step 4 — `USER_NAME` default for the escalation `by` field

**Affected files**
- `bin/microworld-dashboard/server.js` (`startServer` reads the env once;
  `/api/context` handler at `:126-136` gains `userName`)
- `bin/microworld-dashboard/index.html` (`init()` fetches `/api/context`
  non-fatally into `defaultBy`; `escalationForm` initial `by` at `:142` and
  `resetDecisionForms()` at `:316` use `defaultBy`)
- `tests/dashboard-feedback.test.js` (owns the `/api/context` server tests
  at `:98-134`)
- `tests/dashboard-decisions-client.test.js` (harness: `makeFetchStub` gains
  a `contextData` parameter and a failure mode; new client cases)
- `tests/dashboard-decision-run.test.js` (server-attribution guard, U4-C5)

**Design**
`startServer()` reads `process.env.USER_NAME` **once**; `GET /api/context`
returns `{ sha, userName }` where `userName = process.env.USER_NAME || ''`.
The client fetches `/api/context` in `init()` inside a guard so that a
non-OK response or a thrown error leaves `defaultBy = ''` and never prevents
render. `resetDecisionForms()` sets `by: defaultBy` rather than `''`, which
fixes the cold-start blank and the per-view-switch wipe with one change.
`#escalationBy` already binds from `escalationForm.by` (`:616`) and already
has a `change` listener (`:647`), so it is pre-filled and remains editable
with no further wiring.

**The server-side `by` default at `server.js:285` stays `''`.** The value
written into a DECISION file and the audit log must be whatever the human
saw and edited in the form — never a value the server supplied on their
behalf. `USER_NAME` is a form pre-fill only.

**Acceptance criteria**
- **U4-C1 (server, both directions)** In `tests/dashboard-feedback.test.js`:
  with `process.env.USER_NAME = 'Seb'` set **before** `startServer`,
  `GET /api/context?t=<token>` parses to an object with `userName === 'Seb'`
  and a `sha` still equal to the git HEAD sha (no regression to the existing
  behaviour). With `USER_NAME` deleted from the env before `startServer`,
  `userName === ''`. The test restores the prior env value afterwards.
- **U4-C2 (cold start)** `renderClient` with `bundlesData: []`,
  `decisionsData` carrying one escalation, and the `/api/context` stub
  returning `{ sha: 'deadbeef', userName: 'Seb' }` → `contentHtml` contains
  `id="escalationBy" value="Seb"`.
- **U4-C3 (survives a view switch — the half the critique's AC-3 missed)**
  In the same render, after switching to a second decision view and back
  (or selecting a second escalation entry), the re-read `contentHtml` still
  contains `id="escalationBy" value="Seb"` and does not contain
  `id="escalationBy" value=""`.
- **U4-C4 (the user's edit wins)** Set
  `elementsById.escalationBy.value = 'Alice'`, fire `change`, then the
  re-read `contentHtml`'s composed-command pane (V1) contains `by: Alice`
  and contains no `by: Seb`.
- **U4-C5 (never server-attributed)** `git grep -c 'USER_NAME' bin/microworld-dashboard/server.js`
  = 1 (the single read in `startServer`), and in
  `tests/dashboard-decision-run.test.js` — using its existing
  `setupDecisionEnvironment` with `ttyWrite` stubbed — a
  `POST /api/decision/arm` that **omits** `by`, made against a server
  started with `USER_NAME=Seb` in env, produces a composed body whose `by:`
  line is empty and which contains no `Seb`.
- **U4-C6 (context failure is non-fatal)** `renderClient` with the
  `/api/context` stub returning `{ ok: false, status: 500 }` → the rail
  still renders (the extracted `.bundle-section-header` array for the
  fixture is non-empty), `contentHtml` contains `id="escalationBy" value=""`,
  and the run completes with no thrown error.
- **U4-C7** `node tests/dashboard-feedback.test.js`,
  `node tests/dashboard-decisions-client.test.js` and
  `node tests/dashboard-decision-run.test.js` each exit 0;
  `bash tests/validate.sh` exits 0 and prints `All checks passed.`

---

### Step 5 — Institutional record (`scribe`)

**Affected files**
- `CONTEXT.md` (glossary)

**Design**
Record the three lens-3 terms and amend the existing **Microworld
dashboard** entry (`CONTEXT.md:1092`) to name the new rail IA. Note in the
**Document pane** entry that the `Review` section header uses "review" in a
UI grouping sense distinct from the `reviewer`-verdict sense used elsewhere
in the glossary, and that `Packet:` is a UI abbreviation of the canonical
**escalation packet**.

**Acceptance criteria**
- **U5-C1 (entries exist)** `git grep -c '^\*\*Document pane\*\*' CONTEXT.md`
  = 1; `git grep -c '^\*\*Markdown-lite renderer\*\*' CONTEXT.md` = 1;
  `git grep -c 'Plans & Specs' CONTEXT.md` ≥ 1.
- **U5-C2 (claim-anchored: the pane count is real)** The **Document pane**
  entry states that six panes render markdown. The reviewer re-derives the
  set of `.doc-pane` render sites from `index.html` (`git grep -n 'doc-pane'
  bin/microworld-dashboard/index.html`, discounting the single CSS rule) and
  confirms it is exactly six and that the entry names those same six. Do not
  substitute a bare `git grep -c` count for this: `-c` counts matching
  *lines*, not occurrences, so two usages on one line would under-report.
- **U5-C3 (claim-anchored: no over-claimed markdown support)** For every
  markdown construct the **Markdown-lite renderer** entry names,
  `tests/dashboard-markdown-lite.test.js` contains a corresponding passing
  case. A construct named in prose with no test case is a FAIL.
- **U5-C4 (claim-anchored: section names match the code)** The three header
  strings quoted in the amended **Microworld dashboard** entry are
  byte-identical to the three strings `renderLeftRail` emits.
- **U5-C5 (version consistency)** Across this plan's full commit range,
  either `.claude-plugin/plugin.json`'s version is unchanged **and**
  `CHANGELOG.md` gains no entry claiming a bump, or both change together and
  agree. (P3 does not fire — no version-stamped file is touched — so no bump
  is required; this criterion only forbids the two drifting apart.)
- **U5-C6** `bash tests/validate.sh` exits 0 and prints `All checks passed.`

---

### Goal-clause → criterion map

| Goal clause | Covered by |
|---|---|
| Review artifacts separated into their own section | U3-C2, U3-C3 |
| Plan/spec artifacts in their own section | U3-C2, U3-C3 |
| Type-identifying row prefixes | U3-C4 |
| Entry counts in headers | U3-C2 |
| "Decisions" umbrella removed | U3-C5 |
| Inverted-urgency auto-select fixed | U3-C7 |
| All md-showing panes render markdown | U2-C2 (six sites), U2-C4 |
| Verbatim panes unchanged | U2-C2 (negative control), U2-C4, U2-C7 |
| Silent truncation replaced by a truthful marker | U2-C5 |
| Renderer is XSS-safe | U1-C3, U1-C4 |
| Renderer is the shipped one, not a copy | U2-C2, U2-C3 |
| Default name from `USER_NAME` at cold start | U4-C1, U4-C2 |
| Default name survives a view switch | U4-C3 |
| User's edit still wins | U4-C4 |
| Server never attributes a name | U4-C5 |

---

## Open Questions

None. Every gap found during authoring was resolvable against the tree or by
a defensible default, and each is recorded as a dated self-resolved line in
Clarifications above — including the four premise corrections, the two
deliberate deviations from the critique's literal text (counts on all three
headers; briefing/working-bundle rows carry no prefix), and the three
additions to the draft acceptance criteria.

Two items the critique raised as adjacent-but-not-required are **deferred**,
not resolved — see Out of Scope. They are recorded as a future spec, not as
`## Convergence follow-ups` on this one, because neither is a gap in this
plan's own goal.

---

## Out of Scope

- **Keyboard accessibility of the left rail.** Rows are unfocusable,
  non-keyboard-activatable `<div>`s. Real, independently testable, and
  orthogonal to all three operator requirements — a separate spec.
- **The 5-second poll's full-`innerHTML` re-render**, which can eat an
  in-flight click or reset rail scroll position (`index.html:1067`,
  `pollBundles` → `renderLeftRail`). Verified not to conflict with Step 3:
  Step 3 changes what markup `renderLeftRail` builds, not the
  replace-and-reattach mechanism, and the poll never re-runs auto-select.
- Any change to `/api/source`'s contract or to `MAX_LINES` (`source.js:10`).
- Any change to the DECISION-file grammar, the arm/run endpoints, or the
  `/dev/tty` confirmation channel.
- Any change to `V1`-`V6` rendering.
- A markdown-rendering pass over the notebook output pane or the
  microworld-bundle function views.

---

## Self-check

- **CHK1**: Are the panes that receive markdown enumerated exhaustively and
  by anchor, rather than described by category? — FAIL (ambiguous) —
  revised in place: added the D1-D6 and V1-V6 tables with current line
  anchors; the pass found `renderPendingReviewView` contributes two verbatim
  command panes, not the one the critique implied.
- **CHK2**: Does the plan say which escape function `markdown-lite.js` uses,
  given it must be `require`-able? — FAIL (missing) — revised in place:
  Context correction 2 plus the Step 1 design paragraph and U1-C2.
- **CHK3**: Is the truncation marker's data source defined, and is the
  marker provably not a false claim? — FAIL (missing) — revised in place:
  `totalLines` verified present in `source.js:171` and passed through at
  `server.js:169`; U2-C5 pins both the truncated and non-truncated cases.
- **CHK4**: Do Steps 2 and 3 agree about whether `decision-item` /
  `data-decision-kind` survive the removal of the word "Decisions"? — PASS
  (Step 3's design paragraph and U3-C5 both scope the removal to rendered
  header text; Step 2 does not touch rail wiring).
- **CHK5**: Is there a criterion that would fail if the shipped page
  re-implemented markdown rendering inline instead of calling the injected
  module? — FAIL (missing) — revised in place: U2-C2's sentinel-stub case,
  plus U2-C3's placeholder-consumed assertion.
- **CHK6**: Is `renderMarkdown`'s behaviour on non-string input defined? —
  FAIL (missing) — revised in place: Step 1 design ("fails closed") and the
  four non-string cases in U1-C3.
- **CHK7**: Is the exact encoding of the `&` in `Plans & Specs` defined, so
  U3-C2's deep-equal assertion is unambiguous? — FAIL (ambiguous) — revised
  in place: pinned as a bare `&` in the Clarifications log and in Step 3's
  design table.
- **CHK8**: Do Steps 3 and 4 agree on which fixture shape a client test uses
  to reach the escalation view, given Step 3 changes auto-select? — PASS
  (Step 4's U4-C2/C6 specify `bundlesData: []`, which selects the escalation
  under both the old and the new auto-select rule, so Step 4 is order-
  independent with respect to Step 3).
- **CHK9**: Does the plan name the existing test assertions the IA change
  breaks? — FAIL (missing) — revised in place: Context correction 4, R4,
  Step 3's affected files, and U3-C8.
- **CHK10**: Is every acceptance criterion something an agent can run and
  get a pass/fail from? — PASS (each is a command exit status, an exact
  string/array comparison against rendered output, or — for U1-C4 — a
  named revert-and-rerun the reviewer performs).
- **CHK11**: Is each of the operator's three verbatim requirements traceable
  to at least one criterion? — PASS (Goal-clause → criterion map;
  requirement 1 → U3-C2/C3/C4/C5, requirement 2 → U2-C2/C4/C5, requirement 3
  → U4-C1/C2/C3/C4).
- **CHK12**: Does the plan state what happens when the newly-added `init()`
  fetch fails? — FAIL (missing) — revised in place: Context correction 3,
  the Edge-cases clarification, Step 4's design paragraph, and U4-C6.
- **CHK13**: Is the Constitution check's P3 line justified rather than
  asserted? — PASS (justified twice: no version-stamped file is in any
  unit's affected-files list, and the convention was verified against
  commits `417ad35` and `0779929`).
- **CHK14**: Does the plan distinguish deferred adjacent work from work this
  plan owns, without leaving it implicit? — PASS (Out of Scope names both
  items, states why each is deferred, and records the verified
  non-conflict between the poll-race item and Step 3).
- **CHK15**: Is any criterion an existence-grep that would pass against a
  broken implementation? — FAIL (ambiguous, at first draft) — revised in
  place: U1 gained the mutation proof (U1-C4), U2's grep-shaped checks
  (U2-C3, U2-C7) were each paired with a rendered-output assertion, and U5's
  docs criteria were rewritten from "the entry exists" to claim-anchored
  re-derivation (U5-C2, U5-C3, U5-C4).

All FAIL items above were resolved by in-place revision; none required
conversion to an Open Question, and the Open Questions list is
correspondingly empty.

---

## Scribe update hint

After Unit 5 lands, `CONTEXT.md` carries the three new glossary entries and
the amended **Microworld dashboard** entry. No ADR is warranted: this is a
usability revision within an already-decided architecture (ADR-0004,
ADR-0019 and the microworld-dashboard plan of 2026-08-10 remain accurate).
`.claude/wiki/architecture.md` needs no change — it documents the
server/polling model, which is untouched; note the gh323 precedent that a
careless edit there is exactly how a false claim got shipped last time.
`README.md`'s "Microworld dashboard" section (`:260-326`) documents startup,
tokens and feedback blocks, none of which change; it does not describe the
rail sections, so it needs no edit.

---

## Dispatch contracts (fast path — ≤5 units, no `task-master`)

Retrieval contract for every unit below: **no tracker issue exists.** Read
this document at `/home/sebas/AntiSlop/docs/plans/2026-08-18-dashboard-usability-revision.md`
and work from the named Step. Do not run `gh issue view`.

---

**Unit: dash-ux-1**

## Objective
Add `bin/microworld-dashboard/markdown-lite.js`, a vendored,
dependency-free, dual-environment markdown renderer, plus its unit-test
suite, registered in the merge gate. Module only — no page wiring in this
unit.

## Retrieval
`/home/sebas/AntiSlop/docs/plans/2026-08-18-dashboard-usability-revision.md`,
Step 1. No tracker issue.

## Affected files
- `bin/microworld-dashboard/markdown-lite.js` (new)
- `tests/dashboard-markdown-lite.test.js` (new)
- `tests/validate.sh` (register the suite, following `:573-635`'s block shape)

## Ordered edits
1. Write `markdown-lite.js` following `decision-block.js`'s dual-environment
   shape exactly: zero `require(`, zero `document.`, a guarded
   `module.exports` tail.
2. Implement the private DOM-free `escapeHtml` (`& < > " '`) and make every
   text span pass through it before any tag is emitted.
3. Implement the constructs listed in Step 1's design paragraph.
4. Implement the link-scheme allowlist (`http:`, `https:`, relative) and the
   `rel`/`target` attributes on emitted anchors.
5. Make non-string input fail closed.
6. Write `tests/dashboard-markdown-lite.test.js` covering every case in
   U1-C3, following `tests/dashboard-decision-block.test.js`'s style
   (Node built-in runner conventions used by this repo, CommonJS `require`,
   a `failures` array with a non-zero exit).
7. Register the suite in `tests/validate.sh`.

## Do NOT touch
`index.html`, `server.js`, any other `tests/dashboard-*.test.js`,
`CONTEXT.md`, `README.md`, `.claude-plugin/plugin.json`, `CHANGELOG.md`.
No page wiring in this unit — Step 2 owns it.

## Acceptance criteria
U1-C1 through U1-C5, verbatim from Step 1.

## Pre-resolved context
- `decision-block.js:220-222` is the exact `module.exports` guard shape to
  copy; the 379 review confirmed `grep -n "require(" decision-block.js`
  returns nothing, and U1-C2 pins the same property here.
- The page's `escapeHtml` (`index.html:1048`) is **DOM-dependent** and must
  not be reused or imported — that is why this module carries its own.
- `tests/validate.sh:663` prints `All checks passed.`; per-suite lines are
  `OK   tests/<name>` with three spaces.

## Escalation
If a required markdown construct cannot be implemented without a dependency
or a build step, stop and report — do not add either. If U1-C4's mutation
proof does not fail the suite, the escape call is not load-bearing: report
it rather than weakening the criterion.

---

**Unit: dash-ux-2**

## Objective
Wire `renderMarkdown` into the six document panes (D1-D6), add the
`.doc-pane` CSS class and the truthful truncation marker, leaving the six
verbatim panes (V1-V6) unchanged — and prove the shipped page calls the
injected module rather than an inline copy.

## Retrieval
Same document, Step 2. No tracker issue. **Depends on `dash-ux-1`.**

## Affected files
- `bin/microworld-dashboard/index.html`
- `bin/microworld-dashboard/server.js`
- `tests/dashboard-decisions-client.test.js`
- `tests/dashboard-client.test.js`

## Ordered edits
Step 2's "Ordered design" list, items 1-5, in that order.

## Do NOT touch
V1 (`index.html:620`), V2 (`:764`), V3 (`:806`), V4 (`:812`),
V5 (`:415`, `:1171-1202`), V6 (`renderNotebook`'s stdout/stderr cells), the
`.excerpt-pane` and `.excerpt-line` CSS rules, `renderLeftRail`,
`autoSelectDecisionView`, `markdown-lite.js` itself, `CONTEXT.md`.

## Acceptance criteria
U2-C1 through U2-C8, verbatim from Step 2.

## Pre-resolved context
- Injection pattern to mirror: `server.js:81-89`; placeholders at
  `index.html:116` and `:123`.
- `/api/source` already returns `totalLines` (`source.js:171`), emitted
  whole by `server.js:169`. `MAX_LINES = 400` is a server-side hard cap —
  raising the client's `endLine` gains nothing.
- The harness at `tests/dashboard-decisions-client.test.js:73-134` already
  `vm.runInContext`s `feedback-block.js` and `decision-block.js` before the
  module script; adding `markdown-lite.js` is the same one-line pattern.
  Add an optional `markdownStub` parameter for U2-C2.
- D4 and D5 currently render per-line `.excerpt-line` divs; both must
  `join('\n')` and render once.

## Escalation
If any of the six document sites cannot be switched without also changing a
verbatim site, stop and report — do not compromise the negative control.

---

**Unit: dash-ux-3**

## Objective
Replace the "Working Bundles" / "Escalation Packets" / "Decisions" rail
structure with three counted, type-prefixed sections — `Review`,
`Plans & Specs`, `Microworlds` — and fix the inverted-urgency auto-select.

## Retrieval
Same document, Step 3. No tracker issue. Independent of `dash-ux-1`/`-2`.

## Affected files
- `bin/microworld-dashboard/index.html`
- `tests/dashboard-decisions-client.test.js`

## Ordered edits
1. Restructure `renderLeftRail` (`:210-276`) and `renderDecisionsLeftRail`
   (`:281-309`) into the three sections of Step 3's table, in that document
   order, each rendered only when non-empty, each header carrying its exact
   entry count.
2. Add the `Packet: ` prefix to packet-bundle rows; leave briefing and
   working-bundle rows unprefixed.
3. Write `Plans & Specs` with a bare `&`.
4. Change `init()` (`:1056-1068`) so an open escalation is selected ahead of
   a working bundle; keep the rest of the order as Step 3 states.
5. Replace the legacy header assertions at
   `tests/dashboard-decisions-client.test.js:160-167` and `:194` with the
   new header-set assertions; add the U3-C3/C4/C6/C7 cases.

## Do NOT touch
The `data-decision-kind` / `data-decision-key` attributes, the
`decision-item` class, the `decisionCopyBtn` id, any decision *view*
renderer, `server.js`, `decisions.js`, `discover.js`, `markdown-lite.js`,
`CONTEXT.md`.

## Acceptance criteria
U3-C1 through U3-C9, verbatim from Step 3.

## Pre-resolved context
- `.bundle-section-header` is `text-transform: uppercase` (`index.html:88`)
  — that is visual only; the DOM text is exactly as authored, which is what
  U3-C2 asserts.
- Rows under `Review` are a deliberate mix: packet bundles keep
  `data-bundle-id` and the `.bundle-item` click handler; the other three
  kinds keep `data-decision-kind` and the `.decision-item` handler. Both
  handlers already exist at `:258-275` and need no change.
- `tests/dashboard-decisions-client.test.js:160-167` and `:194` **will fail**
  until edited; that is expected, not a regression.

## Escalation
If the count in a header cannot be derived without a second pass over the
data, report rather than approximating it — U3-C2 asserts exact counts.

---

**Unit: dash-ux-4**

## Objective
Default the escalation-decision `by` field from `USER_NAME`, fixing both the
cold-start blank and the per-view-switch wipe, without ever letting the
server attribute a name the human did not see.

## Retrieval
Same document, Step 4. No tracker issue. Independent of `dash-ux-1`/`-2`/`-3`.

## Affected files
- `bin/microworld-dashboard/server.js`
- `bin/microworld-dashboard/index.html`
- `tests/dashboard-feedback.test.js`
- `tests/dashboard-decisions-client.test.js`
- `tests/dashboard-decision-run.test.js`

## Ordered edits
1. `startServer()` reads `process.env.USER_NAME` once.
2. `/api/context` (`server.js:126-136`) returns `{ sha, userName }` with
   `userName = process.env.USER_NAME || ''`; its existing error behaviour is
   unchanged.
3. `init()` fetches `/api/context` into `defaultBy` **inside a guard** — a
   non-OK response or a thrown error leaves `defaultBy = ''` and never
   prevents render.
4. `escalationForm`'s initial `by` (`index.html:142`) and
   `resetDecisionForms()` (`:316`) use `defaultBy`.
5. Extend `makeFetchStub` with a `contextData` parameter and a failure mode;
   add the U4-C2/C3/C4/C6 cases.
6. Add the U4-C1 server cases to `tests/dashboard-feedback.test.js` and the
   U4-C5 attribution guard to `tests/dashboard-decision-run.test.js`.

## Do NOT touch
`server.js:285`'s `by = ''` default — it must stay `''`. The
`#escalationBy` input's existing binding (`:616`) and `change` listener
(`:647`) need no change. Do not touch `renderLeftRail`,
`autoSelectDecisionView`, `decision-block.js`, or the arm/run endpoints'
validation.

## Acceptance criteria
U4-C1 through U4-C7, verbatim from Step 4.

## Pre-resolved context
- The client's only existing `/api/context` fetch is the lazy one inside
  `doCopyFeedback` (`index.html:1282`); leave it alone, add a separate
  guarded fetch in `init()`.
- `/api/context` returns 500 when `git rev-parse HEAD` throws — that is why
  step 3 above is guarded, and it is what U4-C6 pins.
- The harness already stubs `/api/context` as `{ sha: 'deadbeef' }`
  (`tests/dashboard-decisions-client.test.js:64`) and already exposes
  `elementsById.escalationBy` as a drivable control (`:95`).
- Unit 380 reached the 2-FAIL cap on exactly this endpoint family via type
  confusion; do not relax any existing `by`/`reason` validation while
  editing nearby.

## Escalation
If the env read cannot be confined to a single site in `startServer` without
threading it through unrelated call sites, report — U4-C5 asserts exactly
one `USER_NAME` occurrence in `server.js`.

---

**Unit: dash-ux-5** (`scribe`)

## Objective
Record the new vocabulary and the new rail IA in `CONTEXT.md`, with every
claim re-derived from the shipped tree.

## Retrieval
Same document, Step 5. No tracker issue. **Depends on `dash-ux-1` through
`dash-ux-4` having landed.**

## Affected files
- `CONTEXT.md`

## Ordered edits
1. Add a **Document pane** entry defining the document/verbatim split,
   naming the six document panes, and noting that the `Review` section
   header uses "review" in a UI grouping sense distinct from the
   `reviewer`-verdict sense.
2. Add a **Markdown-lite renderer** entry — escape-first, dependency-free,
   dual-environment, link-scheme allowlist — naming only constructs that
   `tests/dashboard-markdown-lite.test.js` actually covers.
3. Amend the **Microworld dashboard** entry (`CONTEXT.md:1092`) to name the
   three rail sections, quoting the header strings byte-identically to what
   `renderLeftRail` emits, and noting that `Packet:` is a UI abbreviation of
   the canonical **escalation packet**.

## Do NOT touch
`.claude/wiki/architecture.md` (it documents the server/polling model, which
is unchanged — see the gh323 precedent), `README.md`, any file under
`bin/` or `tests/`, `.claude-plugin/plugin.json`, `CHANGELOG.md`.

## Acceptance criteria
U5-C1 through U5-C6, verbatim from Step 5.

## Pre-resolved context
- `CONTEXT.md` has **no** entry for "briefing" today, despite the code using
  it for `docs/plans/*.md` entries. Adding one is optional here; if added,
  U5-C3's no-over-claim rule applies to it too.
- gh323 FAILed a docs unit for a single false clause about live re-rendering
  that one grep would have refuted. Every claim in this unit is
  re-derivable; re-derive it rather than paraphrasing this plan.

## Escalation
If any claim this unit would make cannot be re-derived from the shipped
tree, do not soften the wording — report the discrepancy, since it means an
earlier unit did not ship what this plan describes.
