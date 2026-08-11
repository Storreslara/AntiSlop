# Microworld dashboard — Gruvbox Material restyle (ClaudeVoice aesthetic parity)

Date: 2026-08-11
Author: spec-master
Status: **FINAL — all 4 Open Questions answered by the owner 2026-08-11**
(OQ1(a) all-monospace, OQ2(a) dark-only, OQ3(a) reviewer PASSes on Criteria
1–9, OQ4(a) dispatch now in parallel with #328–#332). Dispatchable as one
fast-path unit. PRD view published as issue **#333** (`ready-for-agent`); this
document remains authoritative.

---

## Goal

Restyle the **Microworld dashboard**'s single-file UI
(`bin/microworld-dashboard/index.html`) so its visual surface reads as the same
design system as the sibling project at `/home/sebas/ClaudeVoice`
(`frontend/`), by adopting that project's Gruvbox Material Dark color tokens,
its 4px spacing scale, its radius scale, its monospace type stack, and its
component-chrome patterns (pill buttons, ghost buttons, dot chips, three-layer
depth, gated motion, yellow focus ring).

Explicitly **not** in this goal: any change to layout structure, DOM structure,
element ids/classes/data-attributes, JS behavior (bundle discovery, 5s polling,
`POST /api/invoke`, Cell notebook mechanics, excerpt loading, feedback-block
copy, clipboard fallback), server routes, auth, or the audit-log contract.

---

## Context

### What ClaudeVoice's frontend actually is (inspected, not assumed)

`/home/sebas/ClaudeVoice/frontend/` is React 19 + Vite 8 + TypeScript, but its
**styling** carries none of that weight — it is two hand-written plain-CSS
files with zero framework:

| Fact | Evidence |
|---|---|
| No Tailwind, no CSS framework, no component library | `frontend/package.json` deps are only `react`, `react-dom`, `@xterm/*` |
| All CSS is hand-written plain CSS | `src/index.css` (55 lines) + `src/App.css` (463 lines); no other `.css`/`.scss` in `src/` |
| Color tokens are 13 pinned hexes | `src/theme/gruvbox.ts` — Gruvbox Material Dark, medium background |
| Tokens reach CSS as `--gvx-*` custom properties | `applyTheme()` in `gruvbox.ts` sets them on `<html>` at runtime from `main.tsx` |
| Scale tokens are static CSS | `src/index.css` `:root` — `--space-1/2/3/4/6`, `--radius-card/chip/pill` |
| Type is all-monospace, **no webfont download** | `index.css` body: `'JetBrains Mono', 'Cascadia Code', ui-monospace, Consolas, monospace` — a system-fallback stack; the source comment records this as a deliberate decision ("OQ3: no self-hosted font") |
| Dark-only, no light theme, no toggle | `index.css` body sets `color-scheme: dark`; no light branch anywhere in either CSS file |
| Palette is AA-contrast verified upstream | `src/theme/contrast.ts` + `contrast.test.ts` assert ≥ 4.5:1 |

The 13 pinned hexes (`src/theme/gruvbox.ts`):

| Token | Hex | Token | Hex |
|---|---|---|---|
| `--gvx-bg-dim` | `#1d2021` | `--gvx-red` | `#ea6962` |
| `--gvx-bg` | `#282828` | `--gvx-green` | `#a9b665` |
| `--gvx-bg-soft` | `#32302f` | `--gvx-yellow` | `#d8a657` |
| `--gvx-fg` | `#d4be98` | `--gvx-blue` | `#7daea3` |
| `--gvx-fg-bright` | `#ddc7a1` | `--gvx-purple` | `#d3869b` |
| `--gvx-gray` | `#928374` | `--gvx-aqua` | `#89b482` |
| | | `--gvx-orange` | `#e78a4e` |

Scale tokens (`src/index.css`): `--space-1: 4px`, `--space-2: 8px`,
`--space-3: 12px`, `--space-4: 16px`, `--space-6: 24px`; `--radius-card: 8px`,
`--radius-chip: 6px`, `--radius-pill: 22px`.

Component-chrome patterns worth porting (`src/App.css`):
- **Three-layer depth** — page = `bg-dim`, card = `bg`, border = `bg-soft`;
  card shadow `0 4px 16px rgba(0, 0, 0, 0.4)`.
- **Pill button** (`.ptt-pill`) — `--radius-pill`, solid token background,
  `color: var(--gvx-bg)` (dark text on the accent), `font-weight: 600`.
- **Ghost button** (`.ghost-button`) — transparent bg, `1px solid var(--gvx-gray)`,
  `--radius-chip`, hover raises the border to `--gvx-fg`.
- **Dot chip** (`.chip` + `.chip-dot`) — 6px round dot, `--radius-chip`,
  card bg, `bg-dim` border, `0.85em`, accent-colored border per severity.
- **Status dot** — round, colored green / yellow / red / gray by state.
- **Focus ring** — `:focus-visible { outline: 2px solid var(--gvx-yellow);
  outline-offset: 2px; }`.
- **Motion is off by default** and enabled only inside
  `@media (prefers-reduced-motion: no-preference)`.

### What the dashboard is today (inspected)

`bin/microworld-dashboard/index.html`, 810 lines, one file, no build step:

- A **57-line `<style>` block** (lines 8–64) — light Material-ish palette:
  `#fafafa` page, `#f0f0f0` rail, `#fff` cards, `#2196f3` primary,
  `#4caf50` / `#f44336` / `#ff9800` / `#9e9e9e` status, `system-ui` sans.
- A `<script>/* __FEEDBACK_BLOCK_SOURCE__ */</script>` placeholder that
  `server.js`'s `GET /` handler string-replaces with `feedback-block.js`.
- A `<script type="module">` client (lines 86–808) that renders everything.

**The load-bearing finding:** styling is *not* confined to the `<style>`
block. There are **36 inline `style="…"` attributes inside the module script's
template literals**, carrying **29 distinct hex literals / 90 hex occurrences**
across the whole file. Every Cell in the notebook, the cell control buttons,
the stdout/stderr blocks, the fresh-process notice, the disabled banner, the
excerpt line numbers, and every error/empty branch are styled inline. A
`<style>`-block-only reskin would therefore produce a dark shell wrapped around
a light, unreadable notebook — the single most-used surface of the page. Any
faithful restyle must reach into those 36 inline attributes.

Distinct visual surfaces requiring restyle (enumerated from the file):

| # | Surface | Where |
|---|---|---|
| 1 | Page background / body type | `<style>` `body` |
| 2 | Left rail + its scroll container | `.left-rail` |
| 3 | Rail section headers ("Working Bundles" / "Escalation Packets") | `.bundle-section-header` |
| 4 | Bundle rows: default / hover / active | `.bundle-item`, `.bundle-item.active` |
| 5 | Status indicators — pass / fail / timeout / unknown | `.status-pass/-fail/-timeout/-unknown` |
| 6 | Header bar + `<h1>` | `.header`, `h1` |
| 7 | Group tab row + function tab row | `.tabs-container`, `.tab-button`, `.tab-button.active` |
| 8 | Empty states (3 variants) | `.empty-state`, `.empty-state-text`, `.code` |
| 9 | Invoke form pane | `.form-pane`, `.form-group`, `label`, `label .desc` |
| 10 | Text / number / textarea inputs + focus | `input[type=…]`, `textarea` |
| 11 | Primary action button | `.submit-btn` (+ `:hover`, `:disabled`) |
| 12 | Copy-feedback button + confirmation | `.copy-btn`, `.copy-feedback` |
| 13 | Comment box | `.comment-box` |
| 14 | Source excerpt pane + line numbers | `.excerpt-pane`, `.excerpt-line`, inline `#999` |
| 15 | Output pane (Cell notebook container) | `.output-pane` |
| 16 | Cell container / header / body | inline styles, `renderCell()` |
| 17 | Cell control buttons: Edit / Collapse / Remove / Copy | inline styles, `renderCell()` |
| 18 | stdout block | inline styles, `renderCell()` |
| 19 | stderr block | inline styles, `renderCell()` |
| 20 | "each cell runs in a fresh process" notice | inline styles, `renderNotebook()` |
| 21 | Exit-code / duration / output labels | `.output-label`, `.exit-code` |
| 22 | Timeout / truncated banners | `.banner`, `.banner-timeout`, `.banner-truncated` |
| 23 | Disabled-function notice | inline styles, `renderContent()` |
| 24 | "no functions declared" notice | `.no-functions` |
| 25 | Error text (fetch failure, invoke failure) | inline `#f44336`, 4 sites |
| 26 | Spinner keyframes | `.spinner`, `@keyframes spin` |

### Constraints discovered (each verified, not inferred)

1. **No build step exists and none can be added here.** ClaudeVoice's React /
   Vite / TS toolchain is irrelevant to the *styling* (which is plain CSS), so
   nothing about the aesthetic requires it. Adopting Vite/React/Tailwind for
   this page would be a build-tooling change — **out of scope**, and
   unnecessary: 100% of the target aesthetic is expressible as plain CSS
   custom properties in the existing `<style>` block.
2. **Runtime token injection is not portable.** ClaudeVoice sets `--gvx-*` from
   TS at runtime. The dashboard has no module for that, and adding a second
   `<script>` risks the test harness's script extraction (below). Tokens must
   be declared **statically** in `:root` inside the existing `<style>` block.
3. **The test harness extracts the client by regex.**
   `tests/dashboard-client.test.js:41` and `tests/dashboard-notebook.test.js:74`
   both do `html.match(/<script type="module">([\s\S]*?)<\/script>/)` —
   non-greedy, first match. Verified matching today (28760 chars). No new
   `<script type="module">` block may be introduced before it, and no
   `</script>` may appear inside it.
4. **No external assets are permitted.**
   `tests/dashboard-client.test.js` Test (c) fails on any
   `<script src="http(s)://…">`. A webfont `<link>` would slip that regex but
   is wrong regardless: the dashboard is loopback-only and often used offline,
   and ClaudeVoice itself downloads no font. The system-fallback monospace
   stack ports over verbatim with zero network dependency.
5. **No test asserts any CSS, class, or color.** Verified: the only `style`
   hits in `tests/dashboard-*.test.js` are two `style: {}` DOM stubs in
   `dashboard-feedback.test.js:658,667`. Tests do assert on rendered text
   (`"Expand"`, `"(1 cell)"`, `"(2 cells)"`), on `data-group-name=`, and on
   `value=` — none of which a restyle touches.
6. **The spacing scale already lines up exactly.** Today's `0.25 / 0.5 / 0.75 /
   1 / 1.5 rem` are precisely `4 / 8 / 12 / 16 / 24 px` — ClaudeVoice's
   `--space-1/2/3/4/6`. Adopting the scale is therefore a **pure rename with
   zero geometry change** for every value except three off-scale literals
   (`2rem` empty-state padding; `0.2rem`/`0.4rem` inline-code padding).
7. **No CSP header** is sent by `server.js`, so inline styles keep working.
8. **Single copy of the file.** `find` confirms exactly one `index.html`; there
   is no shipped mirror to keep in parity, and `package.json`'s `files` ships
   the whole `bin` entry, so packaging needs no change.
9. **The directory is mid-flight-renamed.** `bin/dashboard/` →
   `bin/microworld-dashboard/` landed on disk as unit #327, whose review
   returned **ESCALATE-TO-HUMAN** (heavy-unit file-count trigger) and is
   awaiting the owner's decision. The new path is what is on disk and is the
   only path this plan uses.
10. **An in-flight sibling plan will move the test files.**
    `docs/plans/2026-08-11-microworld-silo.md` Step 2 (issue #328) relocates
    `tests/dashboard-*.test.js` → `tests/microworld/`. Every criterion below is
    written to survive that move (see Risks R2).

### Baselines measured today (2026-08-11, on `master` at `cfa1389`)

| Measurement | Command | Baseline |
|---|---|---|
| Full gate | `bash tests/validate.sh` | exit **0** |
| Gruvbox tokens present | `grep -c 'gvx-' bin/microworld-dashboard/index.html` | **0** |
| Distinct hex literals | `grep -o '#[0-9a-fA-F]\{3,6\}' … \| sort -u \| wc -l` | **29** |
| Total hex occurrences | same, without `sort -u` | **90** |
| Inline `style="` attributes | `grep -c 'style="' …` | **36** |
| Module-script regex extraction | node `match()` | **MATCH, 28760 chars** |
| CLI smoke | `node bin/cli.js --dashboard --dashboard-port=0` | prints `http://127.0.0.1:<port>/?t=<64-hex>` |
| DOM-contract token check (Criterion 4) | `scripts` block below | **0 missing** |

Baselines expire — the implementer must re-measure before claiming a delta.

---

## Clarifications

1. Functional scope & success criteria: Partial
2. Domain entities / data model: Clear
3. User interaction flow: Clear
4. Non-functional attributes (perf, security, scale): Partial
5. External dependencies & integrations: Clear
6. Edge cases / failure handling: Partial
7. Technical constraints & tradeoffs: Partial
8. Terminology consistency: Clear
9. Completion / acceptance signals: Missing

- 2026-08-11 Functional scope & success criteria: Q What does "mimic
  ClaudeVoice's styling" concretely mean — which artifacts are adopted and
  which are excluded? → A (self-resolved): adopt exactly four things — (a) the
  13 `--gvx-*` color tokens at their pinned hex values, under the same names;
  (b) the `--space-*` / `--radius-*` scale, same names and values; (c) the
  monospace system-fallback font stack verbatim; (d) the component-chrome
  patterns (three-layer depth, pill/ghost buttons, dot chips, focus ring,
  gated motion). Exclude all branding: no favicon (ClaudeVoice's
  `public/favicon.svg` is a purple `#863bff` branded mark), no `icons.svg`, no
  `hero.png`, no wordmark, and no copy — the page keeps its own
  `<title>` and `<h1>Microworld Dashboard</h1>` text unchanged. Exclude
  ClaudeVoice's *layout* (its header wordmark/status split, two-column grid,
  responsive breakpoints) — that is layout, not styling, and layout is out of
  scope.
