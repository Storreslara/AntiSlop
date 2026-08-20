# Debug spec — dash-ux-1 Step 1, 2-FAIL-cap escalation

**Scope:** a focused root-cause diagnosis plus revised acceptance criteria for
the failed step. Not a replan. Step 1's goal and scope are unchanged — a
vendored, dependency-free, dual-environment markdown renderer, module only, no
page wiring. What changes is **how the criteria verify the escape-first
guarantee**, plus a prescribed structural design that makes that guarantee
unreachable-by-construction rather than patched case-by-case.

**Parent plan:** `docs/plans/2026-08-18-dashboard-usability-revision.md`
§ "Step 1 — `markdown-lite.js`: the vendored renderer (module only, no wiring)"
**Unit:** `dash-ux-1` · **FAIL record:** `.claude/reviewed/dash-ux-1.fail`
(2nd FAIL; the 1st was overwritten at the same path) ·
**Attempts:** `c9aae3d` (1st, haiku), `5b1e88f` (2nd, sonnet)

**Units dash-ux-2 … dash-ux-5 are untouched by this pass.**

---

## fail-triage: verify → categorize

### 1. VERIFY — confirmed, and reachable in one more context than reported

Re-run live against the tree at `5b1e88f`, not read from the record. All five
reviewer payloads reproduce exactly as recorded:

```
VULN  '**a** <img src=x onerror=alert(1)> **b**'
      -> <p><strong>a</strong> <img src=x onerror=alert(1)> <strong>b</strong></p>
VULN  '*a* <svg onload=alert(1)> *b*'
      -> <p><em>a</em> <svg onload=alert(1)> <em>b</em></p>
VULN  '`a` <img onerror=alert(1) src=q> `b`'
      -> <p><code>a</code> <img onerror=alert(1) src=q> <code>b</code></p>
VULN  '[a](http://x) <img src=q> [b](http://y)'
      -> raw <img src=q> between two live anchors
VULN  '**a** <a href=javascript:alert(1)>x **b**'
      -> <p><strong>a</strong> <a href=javascript:alert(1)>x <strong>b</strong></p>
safe  '**a** <img src=/x> **b**'      (control: the '/' condition holds)
VULN  '- **a** <img src=x> **b**'     (ul reach confirmed)
VULN  '1. **a** <img src=x> **b**'    (ol reach confirmed)
D2    '**a `<x>` b**'
      -> <p><strong>a <code>&amp;lt;x&amp;gt;</code> b</strong></p>   (double-escaped)
```

Meanwhile `node tests/dashboard-markdown-lite.test.js` exits **0** with all 30
checks green. **The suite is green and the module is exploitable** — that
disjunction is the actual finding of this triage, and it is what the revised
criteria exist to make impossible.

Measured beyond the record: a generated cross-product of 540 inputs (9 raw-HTML
fragments × 4 marker types × 3 adjacency positions × 5 block contexts) yields
**72 unsafe outputs** on the current module. So this is not a five-payload
defect; it is a broad class, and the record's five are a sample of it.

**Status: confirmed.**

### 2. CATEGORIZE — spec/criterion defect (not a plain code defect)

The normal FAIL route is "criterion right, code wrong → back to
lead-programmer." That is **not** this case, and that is precisely why two
competent attempts each landed short of the same invariant.

Step 1 carries the security property in a **prose design paragraph**, not in any
criterion:

> "There is no sanitize pass and none is needed: raw inline HTML in the source
> can never reach the page as markup because it is escaped before any tag is
> emitted."

That sentence states a *whole-module invariant*. The criteria that were supposed
to enforce it (U1-C3, U1-C4) test **instances**:

- **U1-C3** enumerates one XSS case, `renderMarkdown('<img src=x onerror=alert(1)>')`
  — a bare fragment with no adjacent markers. That input never enters the
  vulnerable branch, so the criterion passes on a module that is unsafe. The
  reviewer's own control case (`<img src=/x>`, which contains a `/` and is
  therefore correctly escaped) proves the pass was luck of payload selection,
  not evidence.
- **U1-C4**'s mutation proof asked only that "the escape call" be load-bearing.
  The module had **six** `escapeHtml` call sites inside `renderInline`; mutating
  any one of them reddens the suite. So U1-C4 was satisfiable while the invariant
  was false — it proved *an* escape mattered, never that *every* text span passed
  through one.

An implementer given "escape before emitting" plus a fifteen-case list will
build to the list. Both attempts did exactly that, and both were reactive:
attempt 1 built the marker scheme; attempt 2 patched the marker scheme's entry
point. Neither was ever asked for "no code path may hold unescaped user text."

This is why the fix is a debug spec and not a third dispatch of the same
criteria.

---

## Root cause

### D1 — an unanchored split regex re-admits unescaped text

`markdown-lite.js:157-163` is the module's only escaping step for plain text on
the inline path. It escapes by *elimination*: split the string on anything that
looks like a marker, then escape only the parts that don't:

```js
result = result.split(/(\x00[^/]*\x00|\x00\/[^/]*\x00)/g).map(function(part) {
  if (part.startsWith('\x00')) {
    return part;                 // "marker" - don't escape
  }
  return escapeHtml(part);       // plain text - escape it
}).join('');
```

Alternative 1, `\x00[^/]*\x00`, is **not anchored to a marker vocabulary**.
`[^/]*` excludes exactly one character — the slash — so a single match may begin
at the *closing* NUL of one marker, run straight across the intervening
still-unescaped plain text, and terminate at a NUL belonging to the *next*
marker. The whole span then starts with `\x00`, so the `startsWith` test returns
it verbatim and it is never escaped.

Trigger: raw HTML between two inline markers on the same line, containing no `/`.
Void tags and attribute-only payloads satisfy that for free — no NUL byte
anywhere in the input, which is why `:39`'s NUL strip (attempt 2's fix) does not
defend against it.

**The generalizable shape: escaping-by-elimination is a blocklist.** It asks
"which parts are *not* text?" and escapes the remainder. Every such scheme is one
classification error away from emitting raw input, and the classifier here is a
regex over a delimiter the input can also contain. Attempt 1 put the hole in the
classifier's input (forged NUL); attempt 2 sealed the input and left the hole in
the classifier itself. A third patch to that regex would move the hole again —
the reviewer's warning that it "is likely to leave a fourth hole" is correct, and
this spec does not take that route.

### D2 — the same scheme double-escapes nested spans

`:135-155` escapes each construct's content as it substitutes markers, and then
`:158-163` escapes again anything the split fails to recognise as a marker. Where
both fire, `escapeHtml` re-escapes the `&` it introduced on the first pass:

```
renderMarkdown('**a `<x>` b**')
  -> <p><strong>a <code>&amp;lt;x&amp;gt;</code> b</strong></p>
     (the reader sees the literal text "&lt;x&gt;", not "<x>")
```

Measured, second instance not in the FAIL record — the same defect on an
attribute:

```
renderMarkdown('[a](http://x?a=1&b=2)')
  -> href="http://x?a=1&amp;amp;b=2"      (should be &amp;)
```

D1 and D2 are one root cause seen from two sides: **escaping happens in more than
one place, and no single place owns it.** With N escape sites, every text span is
escaped 0, 1, or 2 times, and the scheme's job is to guess which — 0 is D1, 2 is
D2.

### The prescribed fix: one escape, first, on everything

Escape the **entire line once**, as the first statement of `renderInline`, and
then run the inline-formatting regexes against the **already-escaped** text,
emitting tags around escaped spans. Delete the marker/sentinel scheme entirely.

```
renderInline(text):
    result = escapeHtml(text)          # the ONLY escape on this path
    result = result.replace(code   -> '<code>'   + $1 + '</code>')
    result = result.replace(link   -> allowlisted ? '<a href="'+$2+'" rel=... >'+$1+'</a>' : $1)
    result = result.replace(bold   -> '<strong>' + $1 + '</strong>')
    result = result.replace(italic -> '<em>'     + $1 + '</em>')
    return result
```