- 2026-08-11 Functional scope & success criteria: Q Does "mimic" extend to
  ClaudeVoice's build tooling? → A (self-resolved): no. The aesthetic is 100%
  plain CSS; React/Vite/TS carry none of it. A build-tooling change is out of
  scope and is not needed — surfaced explicitly per the request's step 3.
- 2026-08-11 Non-functional attributes: Q Must the restyle add a network
  dependency (webfont)? → A (self-resolved): no. ClaudeVoice downloads no
  font; its stack is system-fallback monospace. The dashboard is loopback-only
  and is used offline, and `dashboard-client.test.js` Test (c) already bars
  external scripts. Criterion 6 gates this.
- 2026-08-11 Non-functional attributes: Q Is contrast/accessibility a
  requirement this plan must re-verify? → A (self-resolved): no re-gate. The
  palette is AA-verified upstream by ClaudeVoice's own
  `src/theme/contrast.test.ts` (≥ 4.5:1). Adopting the pinned hexes inherits
  that property; re-asserting it here would be a criterion about the palette,
  not about the diff, and would be true before and after (vacuous). Cited as
  provenance in Implementation Decisions instead.
- 2026-08-11 Non-functional attributes: Q Should motion be gated? → A
  (self-resolved): yes — wrap the existing `@keyframes spin` consumer in
  `@media (prefers-reduced-motion: no-preference)`, matching ClaudeVoice's
  default-off pattern, and add the `:focus-visible` yellow ring.