Why this closes the class rather than patching it: after statement one, **no
variable in the function holds unescaped user text**, so there is no span left
for a classifier to misclassify. The later `replace` calls only *add*
renderer-generated tags; they never re-examine the text/markup boundary. The
invariant stops depending on a regex being right and becomes a property of
control flow — which is what "unreachable by construction" means here, and it is
the reason a *count* of escape sites (U1-C6) is a meaningful criterion at all.

Two consequences worth stating, both measured on a prototype rather than assumed:

- **The reviewer's D2 claim is true of this design.** `**a `<x>` b**` renders
  `<code>&lt;x&gt;</code>`, and `[a](http://x?a=1&b=2)` renders
  `href="http://x?a=1&amp;b=2"`. Both correct, single-escaped. Verified, not
  asserted.
- **The NUL machinery becomes dead and must go.** With no sentinels, the three
  FAIL-1 forged-marker payloads are safe *purely by escaping*, with the `:39`
  strip deleted — verified on the prototype. That is the strongest available
  evidence that the fix is structural: the forgery class is closed because there
  is nothing left to forge, not because the input is filtered. U1-C7 pins this.

Ordering is prescribed (code → link → bold → italic) because it is the order the
prototype was verified in; the link regex must run on escaped text so its `href`
lands in the attribute already escaped.

**Accepted, documented consequence:** with `:39` deleted, a literal U+0000 in the
input now passes through into the output as text. This is safe — it is inert text
in an escaped span, and the HTML parser maps NUL in character data to U+FFFD —
and it is not a regression the reviewer should FAIL on. It is recorded here so it
is a decision on the record rather than an unexplained behaviour change.

### Scope note — defects deliberately NOT addressed

`.claude/reviewed/dash-ux-1.fail`'s N1-N5 (heading level clamp, protocol-relative
`//evil.test/x` hrefs, the `:30` comment, `----` hr matching, blockquotes not
calling `renderInline`) are non-blocking and stay non-blocking. They are named
here only so the implementer does not treat them as in scope. **N5 carries an
active trap:** blockquote text is escaped at `:85` and does not route through
`renderInline`; routing it there to "fix" the inconsistency would double-escape
it and reintroduce D2. Do not.

---

## Clarifications

1. Functional scope & success criteria: Partial
2. Domain entities / data model: Clear
3. User interaction flow: Clear
4. Non-functional attributes (perf, security, scale): Partial
5. External dependencies & integrations: Clear
6. Edge cases / failure handling: Missing
7. Technical constraints & tradeoffs: Partial
8. Terminology consistency: Clear
9. Completion / acceptance signals: Partial

- 2026-08-18 Functional scope & success criteria: Q Does this debug spec revise
  only the two criteria the reviewer named (U1-C3, U1-C4), or the design as well?
  → A (self-resolved): the design as well. Revising criteria alone would leave a
  third attempt free to patch the split regex a third time and satisfy any
  case-list I write; the escalation instruction requires the invariant be
  structurally true. U1-C1/C2/C5 are untouched and must stay green.
- 2026-08-18 Non-functional attributes (security): Q What exactly is the security
  property, stated so it is falsifiable? → A (self-resolved): "every `<` and `>`
  in the output belongs to a tag from the renderer's own fixed vocabulary, and no
  emitted anchor carries a non-allowlisted scheme." The parent plan's phrasing
  ("can never reach the page as markup") is unfalsifiable prose and is exactly
  what two attempts satisfied on paper while failing in fact.
- 2026-08-18 Edge cases / failure handling: Q Which input shapes must be
  enumerated, given the five in the record are a sample of a class? → A
  (self-resolved): the five verbatim, in all three block contexts the reviewer
  verified, *plus* a generated cross-product (U1-C4) so the criterion is not
  defeatable by handling exactly the listed five. Measured: the class is 72 cases
  out of 540 on the current module, so a five-case list under-covers it by an
  order of magnitude.
- 2026-08-18 Technical constraints & tradeoffs: Q Escape-first, or anchor the
  split regex to an explicit marker vocabulary (the reviewer's fallback)? → A
  (self-resolved): escape-first, and the fallback is explicitly rejected. Anchoring
  the vocabulary fixes D1 but leaves D2 standing (two escape sites remain), keeps
  the forgery surface alive, and keeps the invariant dependent on a regex
  remaining correct under future edits. Escape-first removes the classifier
  outright and is the only one of the two that makes U1-C6 expressible.
- 2026-08-18 Completion / acceptance signals: Q What criterion would have caught
  both prior attempts? → A (self-resolved): U1-C4 (the property test) fails
  attempt 2 at 72 of 540 generated cases and fails attempt 1 likewise; U1-C6
  (exactly one escape site) fails both by inspection, 6 sites measured today.
  The original U1-C4 mutation proof could not, because six escape sites meant any
  single mutation reddened the suite regardless of the invariant.

**Terminology (`ubiquitous-language`, prose mode, advisory, non-blocking):**
Lens 1 — no glossary term used divergently; `document pane`, `verbatim pane` and
`mutation proof` are used as the parent plan and `CONTEXT.md` use them. Lens 2 —
no new synonym introduced; this spec says "escape-first" throughout, matching the
parent plan's Step 1 design paragraph, and does not introduce a rival term such
as "sanitize". Lens 3 — **escaping by elimination** is a load-bearing new
defect-class term with no `CONTEXT.md` entry; suggested for `scribe` below,
alongside the existing **JSON type confusion** entry (`CONTEXT.md:574`), which it
sits beside as a second worked instance of "a validator that classifies instead
of failing closed".

## Constitution check (.claude/constitution.md v1.0.0)

- P1 "Verify, don't assume": satisfied — every claim above was re-measured live
  against `5b1e88f`: the five payloads, the ul/ol reach, the `/` control, both D2
  instances, the 540-case cross-product, the prototype's behaviour on all of them,
  and every grep baseline quoted in the criteria. Nothing is carried over from the
  FAIL record without re-measurement.
- P2 "Prefer deterministic scripts over LLM re-derivation": satisfied — no
  script-driven file (`--wire-graph-mcp`, `fileHashes`, backfill output) is
  hand-edited; this unit touches one source module and one test file.
- P3 "Version-stamp discipline": satisfied — no `agents/*.md` and no `templates/`
  file is in this unit's diff, so no `plugin.json` bump is required by it.
- P4 "Optional personas degrade gracefully": not engaged — no shared persona prose
  is touched.
- P5 "`tests/validate.sh` is the merge gate": satisfied — U1-C5 is retained
  unchanged. Per the FAIL record's N6, `validate.sh` fails repo-wide at parent
  commit `6adb143` for pre-existing reasons (missing `yaml` module, unrelated
  `--update` drift); that pre-existing state is not attributable to this unit and
  is not a FAIL ground. The clause this unit controls is the presence of
  `OK   tests/dashboard-markdown-lite.test.js` in the output.

---

## Revised acceptance criteria

**These supersede U1-C3 and U1-C4 of the parent plan. U1-C1, U1-C2 and U1-C5
stand unchanged and must stay green.**

**The property under test, stated falsifiably:** for any input, every `<` and `>`
character in `renderMarkdown`'s output belongs to a tag the renderer itself
emitted from its fixed vocabulary, and no emitted anchor carries a
non-allowlisted scheme.

Two shared constants, defined **once** in the test file and used by U1-C3 and
U1-C4 alike. Both are given verbatim because both were measured; a looser
spelling of either silently guts the criteria (see the trap note under U1-C4):

```js
const ALLOWED_TAG = /<\/?(?:h[1-6]|p|strong|em|code|pre|ul|ol|li|blockquote)>|<hr \/>|<br \/>|<a href="[^"<>]*" rel="noopener noreferrer" target="_blank">|<\/a>/g;
const JS_HREF     = /href="\s*javascript:/i;

// unsafe(output) === true means the invariant is broken
function unsafe(out) {
  const residue = out.replace(ALLOWED_TAG, '');
  return residue.includes('<') || residue.includes('>') || JS_HREF.test(out);
}
```

### U1-C1, U1-C2 — unchanged

Verbatim from parent Step 1 and still required: `node
tests/dashboard-markdown-lite.test.js` exits 0 (U1-C1), and
`git grep -n 'require(\|document\.' bin/microworld-dashboard/markdown-lite.js`
prints no lines and exits 1 (U1-C2, module purity). Both passed at `5b1e88f` and
neither is relaxed here — the rewrite must not introduce a `require` or a
`document.` reference.

### U1-C3 (revised) — enumerated regression cases

The suite contains and passes every case below. Cases marked *(retain)* already
exist and must **not** be deleted by the rewrite.

**(a) All 15 original Step 1 cases *(retain)*** — headings, bold, italic, inline
code, fenced block, ul, blockquote, hr, paragraph, the bare-`<img` XSS case, the
`javascript:` link case, the https/relative link cases, the mixed-escape case,
and the four non-string cases. Unchanged and still passing.

**(b) The three FAIL-1 forged-sentinel payloads *(retain)*** — currently at
`tests/dashboard-markdown-lite.test.js:183-198`. These must survive the rewrite
and pass **with no NUL-stripping code anywhere in the module** (see U1-C7);
verified achievable on the prototype. Deleting them as "no longer applicable" is
a criterion failure — they are the record that the forgery class stays closed.

**(c) The five FAIL-2 adjacency payloads, each in all three reachable block
contexts** — paragraph, `- ` list item, `1. ` list item. 15 assertions, each
asserting `unsafe(output) === false`:

```
'**a** <img src=x onerror=alert(1)> **b**'
'*a* <svg onload=alert(1)> *b*'
'`a` <img onerror=alert(1) src=q> `b`'
'[a](http://x) <img src=q> [b](http://y)'
'**a** <a href=javascript:alert(1)>x **b**'
```

**(d) The `/`-containing control** — `'**a** <img src=/x> **b**'` renders
`&lt;img src=/x&gt;`. This case passes on the *current, exploitable* module too;
it is required so the suite records **why** the original U1-C3 XSS case passed,
and so a future reader cannot mistake it for coverage.

**(e) D2, both instances** — `renderMarkdown('**a `<x>` b**')` output contains
`<code>&lt;x&gt;</code>` and does **not** contain `&amp;lt;`; and
`renderMarkdown('[a](http://x?a=1&b=2)')` output contains
`href="http://x?a=1&amp;b=2"` and does **not** contain `&amp;amp;`.

### U1-C4 (revised) — the property test (the load-bearing criterion)

A generated cross-product, not a hand-written list. The test builds inputs from
four arrays declared as named constants in the test file and asserts
`unsafe(output) === false` for **every** generated case:

- `RAW_FRAGMENTS` — ≥ 8 raw-HTML fragments, which **must** include at least one
  containing `/` and one containing none, and must include
  `'<img src=x onerror=alert(1)>'`, `'<svg onload=alert(1)>'`,
  `'<a href=javascript:alert(1)>x'` and `'"><img src=x>'`.
- `MARKERS` — all four inline marker types: `'**a**'`, `'*a*'`, `` '`a`' ``,
  `'[a](http://x)'`.
- `POSITIONS` — fragment before the marker, after it, and **between two
  markers** (the position that produced this FAIL).
- `CONTEXTS` — paragraph, `- ` item, `1. ` item.

Machine-checkable shape requirements, so the criterion cannot be satisfied by a
hand-rolled list that happens to cover the named five:

1. The four constants exist by name and are iterated as a cross-product.
2. The test asserts a **minimum generated-case count of ≥ 250** (e.g.
   `assert(n >= 250, ...)`), so a generator that silently produces nothing fails.
3. Every generated case asserts via the shared `unsafe()` helper above.

**Non-vacuity, measured — do not re-derive:** this exact criterion, run against
the current module at `5b1e88f`, reports **72 unsafe cases out of 540**. It fails
loudly today. If an implementation of it reports 0 against the *unfixed* module,
the generator or the vocabulary is wrong, not the module.

**Two spelling traps, both measured — the criterion is defeated by "simplifying"
either constant:**
- Widening `ALLOWED_TAG`'s anchor clause to a generic attribute wildcard (e.g.
  `<a\s[^<>]*>`) makes it strip the injected `<a href=javascript:alert(1)>` as
  though the renderer had emitted it. Measured: the residue check then **misses**
  payload 5 entirely. The anchor alternative must keep the full literal
  `href="…" rel="noopener noreferrer" target="_blank"` shape.