- 2026-08-11 Edge cases / failure handling: Q How are the 36 inline
  `style="…"` attributes inside the module script's template literals to be
  handled — hoisted into CSS classes, or token-swapped in place? → A
  (self-resolved): **token-swapped in place**. Every hex literal inside an
  inline `style` becomes a `var(--gvx-…)` / `var(--space-…)` /
  `var(--radius-…)` reference; the attribute stays inline and the emitted
  markup keeps byte-identical element ids, class lists, and data-attributes.
  Rationale: hoisting to classes would rewrite the emitted markup, which the
  request forbids ("no change to DOM element IDs/classes"), and would enlarge
  the review surface for zero visual gain. Criterion 4 mechanically enforces
  the no-markup-change half of this.
- 2026-08-11 Edge cases / failure handling: Q Do the error/empty/disabled/
  escalation-packet branches count as surfaces? → A (self-resolved): yes — all
  26 surfaces enumerated in Context are in scope, including the three empty
  states, the four error branches, the disabled-function notice, and the
  "Escalation Packets" rail section. A restyle that leaves an error branch
  light-on-dark is an incomplete restyle.
- 2026-08-11 Technical constraints & tradeoffs: Q Can tokens be injected at
  runtime as ClaudeVoice does? → A (self-resolved): no — declared statically
  in `:root` in the existing `<style>` block, because the dashboard has no
  module for runtime injection and a second script block risks the tests'
  non-greedy `<script type="module">` extraction regex.