- Asserting `!out.includes('javascript:')` instead of `JS_HREF` **false-positives
  on a correct fix**: the correctly-escaped rendering of payload 5 legitimately
  contains the inert text `href=javascript:` inside `&lt;a …&gt;`. Measured: the
  prescribed fix "fails" that naive assertion while being safe. The quote in
  `href="` is what distinguishes an emitted anchor from escaped text, and it is
  load-bearing.

### U1-C5 — unchanged

`bash tests/validate.sh` behaviour per the parent plan, including the
`OK   tests/dashboard-markdown-lite.test.js` line. See the P5 note in the
Constitution check about the pre-existing repo-wide failure.

### U1-C6 (new) — exactly one escape site on the inline path (structural)

```
awk '/^function renderInline/,/^}/' bin/microworld-dashboard/markdown-lite.js | grep -c 'escapeHtml('
```

returns exactly **`1`**, and that call is the **first statement** of
`renderInline`, applied to the function's whole argument.

This is the criterion that encodes "unreachable by construction": with one escape
site covering the entire input, there is no second site to disagree with it (D2)
and no unescaped remainder for a classifier to miss (D1).

**Non-vacuity, measured:** returns **`6`** on the current module. The block-level
`escapeHtml` calls at `:54` (fenced code), `:68` (heading) and `:85` (blockquote)
are **outside** `renderInline`, are not counted by this command, and must stay.

### U1-C7 (new) — the sentinel scheme is gone, not merely guarded

Both, against `bin/microworld-dashboard/markdown-lite.js` only:

```
grep -c 'x00'     bin/microworld-dashboard/markdown-lite.js    -> 0
grep -ci 'sentinel' bin/microworld-dashboard/markdown-lite.js  -> 0
```

**Non-vacuity, measured:** currently **12** and **1** respectively.

**Scoped to the module, not the suite.** `tests/dashboard-markdown-lite.test.js`
must *keep* its three `\x00` payload tests (U1-C3b) — currently 3 matching lines
there, and that count must not go to 0. This pairing is the whole point: the
forged-marker payloads stay in the suite and still pass, while the module
retains no NUL-handling code at all. Safety from structure, not from filtering.

### U1-C8 (new) — mutation proof, replacing the original U1-C4

With `renderInline`'s single escape call neutered — change
`escapeHtml(text)` to `String(text)` — `node tests/dashboard-markdown-lite.test.js`
exits **non-zero**, **and** the failure output names the U1-C4 property test
among the failures. The reviewer performs this mutation and restores the file
afterwards (`git diff` clean).

Naming the property test specifically is what distinguishes this from the
original U1-C4, which any of six escape sites could satisfy. A suite that goes
red only on the U1-C3 enumerated cases while the property test stays green means
the property test is not wired to the escape path, and the unit FAILs regardless
of U1-C1.

---

## Self-check

- CHK1: Is the security property stated falsifiably, rather than as the parent
  plan's unfalsifiable "can never reach the page as markup"? — PASS (stated once
  above U1-C3, and operationalized as the runnable `unsafe()` helper that U1-C3
  and U1-C4 both call)
- CHK2: Would any criterion here have caught attempt 2 as written? — PASS (U1-C4
  fails it at 72 of 540 measured; U1-C6 fails it 6-vs-1; U1-C7 fails it 12-vs-0)
- CHK3: Would any criterion here have caught attempt 1 as written? — PASS (the
  same three; attempt 1's forged-sentinel hole is additionally pinned by U1-C3b,
  which attempt 1 failed)