- 2026-08-11 Technical constraints & tradeoffs: Q Does the in-flight
  `bin/dashboard` → `bin/microworld-dashboard` rename (#327, escalated) or the
  test relocation (#328) block this work? → A (self-resolved): no file
  collision — this plan touches exactly one file, which no remaining silo step
  touches. See Risks R2 for the criteria-wording mitigation.
- 2026-08-11 Terminology consistency: Q Does the request's vocabulary diverge
  from `CONTEXT.md`? → A (self-resolved): no divergence blocking the plan.
  `ubiquitous-language` prose-mode findings are recorded under Further Notes;
  all are advisory.
- 2026-08-11 Functional scope & success criteria: Q How far does the monospace
  stack reach — the whole UI as ClaudeVoice does it, or code/output only? → A:
  **all-monospace, exact mimicry** (OQ1(a), owner). One `font-family` on
  `body`; every surface inherits, including the rail, header, form labels and
  prose. The dashboard is a developer tool showing code and shell output, so
  the content suits it.
- 2026-08-11 Functional scope & success criteria: Q Dark-only as ClaudeVoice
  ships it, or add a light mode the dashboard currently has? → A: **dark-only,
  no toggle** (OQ2(a), owner). No `prefers-color-scheme: light` branch, no
  in-page toggle, one palette. This deliberately inverts the dashboard's
  current light appearance.
- 2026-08-11 Technical constraints & tradeoffs: Q Sequence this behind the
  in-flight `microworld-silo` plan, or in parallel? → A: **dispatch now, in
  parallel with #328–#332** (OQ4(a), owner). Unblocked: unit #327's escalation
  was approved and its PASS marker is on disk (verified 2026-08-11), so
  `bin/microworld-dashboard/` is the settled path. No file collision — this
  unit touches one file no remaining silo step touches.
- 2026-08-11 Completion / acceptance signals: Q Who confirms "it looks like
  ClaudeVoice", and does that block PASS? → A: **the reviewer PASSes on
  Criteria 1–9; the owner runs the visual check post-PASS** (OQ3(a)). A defect
  found visually opens a fast follow-up unit rather than blocking this one.
  The reviewer must state plainly in its verdict that appearance was not
  verified, rather than implying it was.

---

## Risks and dependencies

- **R1 — The inline-style surface is the real work, and it is easy to
  under-deliver.** 36 attributes, spread across `renderNotebook()`,
  `renderCell()`, `renderContent()` and `loadExcerpt()`. Missing even a few
  leaves light-on-dark patches in the most-used pane. Mitigation: Criterion 2
  is an exhaustive "no legacy hex survives anywhere in the file" check, which
  cannot pass while any inline attribute is unconverted.
- **R2 — In-flight sibling plan (`2026-08-11-microworld-silo`) moves the test
  files.** Issue #328 relocates `tests/dashboard-*.test.js` → `tests/microworld/`.
  Mitigation: no criterion below names an individual test file path. The suite
  is invoked as `bash tests/validate.sh`, which is authoritative and stable
  across the move (it is itself updated by #328). If a criterion must name a
  test, it is written as a glob resolved at run time.
- **R3 — RESOLVED 2026-08-11.** Unit #327 (the `bin/dashboard` →
  `bin/microworld-dashboard` rename, commit `c276759`) was escalated on the
  heavy-unit file-count trigger; the owner approved it and its PASS marker is
  now on disk (verified, not assumed). The path this plan uses is settled, and
  the precondition this risk once imposed on dispatch is discharged.
- **R4 — Prior defect history in this area.** There is no prior `.fail` record
  for any dashboard *styling* unit (the whole reviewed-marker directory was
  enumerated, not sampled). Adjacent history that is nonetheless relevant:
  `gh323` and `gh138` both FAILed in the microworld/dashboard area, and
  `gh138` hit the 2-FAIL cap — both on **prose accuracy behind existence-only
  criteria**, not on code. That is why Criterion 2 is an exhaustive-negative
  ("no legacy hex remains") rather than an existence-positive ("gruvbox hexes
  appear"): an existence check would pass on a one-line token block with 90
  legacy hexes still in force. This unit must not be tagged `haiku`.
- **R5 — Visual fidelity is not mechanizable.** No grep can decide "does this
  look like ClaudeVoice". Stated plainly rather than faked; see Criterion 10
  and OQ3. Every *other* criterion is a genuine pass/fail command.
- **R6 — Constitution P3 could be read as firing.** `index.html` is not
  `agents/*.md` and not a template, so P3 does not fire (see Constitution
  check). Deliberately **no** version bump and **no** CHANGELOG edit in this
  unit — silo Step 6 (#332) owns a CHANGELOG edit and a version bump, and two
  units editing CHANGELOG concurrently would conflict.
- **Dependency:** none on any unbuilt code. The work is one file, self-contained.

---

## Constitution check (.claude/constitution.md v1.0.0)

- P1 "Verify, don't assume" (MUST): satisfied — every claim in Context was
  measured (baselines table), and every acceptance-criteria command below was
  executed against the current tree before being written down, including a
  mutation test proving Criterion 4 non-vacuous.
- P2 "Prefer deterministic scripts over LLM re-derivation" (MUST): satisfied —
  `index.html` has no script-driven path; it is not tracked by `--update`'s
  `fileHashes` (verified in #327's review: that machinery tracks adapted
  persona/template specs, not `bin/`). Hand-editing is the correct route here.
- P3 "Version-stamp discipline" (MUST): satisfied, does not fire —
  `bin/microworld-dashboard/index.html` is neither `agents/*.md` nor a
  template. No `plugin.json` bump and no CHANGELOG entry in this unit (see R6).
- P4 "Optional personas degrade gracefully" (SHOULD): not applicable — no
  shared prose about personas is touched.
- P5 "`tests/validate.sh` is the merge gate" (MUST): satisfied — Criterion 1 is
  `bash tests/validate.sh` exiting 0, re-measured green today as the baseline.

---

## Step 1 — Restyle `index.html` to the Gruvbox Material Dark token system

**One unit. One file.**

**Affected files**
- `bin/microworld-dashboard/index.html` — the `<style>` block (lines 8–64) and
  the 36 inline `style="…"` attributes inside the `<script type="module">`
  block. **No other file in the repository is modified.**

### 1a — Declare the token block

At the top of the existing `<style>` block, add a static `:root` rule
declaring all 13 `--gvx-*` tokens at their pinned hex values (table in
Context), plus `--space-1/2/3/4/6` and `--radius-card/chip/pill` at
ClaudeVoice's values. These 13 hexes become the **only** hex literals allowed
anywhere in the file. Add `color-scheme: dark` on `body`, and the monospace
stack `'JetBrains Mono', 'Cascadia Code', ui-monospace, Consolas, monospace`
with `letter-spacing: 0.01em` and antialiasing, exactly as
`ClaudeVoice/frontend/src/index.css` declares it.

### 1b — Token mapping (normative; every row must land)

Three-layer depth: page = `--gvx-bg-dim`, card = `--gvx-bg`, border/hover =
`--gvx-bg-soft`.

| Surface | Today | Becomes |
|---|---|---|
| `body` background / color | `#fafafa` / `#333` | `var(--gvx-bg-dim)` / `var(--gvx-fg)` |
| `.left-rail` bg / border-right | `#f0f0f0` / `#ddd` | `var(--gvx-bg)` / `1px solid var(--gvx-bg-soft)` |
| `.header` bg / border-bottom | `#fff` / `#ddd` | `var(--gvx-bg)` / `var(--gvx-bg-soft)` |
| `.bundle-item` border-bottom | `#e0e0e0` | `var(--gvx-bg-soft)` |
| `.bundle-item:hover` | `#e8e8e8` | `var(--gvx-bg-soft)` |
| `.bundle-item.active` bg / left border | `#e3f2fd` / `#2196f3` | `var(--gvx-bg-soft)` / `3px solid var(--gvx-blue)` |
| `.bundle-section-header` bg / color | `#e0e0e0` / `#333` | `var(--gvx-bg-dim)` / `var(--gvx-gray)` |
| `.bundle-desc`, `.tab-button`, `label .desc`, `.output-label` muted text | `#666` | `var(--gvx-gray)` |
| `.no-functions`, empty-state hints, "No output", inline `#999` sites | `#999` | `var(--gvx-gray)` |
| `.status-pass` | `#4caf50` | `var(--gvx-green)` |
| `.status-fail` | `#f44336` | `var(--gvx-red)` |
| `.status-timeout` | `#ff9800` | `var(--gvx-orange)` |
| `.status-unknown` | `#9e9e9e` | `var(--gvx-gray)` |
| `.code` bg | `#eee` | `var(--gvx-bg-soft)`, radius `var(--radius-chip)` |
| `.tabs-container` bg / border | `#fff` / `#ddd` | `var(--gvx-bg)` / `var(--gvx-bg-soft)` |
| `.tab-button:hover` | `#f5f5f5` | `var(--gvx-bg-soft)` |
| `.tab-button.active` color / underline | `#2196f3` | `var(--gvx-blue)` |
| `.form-pane` bg / border-right | `#fff` / `#ddd` | `var(--gvx-bg)` / `var(--gvx-bg-soft)` |
| `.output-pane` bg | `#f9f9f9` | `var(--gvx-bg-dim)` |
| inputs / textarea bg, color, border | — / — / `#ddd` | `var(--gvx-bg)` / `var(--gvx-fg)` / `var(--gvx-bg-soft)`, radius `var(--radius-chip)` |
| input focus border | `#2196f3` | `var(--gvx-blue)`; **plus** global `:focus-visible { outline: 2px solid var(--gvx-yellow); outline-offset: 2px; }` |
| `.submit-btn` | `#2196f3` bg / `#fff` text / 4px radius | pill: `var(--gvx-blue)` bg, `var(--gvx-bg)` text, `var(--radius-pill)`, `font-weight: 600` |
| `.submit-btn:hover` | `#1976d2` | `filter: brightness(1.08)` (ClaudeVoice pills carry no hover recolor) |
| `.submit-btn:disabled` | `#ccc` | `var(--gvx-gray)` bg, `var(--gvx-bg)` text |
| `.copy-btn` / `:hover` | `#4caf50` / `#45a049` | pill: `var(--gvx-green)` bg, `var(--gvx-bg)` text, `var(--radius-pill)`; hover `filter: brightness(1.08)` |
| `.copy-feedback` bg / border / color | `#e8f5e9` / `#4caf50` / `#2e7d32` | chip: `var(--gvx-bg)` / `1px solid var(--gvx-green)` / `var(--gvx-green)`, `var(--radius-chip)` |
| `.comment-box` border / **font** | `#ddd` / **`sans-serif`** | `var(--gvx-bg-soft)`, bg `var(--gvx-bg)`, color `var(--gvx-fg)`, **`font: inherit`** (per OQ1(a)) |
| `.excerpt-pane` bg / border | `#f5f5f5` / `#ddd` | `var(--gvx-bg-dim)` / `var(--gvx-bg-soft)`, radius `var(--radius-chip)` |
| `.banner` bg | `#f5f5f5` | `var(--gvx-bg)` |
| `.banner-timeout` border / color | `#ff9800` / `#e65100` | `var(--gvx-orange)` / `var(--gvx-orange)` |
| `.banner-truncated` border / color | `#2196f3` / `#0d47a1` | `var(--gvx-blue)` / `var(--gvx-blue)` |
| Cell container border / radius | `#ddd` / 4px | `var(--gvx-bg-soft)` / `var(--radius-card)`, `box-shadow: 0 4px 16px rgba(0,0,0,0.4)` |
| Cell header bg / border | `#f5f5f5` / `#ddd` | `var(--gvx-bg-soft)` / `var(--gvx-bg-soft)` |
| Cell body bg | `#fff` | `var(--gvx-bg)` |
| Cell "Edit" button | `#2196f3` / `#fff` | `var(--gvx-blue)` bg, `var(--gvx-bg)` text, `var(--radius-chip)` |
| Cell "Collapse/Expand" button | `#666` / `#fff` | ghost: transparent bg, `1px solid var(--gvx-gray)`, `var(--gvx-fg)` text, `var(--radius-chip)` |
| Cell "Remove" button | `#f44336` / `#fff` | `var(--gvx-red)` bg, `var(--gvx-bg)` text, `var(--radius-chip)` |
| Cell "Copy Feedback" button | `#4caf50` / `#fff` | `var(--gvx-green)` bg, `var(--gvx-bg)` text, `var(--radius-pill)` |
| stdout block bg / border | `#fafafa` / `#ddd` | `var(--gvx-bg-dim)` / `var(--gvx-bg-soft)` |
| stderr block bg / border / color | `#ffebee` / `#ef5350` / `#c62828` | `var(--gvx-bg-dim)` / `var(--gvx-red)` / `var(--gvx-red)` |
| "fresh process" notice bg / border / heading / body | `#e8f5e9` / `#4caf50` / `#2e7d32` / `#558b2f` | `var(--gvx-bg)` / `1px solid var(--gvx-green)` / `var(--gvx-green)` / `var(--gvx-fg)` |
| Disabled-function notice color / bg | `#f44336` / `#ffebee` | `var(--gvx-red)` / `var(--gvx-bg)` with `1px solid var(--gvx-red)` |
| Error text (4 inline sites) | `#f44336` | `var(--gvx-red)` |
| Excerpt line numbers | `#999` | `var(--gvx-gray)` |
| Headings (`h2`/`h3`, inline `#333` labels) | `#333` | `var(--gvx-fg)` |

Typography (OQ1(a) — all-monospace, exact mimicry): the stack is declared
**once** on `body` and everything inherits. Concretely: `body`'s
`system-ui, -apple-system, sans-serif` is replaced by the ClaudeVoice stack;
`.comment-box`'s explicit `font-family: sans-serif` becomes `font: inherit`;
and the four rules that already say `font-family: monospace` (`.code`,
`.output-pane`, `.excerpt-pane`, the input/textarea rule) drop the bare
`monospace` keyword in favour of inheriting the same token stack, so the page
resolves to one font everywhere rather than two near-identical ones. No
surface keeps a sans-serif face. `font-weight: 500` declarations stay as they
are except on the two pill buttons, which take `600` per ClaudeVoice.

Spacing: replace every `rem` length with its exact `--space-*` equivalent
(`0.25rem`→`--space-1`, `0.5rem`→`--space-2`, `0.75rem`→`--space-3`,
`1rem`→`--space-4`, `1.5rem`→`--space-6`) — a pure rename, geometry unchanged.
Three off-scale values are documented deviations: `.empty-state`'s `2rem`
padding stays a literal (ClaudeVoice mints no 32px token), and `.code`'s
`0.2rem 0.4rem` snaps to `var(--space-1) var(--space-2)`.

Motion: wrap `.spinner`'s `animation` in
`@media (prefers-reduced-motion: no-preference)`, leaving `@keyframes spin`
declared unconditionally, exactly as ClaudeVoice structures its gated block.

### 1c — Hard prohibitions

- No change to any element id, class name, `data-*` attribute, tag, or nesting.
- No change to any rendered text string.
- No change to any JS statement, control flow, `fetch` call, event listener, or
  polling interval. The only permitted edits inside the module script are the
  **contents of `style="…"` attribute values** in template literals.
- No new `<script>` or `<link>` element. No external URL of any kind.
- No new file, no asset, no favicon, no branding.
- No edit to `CONTEXT.md`, `.claude/wiki/`, `README.md`, `CHANGELOG.md`,
  `package.json`, `.claude-plugin/plugin.json`, `tests/`, `hooks/`, or any
  other `bin/microworld-dashboard/*.js` file.

### Acceptance criteria

Run every command from the repo root. Baselines in Context were measured
2026-08-11 and must be re-measured before claiming a delta.

1. **Merge gate green.** `bash tests/validate.sh` exits 0. (Baseline: 0. This
   subsumes all six `dashboard-*.test.js` suites wherever they live, so it
   survives silo Step 2's relocation.)

2. **No legacy palette survives — exhaustive negative.** The set of distinct
   hex literals in the file equals exactly the 13 Gruvbox tokens:
   ```
   diff <(grep -o '#[0-9a-fA-F]\{3,6\}' bin/microworld-dashboard/index.html \
          | tr 'A-F' 'a-f' | sort -u) \
        <(printf '%s\n' '#1d2021' '#282828' '#32302f' '#7daea3' '#89b482' \
          '#928374' '#a9b665' '#d3869b' '#d4be98' '#d8a657' '#ddc7a1' \
          '#e78a4e' '#ea6962' | sort -u)
   ```
   exits 0. (Baseline: 29 distinct hexes, zero of them Gruvbox → currently
   RED. This is the criterion that cannot pass while any of the 36 inline
   attributes is unconverted.)

3. **All 13 tokens are declared and consumed.**
   `grep -c 'var(--gvx-' bin/microworld-dashboard/index.html` ≥ 40, and for
   each of the 13 token names, `grep -q -- '--gvx-<name>:' <file>` succeeds.
   (Baseline: `grep -c 'gvx-'` = 0 → currently RED.)

4. **DOM contract intact — no id/class/data-attribute changed.** The token
   list below must all be present; the check exits 0 with `missing=0`. Verified
   green on the current file and **proved non-vacuous by mutation**
   (renaming `status-timeout`→`status-timedout` and `id="outputPane"`→
   `id="outPane"` in a scratch copy produced `missing=2`, exit 1).
   ```
   while read -r tok; do
     [ -z "$tok" ] && continue
     grep -qF -- "$tok" bin/microworld-dashboard/index.html || \
       { echo "MISSING: $tok"; missing=1; }
   done < docs/plans/assets/dashboard-dom-contract.txt; test -z "$missing"
   ```
   Token list (inline it in the check if the asset file is not created):
   `id="leftRail"`, `id="contentArea"`, `id="excerptContainer"`,
   `id="excerptPane"`, `id="commentBox"`, `id="copyFeedbackBtn"`,
   `id="copyFeedback"`, `id="clipboardFallback"`, `id="inputForm"`,
   `id="outputPane"`, `cell-comment-`, `cell-copy-feedback-`,
   `cell-clipboard-fallback-`, `bundle-item`, `bundle-section-header`,
   `bundle-title`, `bundle-desc`, `status-indicator`, `status-pass`,
   `status-fail`, `status-timeout`, `status-unknown`, `tabs-container`,
   `tab-button`, `form-and-output`, `form-pane`, `output-pane`, `form-group`,
   `output-label`, `banner-timeout`, `banner-truncated`, `exit-code`,
   `no-functions`, `empty-state`, `empty-state-text`, `excerpt-pane`,
   `excerpt-line`, `comment-section`, `comment-box`, `copy-feedback`,
   `hidden-textarea`, `submit-btn`, `copy-btn`, `cell-edit-btn`,
   `cell-toggle-btn`, `cell-copy-btn`, `cell-remove-btn`, `data-bundle-id`,
   `data-group-name`, `data-fn-id`, `data-cell-id`, `left-rail`,
   `main-content`, `content-area`, `spinner`.

5. **JS behavior byte-identical outside `style` attributes.** Every changed
   line in the diff must lie inside a `style="…"` attribute value or inside the
   `<style>` block. Machine check:
   ```
   git diff -U0 "$BASE"..HEAD -- bin/microworld-dashboard/index.html \
     | grep -E '^[+-]' | grep -vE '^(\+\+\+|---)' \
     | grep -vcE '(style=|--gvx-|--space-|--radius-|^[+-] *[.#a-z:@*{} ].*[:{}])'
   ```
   → `0`. Any non-zero result names a line the reviewer must read individually
   and justify, and an unjustified one is a FAIL.

6. **No network asset introduced.**
   `grep -cE '(src|href)="(https?:)?//' bin/microworld-dashboard/index.html`
   → `0`, and `dashboard-client.test.js` Test (c) passes inside Criterion 1.

7. **Client script still extractable by the test harness.**
   ```
   node -e "const h=require('fs').readFileSync('bin/microworld-dashboard/index.html','utf8');
   const m=h.match(/<script type=\"module\">([\s\S]*?)<\/script>/);
   if(!m||m[1].length<20000) process.exit(1);"
   ```
   exits 0. (Guards constraint 3: a stray `</script>` or a new module block
   would silently truncate what every client test executes.)

8. **End-to-end serve + CLI smoke.**
   ```
   timeout 10s node bin/cli.js --dashboard --dashboard-port=0 > /tmp/dash.log 2>&1
   grep -qE 'http://127\.0\.0\.1:[0-9]+/\?t=[0-9a-f]{16,}' /tmp/dash.log
   ```
   the `grep` exits 0. (`timeout` yields rc 124 by design; the grep is the
   assertion. Verified working today.) Additionally, a `GET /` against a
   started server returns HTTP 200 with a body containing `--gvx-bg:` — this
   proves the feedback-block string replacement still lands after the edit.

9. **No sans-serif face survives — all-monospace, per OQ1(a).**
   `grep -cE 'sans-serif|system-ui' bin/microworld-dashboard/index.html` → `0`
   and the monospace stack is declared exactly once:
   `grep -c "'JetBrains Mono'" bin/microworld-dashboard/index.html` → `1`.
   Baselines re-measured 2026-08-11: **2** and **0** respectively → both
   currently RED. (Note `grep -c` counts matching *lines*, not matches: the
   two lines are `body`'s `system-ui, -apple-system, sans-serif` — which alone
   carries two of the three occurrences — and `.comment-box`'s `sans-serif`.
   An earlier draft of this criterion misstated the line baseline as 3 by
   conflating `-c` with `-o`; corrected here.)

10. **Visual fidelity — NOT MECHANIZABLE, human check, does NOT gate PASS.**
    No command can decide whether the page reads as ClaudeVoice's design
    system. Stated plainly rather than gated behind a proxy grep. Per OQ3(a):
    **the reviewer PASSes on Criteria 1–9 and must state in its verdict that
    appearance was not verified**, rather than implying it was. The owner then
    runs the check post-PASS: `node bin/cli.js --dashboard`, open the URL,
    select a bundle, invoke a function, and confirm by eye that (i) no
    light-colored patch remains in any surface — including the error, empty,
    disabled and Escalation-Packet branches; (ii) text is legible on every
    background; (iii) the page reads as one consistent dark monospace surface.
    A defect found here opens a fast follow-up unit; it never retroactively
    invalidates this unit's PASS.

---

## Open Questions — ALL RESOLVED 2026-08-11

**None outstanding.** All four were put to the owner and answered with the
recommended default. The options are retained below **verbatim as asked**, as
the decision record, so a future reader can see what was considered and
rejected, not just what won. Note the criterion numbers *inside* the retained
OQ3 text are pre-finalization: answering OQ1 added a new Criterion 9
(all-monospace), pushing the visual check from 9 to 10. The authoritative
numbering is the Acceptance criteria list above.

- **OQ1 → (a) all-monospace, exact mimicry.** Landed in §1b's typography
  paragraph and gated by Criterion 9.
- **OQ2 → (a) dark-only, no toggle.** Landed throughout §1b; no light branch
  is authored, and Criterion 2's 13-hex allowlist makes a second palette
  impossible to add without failing.
- **OQ3 → (a) reviewer PASSes on Criteria 1–9; the owner's visual check is
  post-PASS** and a defect there becomes a fast follow-up unit. Landed as
  Criterion 10.
- **OQ4 → (a) dispatch now, in parallel with #328–#332.** #327's PASS marker
  is on disk, so nothing blocks it (R3 discharged).

**OQ1 — Typography reach: how far does the monospace stack go?**
ClaudeVoice makes its *entire* UI monospace — headings, labels, prose, buttons,
everything — deliberately, so the chrome around its terminal reads as one
surface. The dashboard today is `system-ui` sans for chrome with monospace only
for code/output. Faithful mimicry means all-monospace, which visibly changes
the feel of the rail, header, form labels and prose.
- (a) **Recommended — all-monospace**, exactly as ClaudeVoice: one `font-family`
  on `body`, everything inherits. Highest fidelity; the dashboard is a
  developer tool showing code and shell output, so it suits the content.
- (b) Monospace only for code/output/inputs; keep a sans stack for chrome and
  prose. Lower fidelity, more conventional readability for the rail and prose.

**OQ2 — Theme scope: dark-only, or add a light mode?**
ClaudeVoice has **no** light theme — `color-scheme: dark`, no toggle, no
media-query branch. The dashboard today is light-only. Mimicry therefore
*inverts* the dashboard's current appearance.
- (a) **Recommended — dark-only, no toggle**, matching ClaudeVoice exactly.
  Simplest, highest fidelity, one palette to maintain.
- (b) Dark by default plus a `prefers-color-scheme: light` branch. Doubles the
  token surface, has no ClaudeVoice counterpart to copy from, and would require
  inventing a light palette — real added scope.
- (c) Dark-only plus an in-page toggle. Requires new DOM and new JS, which the
  request puts out of scope.

**OQ3 — Completion signal: does the human visual check block PASS?**
Criterion 9 is genuinely not mechanizable. Criteria 1–8 are all real pass/fail
commands, but none of them proves the page *looks* right.
- (a) **Recommended — reviewer PASSes on Criteria 1–8**; Criterion 9 is run by
  the owner as an explicit, recorded post-PASS visual confirmation, and a
  defect found there opens a follow-up unit. Keeps the reviewer's verdict
  mechanical and honest about what it did and did not verify.
- (b) Reviewer must escalate (`ESCALATE-TO-HUMAN`) so the owner's visual
  sign-off gates the marker, via the human-review channel. Slower, but no
  restyle lands unseen.
- (c) Reviewer performs the visual check itself. Not recommended — the reviewer
  cannot see rendered pixels, so this would be sign-off on a claim it cannot
  actually verify.

**OQ4 — Sequencing against the in-flight `microworld-silo` plan.**
*(Asked while unit #327 — the `bin/dashboard` → `bin/microworld-dashboard`
rename this plan depends on — was still `ESCALATE-TO-HUMAN`. It has since been
approved and its PASS marker written, so option (c)'s stated risk is moot.)*
- (a) **Recommended — dispatch this restyle after #327's decision lands, in
  parallel with #328–#332.** There is no file collision: this unit touches only
  `bin/microworld-dashboard/index.html`, which no remaining silo step touches,
  and every criterion here is worded to survive the test relocation.
- (b) Queue the restyle behind the entire silo plan (#332). Safest ordering,
  but serialises unrelated work for no measured benefit.
- (c) Dispatch immediately, before #327 is approved. Not recommended — if the
  rename is rejected, every path in this plan is wrong.

---

## Self-check

- CHK1: Is "mimic ClaudeVoice's styling" defined concretely enough that two
  implementers would produce the same file? — PASS (Clarifications enumerate
  the four adopted artifacts and the excluded ones; §1b is a normative,
  row-by-row mapping table).
- CHK2: Does the plan state what happens to the 36 inline `style` attributes
  inside JS template literals? — FAIL (missing, in the first draft) — revised
  in place: added the token-swap-in-place decision, Constraint/Context finding,
  §1c prohibition, and Criteria 2 and 5.
- CHK3: Do the Context surface inventory (26 rows) and the §1b mapping table
  agree — is every enumerated surface actually mapped? — PASS (each of the 26
  surfaces appears in §1b; the spinner appears under the motion paragraph).
- CHK4: Is every acceptance criterion something an agent can run and get
  pass/fail from? — PASS for Criteria 1–9 (each was executed against the
  current tree before being written); Criterion 10 is explicitly declared
  non-mechanizable rather than dressed up as a gate.
- CHK5: Is at least one criterion proved non-vacuous, per this repo's repeated
  failure mode? — PASS (Criterion 4 was mutation-tested: `missing=0` on the
  real file, `missing=2` on a mutated copy; Criteria 2 and 3 are RED against
  the current tree by construction, since the file has 0 `gvx-` occurrences and
  29 non-Gruvbox hexes).
- CHK6: Do the "no build tooling" constraint and the "adopt ClaudeVoice's
  design tokens" goal contradict each other? — PASS (Context establishes that
  ClaudeVoice's styling is plain CSS carrying no framework dependency, so both
  hold simultaneously; stated explicitly in Constraint 1).
- CHK7: Is the dark/light theme question decided anywhere in the plan without
  the owner? — FAIL (ambiguous, in the first draft — the mapping table assumed
  dark) — converted to Open Question 2; **OQ2 answered 2026-08-11 (dark-only,
  no toggle)**, so the mapping table's assumption is now the owner's decision
  rather than mine.
- CHK8: Is the completion signal for a purely visual change defined? — FAIL
  (missing) — converted to Open Question 3; **OQ3 answered 2026-08-11**, and
  the answer is now written into Criterion 10 (reviewer PASSes on 1–9 and must
  say appearance was unverified; owner checks post-PASS).
- CHK13 (added on finalization): Now that OQ1 mandates all-monospace, does the
  plan actually say what happens to the four rules that already declare
  `font-family: monospace` and the one that declares `sans-serif`? — FAIL
  (missing) — revised in place: §1b gained a typography paragraph naming all
  five, and Criterion 9 gates the outcome (baseline 2 sans/system-ui *lines*
  → must reach 0, so it is RED today and non-vacuous).
- CHK14 (added on finalization): Do the Open Questions section, the
  Clarifications log, Criterion 10 and the dispatch contract all agree on
  whether the visual check gates PASS? — PASS (all four state: it does not;
  reviewer PASSes on 1–9, owner checks post-PASS, defect becomes a follow-up
  unit).
- CHK9: Does the plan say which paths are current, given the mid-flight
  rename? — PASS (Constraint 9 and every path use
  `bin/microworld-dashboard/`; the old path appears nowhere as a target).
- CHK10: Do Criterion 1 and Risk R2 agree about which test paths are named? —
  PASS (no criterion names an individual test file; Criterion 1 delegates to
  `tests/validate.sh`).
- CHK11: Does the plan state whether a version bump / CHANGELOG entry is
  required, and does that agree with the Constitution check? — PASS (R6 and
  Constitution P3 both say no, for the same stated reason, and both name silo
  Step 6 as the owner of the CHANGELOG edit).
- CHK12: Is the prior-defect history for this area recorded rather than
  assumed? — PASS (R4; the reviewed-marker directory was enumerated in full,
  not sampled — no styling `.fail` exists, and the two adjacent FAILs and their
  shared cause are named).

---

## Further Notes

### Ubiquitous-language check (prose mode, advisory — never gates)

Glossary: `CONTEXT.md` (present). Read once and reused across both check points.

- **Lens 1 — a glossary term used with a different meaning:** nothing found.
  "Microworld dashboard" is used throughout in `CONTEXT.md`'s sense (the
  server/UI process as a whole); "function entry" and the check's
  `pass`/`fail`/`timeout` result vocabulary are used canonically.
- **Lens 2 — a new synonym for an already-defined term:** one mild finding.
  The request's "code/JSON display areas" and this plan's "output pane"
  describe the region `CONTEXT.md` defines as holding ephemeral **Cell**s.
  Canonical term: **Cell**. Mitigated by using "Cell" for the unit of
  execution history and reserving "output pane" for the literal
  `.output-pane` CSS selector it names (surfaces 15–16).
- **Lens 3 — a load-bearing new domain term with no glossary entry:** one
  suggestion for `scribe`. This plan introduces **design token** (`--gvx-*`,
  `--space-*`, `--radius-*`) as a named concept with a cross-project
  provenance (`ClaudeVoice/frontend/src/theme/gruvbox.ts` is the upstream
  source of truth for the 13 hexes). If the restyle lands, a one-line
  `CONTEXT.md` entry recording that provenance would prevent a future agent
  "correcting" the palette to something locally invented.

### Stale-path note (not this unit's work)

`CONTEXT.md:102` still names `bin/dashboard/audit-log.js` as a consumed
interface. Already inventoried by #327's review and sequenced to silo Step 5
(#330). Recorded here only so it is not mistaken for a defect this unit
introduced.

---

## Scribe update hint

If this lands: no wiki or `CONTEXT.md` update is required for behavior (none
changed). The one entry worth considering is the Lens-3 suggestion above — a
line under the **Microworld dashboard** glossary entry recording that the
dashboard's palette is the Gruvbox Material Dark token set adopted from
`ClaudeVoice/frontend/src/theme/gruvbox.ts`, so the hex values have an
upstream source of truth rather than looking arbitrary. Defer to silo Step 5
(#330) if that unit is still open, to avoid two units editing `CONTEXT.md`.

---

## Dispatch contract (fast path — 1 unit)

**Encodes the owner's answers to OQ1–OQ4, all recommended defaults, confirmed
2026-08-11. Ready to dispatch.**

**Unit: `adhoc-2026-08-11-dashboard-gvx-restyle`**
Suggested model: **not `haiku`** — 36 inline attributes across four render
functions plus a 57-line stylesheet, with an exhaustive-negative criterion and
a documented area FAIL history (R4).

### Objective
Restyle `bin/microworld-dashboard/index.html` to the Gruvbox Material Dark
token system adopted from `ClaudeVoice/frontend`, changing colors, type,
spacing, radii and component chrome only — no layout, no DOM, no JS behavior.

### Retrieval
The canonical spec is
`docs/plans/2026-08-11-microworld-dashboard-gvx-restyle.md` (authoritative) —
read §Context, Step 1a–1c and the Acceptance criteria in full before editing.
A PRD view of the same spec is published as **issue #333** in
`Storreslara/AntiSlop` (`ready-for-agent`); fetch it with
`gh issue view 333`. On any disagreement the plan document wins. The upstream
style reference is `/home/sebas/ClaudeVoice/frontend/src/index.css`,
`src/App.css` and `src/theme/gruvbox.ts` (read-only; never modify that repo).

### Affected files
- `bin/microworld-dashboard/index.html` — sole file modified.

### Ordered edits
1. Insert the `:root` token block (13 `--gvx-*`, 5 `--space-*`, 3 `--radius-*`)
   at the top of the existing `<style>` block; set `color-scheme: dark`, the
   monospace stack, `letter-spacing: 0.01em`, antialiasing on `body`.
2. Rewrite every rule in the `<style>` block per the §1b mapping table.
3. Add `:focus-visible { outline: 2px solid var(--gvx-yellow); outline-offset:
   2px; }` and gate `.spinner`'s `animation` behind
   `@media (prefers-reduced-motion: no-preference)`.
4. Walk the module script top to bottom and convert all 36 inline `style="…"`
   attribute values to `var(--gvx-…)` / `var(--space-…)` / `var(--radius-…)`
   per §1b. Change nothing else on those lines.
5. Re-run Criterion 2 after step 4; a non-empty `diff` names exactly the hexes
   still to convert. Iterate until it is empty.
6. Run Criteria 1, 3–8 in order.

### Do NOT touch
`CONTEXT.md`, `.claude/wiki/`, `README.md`, `CHANGELOG.md`, `package.json`,
`.claude-plugin/plugin.json`, `tests/**`, `hooks/**`, `adapters/**`,
`docs/**` (other than reading this plan), any other file under
`bin/microworld-dashboard/`, and the entire `/home/sebas/ClaudeVoice` tree.
No new file, no favicon, no asset, no `<script>`, no `<link>`, no external URL.
No version bump and no CHANGELOG entry (Constitution P3 does not fire; silo
Step 6 / #332 owns those).

### Acceptance criteria
Criteria 1–10 of Step 1, verbatim. Criteria 1–9 are runnable and gate the
verdict; Criterion 10 is explicitly non-mechanizable and, per OQ3(a), is the
owner's post-PASS visual confirmation rather than a reviewer gate — the
reviewer must say so plainly in its verdict rather than implying it checked
appearance.

### Pre-resolved context
Do not re-derive these; they were measured 2026-08-11 (re-verify only a
specific claim you doubt):
- Blast radius is one file. No other file in the repo references the
  dashboard's CSS classes; no test asserts any CSS, class, or color (only two
  `style: {}` DOM stubs at `tests/dashboard-feedback.test.js:658,667`).
- `tests/dashboard-client.test.js:41` / `dashboard-notebook.test.js:74`
  extract the client with a non-greedy `<script type="module">…</script>`
  regex — do not add a script block or an unescaped `</script>`.
- `server.js` sends no CSP, so inline styles keep working; its `GET /` handler
  string-replaces `/* __FEEDBACK_BLOCK_SOURCE__ */`, which must survive.
- Today's `rem` values map 1:1 onto ClaudeVoice's 4/8/12/16/24px scale, so
  adopting `--space-*` changes no geometry.
- Baselines: `validate.sh` exit 0; `grep -c 'gvx-'` = 0; 29 distinct hexes /
  90 occurrences; 36 inline `style="`; module script 28760 chars; 2 lines
  carrying `sans-serif`/`system-ui` (3 occurrences); 6 `font-family: monospace`
  occurrences; 0 `'JetBrains Mono'`.
- The `bin/microworld-dashboard/` path is settled — unit #327 PASSed and its
  marker is on disk. Do not "fix" any path to `bin/dashboard/`.

### Escalation
Stop and report rather than improvising if: (a) any acceptance criterion
cannot be made to pass without touching a file on the Do-NOT-touch list;
(b) a `<style>`-only conversion turns out to be insufficient for a surface not
listed in the 26-row inventory (report the surface, do not restructure the
DOM); (c) satisfying Criterion 2's 13-hex allowlist would require inventing a
colour ClaudeVoice does not define (report the surface and the need — do not
mint a 14th token); or (d) a second FAIL on this unit — which routes back to
`spec-master` for a debug spec, never a third blind fix attempt.