- CHK4: Is every criterion machine-checkable? — PASS (each names an exit code, a
  `grep -c`/`awk` return value, a named-constant existence check, a minimum case
  count, or a boolean assertion over output; none says "correctly" or "safely")
- CHK5: Was every grep/awk criterion run against the current tree to confirm it
  is non-vacuous — i.e. that it does not already pass before any work is done? —
  PASS (U1-C6 measured 6, U1-C7 measured 12 and 1, U1-C4 measured 72/540; each
  baseline is quoted inline at the criterion)
- CHK6: Do U1-C3 and U1-C7 agree about the `\x00` payload tests, given U1-C7
  demands zero `x00` matches? — PASS (U1-C7 is explicitly scoped to the module
  file; U1-C3b explicitly requires the three test-file payloads be retained, and
  the pairing is stated as deliberate in both places)
- CHK7: Is the reviewer's claim that escape-first removes D2 as a side effect
  verified rather than repeated? — PASS (prototyped and measured on both D2
  instances — the nested-code case and the `&`-in-href case; the second instance
  is not in the FAIL record and was found by this verification)
- CHK8: Is the prescribed design's *ordering* dependency stated, so the
  implementer does not reorder the replaces and reintroduce a defect? — FAIL
  (missing) — revised in place: the prescribed order (code → link → bold →
  italic) and the reason the link regex must see escaped text are now stated
  under "The prescribed fix".
- CHK9: Does the spec constrain the outcome without handing over a finished
  patch? — PASS (the fix sketch is pseudo-code of the invariant; naming,
  comments, helper placement and regex literals for the four constructs are left
  to the implementer, while U1-C6/C7 make only escape-first satisfiable)
- CHK10: Is the behaviour change introduced by deleting the NUL strip
  acknowledged, so a reviewer does not read it as an unexplained regression? —
  FAIL (missing) — revised in place: added the "Accepted, documented consequence"
  paragraph recording NUL passthrough and why it is inert.
- CHK11: Are the N1-N5 non-blocking notes explicitly placed out of scope, so this
  debug pass does not creep? — PASS (Scope note names all five as out of scope,
  and flags N5's double-escape trap as an active hazard rather than a suggestion)

## Scribe update hint

On landing: add a `CONTEXT.md` glossary entry for **escaping by elimination** —
escaping a string by classifying which parts are *not* text and escaping the
remainder, so that any classifier error emits raw input; contrast with
escape-first, which escapes everything once at a single choke point and then only
adds markup. Cite this unit as the worked instance, and cross-reference the
adjacent **JSON type confusion** entry (`CONTEXT.md:574`) — both are the same
underlying error of a validator that *classifies* where it should *fail closed*.
Note in the dashboard wiki page that `markdown-lite.js` carries a
one-escape-site invariant enforced by U1-C6, so future edits must not add a
second `escapeHtml` call inside `renderInline`.

---

## Dispatch contract — fast path (1 unit, no `to-tickets`, no `task-master`)

This debug spec resolves to **one** unit, well inside the ≤5-unit fast path, so
it is dispatched directly and `task-master` is not involved.

**Unit:** `dash-ux-1-fix` (re-dispatch of `dash-ux-1`, Step 1 of
`docs/plans/2026-08-18-dashboard-usability-revision.md`)

### Objective
Replace `markdown-lite.js`'s escape-by-elimination inline path with a single
escape-first choke point, so that no code path in the module ever holds
unescaped user text, and prove it with a generated cross-product test that goes
red when the escape is removed.

### Retrieval
No tracker issue for this pass. Read this file —
`/home/sebas/AntiSlop/docs/plans/2026-08-18-dash-ux-1-debug-spec-escape-first.md` —
in full, plus parent Step 1 at
`/home/sebas/AntiSlop/docs/plans/2026-08-18-dashboard-usability-revision.md`
lines 337-401, and the standing FAIL record at
`/home/sebas/AntiSlop/.claude/reviewed/dash-ux-1.fail`.

### Affected files
- `/home/sebas/AntiSlop/bin/microworld-dashboard/markdown-lite.js` — the NUL
  strip at `:39`, `renderInline` at `:130-172` (the four construct replaces
  `:135-155`, the split/skip block `:157-163`, the marker-replacement block
  `:165-169`), and the header comment at `:3-6`.
- `/home/sebas/AntiSlop/tests/dashboard-markdown-lite.test.js` — extend, do not
  replace.

### Ordered edits
1. Delete the NUL strip at `:39` and its `:35-38` comment.
2. Rewrite `renderInline`: first statement escapes the whole argument exactly
   once; then the four construct replaces emit tags directly around the
   already-escaped content, in the order code → link → bold → italic. Delete the
   split/skip block and the marker-replacement block entirely.
3. Leave the block-level `escapeHtml` calls at `:54`, `:68` and `:85` exactly as
   they are. Do **not** route blockquotes through `renderInline` (N5) — that
   would double-escape them.
4. Update the `:3-6` header comment so it describes the one-escape-site
   invariant it now actually has.
5. Extend the suite: retain every existing case including the three `\x00`
   payloads, then add U1-C3 (c)/(d)/(e) and the U1-C4 property test with its
   shared `ALLOWED_TAG` / `JS_HREF` / `unsafe()` helper.

### Do NOT touch
- `index.html`, `server.js`, any other `tests/dashboard-*.test.js`, `CONTEXT.md`,
  `README.md`, `.claude-plugin/plugin.json`, `CHANGELOG.md`.
- `tests/validate.sh` — registration from `c9aae3d` is already correct.
- Units dash-ux-2 … dash-ux-5, and all page wiring (Step 2 owns it).
- The N1-N5 non-blocking notes in the FAIL record — out of scope this pass.
- `isValidLinkScheme`'s allowlist: do not widen or narrow it. (N2's
  protocol-relative `//evil.test/x` finding stays a non-blocking note; changing
  it here would be scope creep and would alter U1-C3's link assertions.)

### Acceptance criteria
U1-C1, U1-C2, U1-C5 verbatim from parent Step 1; U1-C3 and U1-C4 as **revised
above**; plus the new U1-C6, U1-C7, U1-C8. The load-bearing ones are U1-C4
(property test), U1-C6 (one escape site) and U1-C8 (mutation proof); U1-C8 is
non-negotiable and the reviewer will run it.

### Pre-resolved context
- **Do not re-derive the vulnerability surface** — it is measured above: five
  payloads × three block contexts, the `/` control, both D2 instances, and the
  540-case cross-product yielding 72 unsafe on the current module. Verify a
  specific claim only if you doubt it.
- **The prescribed design is prototyped, not theorised.** Escape-first was run
  against all five payloads, the control, both D2 instances, and the full 540-case
  cross-product: **0 unsafe**, with the three FAIL-1 forged-marker payloads still
  safe with no NUL-handling code present.
- **`ALLOWED_TAG` and `JS_HREF` must be copied verbatim** from U1-C4. Both
  looser spellings were measured and both silently break the criterion — one
  misses payload 5, the other false-positives on a correct fix.
- `grep` is wrapper-shadowed in this environment (bare `grep` inline resolves to
  `ugrep`, GNU `grep` inside a script). The counts quoted in U1-C6/U1-C7 are
  line-counts and agree under both; if a count looks off by an order of
  magnitude, check which `grep` ran before concluding the code is wrong.
- This repo's suites are plain Node scripts with a `failures` array and a
  non-zero exit — follow `tests/dashboard-markdown-lite.test.js`'s existing
  shape. Append new checks **above** the trailing `if (failures.length > 0)`
  block at `:224`; anything added below it can never fail the suite.

### Escalation
This unit has already consumed **both** FAIL attempts under the shared protocol's
2-FAIL cap. A third FAIL must **not** be re-dispatched to `lead-programmer`:
stop, and surface to the human with the full three-attempt defect history. If any
criterion above proves unverifiable or wrong during implementation, stop and
report rather than reinterpreting it — a criterion reinterpreted to pass is the
exact failure mode that produced this escalation. In particular, if U1-C4 reports
0 unsafe cases against the **unfixed** module, the generator is wrong: report it
rather than accepting the green.
