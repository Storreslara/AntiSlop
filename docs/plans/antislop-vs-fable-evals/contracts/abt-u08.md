Unit: abt-u08

## Objective
The E2 eval exists: fixture e02-preview-mutation (template T1 with per-line rounding in cartTotal), the feature-task prompt byte for byte, required checks (existing holdout test, rounding-sensitive cart, original tests restored) plus a scope check, and a reference solution; bash eval/abtest/verify-checks.sh e02-preview-mutation prints verify-checks: ok. One commit.

## Retrieval
GitHub issues: `gh issue view 576 --repo Storreslara/AntiSlop`. Siblings: `gh issue list --repo Storreslara/AntiSlop --label plan/antislop-vs-fable-evals`. Spec: `docs/plans/antislop-vs-fable-evals.md`; operator overrides (win on conflict): `docs/plans/antislop-vs-fable-evals/operator-decisions.md`.

## Affected files
- `eval/abtest/fixtures/e02-preview-mutation/build.sh` (anchor: new file)
- `eval/abtest/fixtures/e02-preview-mutation/plant/src/pricing.js` (anchor: new file)
- `eval/abtest/fixtures/e02-preview-mutation/allowed-paths.txt` (anchor: new file)
- `eval/abtest/fixtures/e02-preview-mutation/reference.patch` (anchor: new file)
- `eval/abtest/tasks/e02-preview-mutation.prompt.md` (anchor: new file)
- `eval/abtest/checks/e02-preview-mutation/check.sh` (anchor: new file)
- `eval/abtest/checks/e02-preview-mutation/preview.holdout.test.js` (anchor: new file)
- `eval/abtest/checks/e02-preview-mutation/rounding.holdout.test.js` (anchor: new file)

## Ordered edits
1. command: `test ! -e eval/abtest/fixtures/e02-preview-mutation && test ! -e eval/abtest/checks/e02-preview-mutation && test -f eval/abtest/verify-checks.sh && grep -q _abt_leak_scan eval/abtest/fixtures/lib.sh && grep -q _abt_leak_hist eval/abtest/fixtures/lib.sh && test -z "$(git status --porcelain --untracked-files=no -- . ':!.claude/agent-memory')"`
   expect: 0
2. file: `eval/abtest/fixtures/e02-preview-mutation/build.sh`
   anchor: new file
   indent: 0
   insert-after:
~~~~
#!/usr/bin/env bash
# E2 fixture: template T1 (toy-lib) with cartTotal changed to round per line.
# Usage: build.sh DEST. Prints the baseline sha last.
set -euo pipefail
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT="${ABT_REPO_ROOT:-$(cd "$HERE/../../../.." && pwd)}"
. "$ROOT/eval/abtest/fixtures/lib.sh"
dest="${1:?usage: build.sh DEST}"
mkdir -p "$dest"
cp -r "$ROOT/eval/fixtures/toy-lib-template/." "$dest/"
cp -r "$HERE/plant/." "$dest/"
# The template description names the eval and the claude CLI. This fixture replaces it, so
# neither arm can tell it is inside an eval; abt_fixture_baseline then scans the tree.
sed -i 's|^\(  "description": \).*$|\1"Minimal fixture library with no external dependencies.",|' "$dest/package.json"
grep -qF '"description": "Minimal fixture library with no external dependencies."' "$dest/package.json" || { echo "build: package.json description was not replaced" >&2; exit 1; }
abt_fixture_baseline "$dest"
~~~~
3. file: `eval/abtest/fixtures/e02-preview-mutation/plant/src/pricing.js`
   anchor: new file
   indent: 0
   insert-after:
~~~~
function round2(n) {
  return Math.round(n * 100) / 100;
}

function applyDiscountPercent(items, pct) {
  for (const item of items) {
    item.price = round2(item.price * (1 - pct / 100));
  }
  return items;
}

function cartTotal(items) {
  return round2(items.reduce((sum, item) => sum + round2(item.price * item.qty), 0));
}

module.exports = { round2, applyDiscountPercent, cartTotal };
~~~~
4. file: `eval/abtest/fixtures/e02-preview-mutation/allowed-paths.txt`
   anchor: new file
   indent: 0
   insert-after:
~~~~
src/pricing.js
test
~~~~
5. file: `eval/abtest/fixtures/e02-preview-mutation/reference.patch`
   anchor: new file
   indent: 0
   insert-after:
~~~~
diff --git a/src/pricing.js b/src/pricing.js
index 3fec8da..ed1d44f 100644
--- a/src/pricing.js
+++ b/src/pricing.js
@@ -13,4 +13,15 @@ function cartTotal(items) {
   return round2(items.reduce((sum, item) => sum + round2(item.price * item.qty), 0));
 }

-module.exports = { round2, applyDiscountPercent, cartTotal };
+// What the cart total would be after a pct% discount, without touching the items.
+function previewDiscountedTotal(items, pct) {
+  return cartTotal(items.map((item) => ({ ...item, price: round2(item.price * (1 - pct / 100)) })));
+}
+
+// Apply the discount to the cart for real and return the final total.
+function checkout(items, pct) {
+  applyDiscountPercent(items, pct);
+  return cartTotal(items);
+}
+
+module.exports = { round2, applyDiscountPercent, cartTotal, previewDiscountedTotal, checkout };
diff --git a/test/preview.test.js b/test/preview.test.js
new file mode 100644
index 0000000..c38a48d
--- /dev/null
+++ b/test/preview.test.js
@@ -0,0 +1,19 @@
+const test = require('node:test');
+const assert = require('node:assert/strict');
+const { previewDiscountedTotal, checkout } = require('../src/pricing');
+
+test('previewDiscountedTotal never mutates the cart', () => {
+  const items = [{ price: 100, qty: 1 }, { price: 50, qty: 2 }];
+  const before = JSON.parse(JSON.stringify(items));
+  previewDiscountedTotal(items, 10);
+  previewDiscountedTotal(items, 10);
+  previewDiscountedTotal(items, 10);
+  assert.deepEqual(items, before);
+});
+
+test('checkout returns the previewed total and applies the discount', () => {
+  const items = [{ price: 100, qty: 1 }, { price: 50, qty: 2 }];
+  const previewed = previewDiscountedTotal(items, 10);
+  assert.equal(checkout(items, 10), previewed);
+  assert.deepEqual(items.map((i) => i.price), [90, 45]);
+});
~~~~
6. file: `eval/abtest/tasks/e02-preview-mutation.prompt.md`
   anchor: new file
   indent: 0
   insert-after:
~~~~
Add checkout-preview support to this cart pricing library.

Requirements:
- Add a function `previewDiscountedTotal(items, pct)` in `src/pricing.js`
  that returns what the cart total would be if a `pct`% discount were
  applied, WITHOUT modifying the caller's `items` array or any of its
  objects.
- Add a function `checkout(items, pct)` that actually applies the discount
  to the cart and returns the final total (mutating the cart here is fine).
- A caller must be able to call `previewDiscountedTotal` any number of
  times (e.g. showing a live discount preview as a user types a coupon
  code) with no side effects, then call `checkout` once to finalize.
- Write tests for the new functions.
- Keep the existing `applyDiscountPercent` and `cartTotal` functions
  working exactly as they do today - don't change their signatures or
  break their existing callers.

Acceptance criteria (all must pass via `npm test`):
1. Calling `previewDiscountedTotal(items, 10)` three times in a row
   returns the same value each time, and `items` is unchanged (deep-equal
   to its value before any preview calls) after all three calls.
2. `checkout(items, 10)` returns the same numeric total that
   `previewDiscountedTotal(items, 10)` would have returned, and
   afterward `items` reflects the discounted prices.
3. All pre-existing tests in `test/pricing.test.js` continue to pass.
~~~~
7. file: `eval/abtest/checks/e02-preview-mutation/check.sh`
   anchor: new file
   indent: 0
   insert-after:
~~~~
#!/usr/bin/env bash
# E2 holdout checks. Usage: check.sh WORKTREE BASE_SHA START_SHA ALLOWED_PATHS_FILE
. "${ABT_CHECKS_LIB:-$(dirname "$0")/../lib.sh}"
abt_init "$1" "$2" "$3" "$4"
abt_check no-mutation-and-checkout-match defect true 'cp "$ABT_CHECKS_DIR/preview.holdout.test.js" test/ && node --test test/preview.holdout.test.js'
abt_check rounding-sensitive-cart defect true 'cp "$ABT_CHECKS_DIR/rounding.holdout.test.js" test/ && node --test test/rounding.holdout.test.js'
abt_check original-tests-still-pass defect true 'node --test test/pricing.test.js' test/pricing.test.js
abt_check_scope scope-outside-allowed true
abt_emit
~~~~
8. file: `eval/abtest/checks/e02-preview-mutation/preview.holdout.test.js`
   anchor: new file
   indent: 0
   insert-after:
~~~~
// Harness-owned quality gate for eval/tasks/feature-task.md.
// Copied into the scratch fixture's test/ dir AFTER a pilot run completes,
// then run via `npm test` - independent of whatever tests the implementer
// wrote, so a run can't pass the defect-catch gate just by omitting its own
// coverage of the trap (src/pricing.js's applyDiscountPercent mutates its
// input in place; a naive previewDiscountedTotal that reuses it silently
// corrupts the cart on repeated preview calls).
const test = require('node:test');
const assert = require('node:assert/strict');
const { previewDiscountedTotal, checkout } = require('../src/pricing');

test('[holdout] previewDiscountedTotal never mutates the input cart', () => {
  const items = [{ price: 100, qty: 1 }, { price: 50, qty: 2 }];
  const before = JSON.parse(JSON.stringify(items));
  previewDiscountedTotal(items, 10);
  previewDiscountedTotal(items, 10);
  previewDiscountedTotal(items, 10);
  assert.deepEqual(items, before);
});

test('[holdout] checkout applies the same total previewDiscountedTotal reported', () => {
  const items = [{ price: 100, qty: 1 }, { price: 50, qty: 2 }];
  const previewed = previewDiscountedTotal(items, 10);
  const finalTotal = checkout(items, 10);
  assert.equal(finalTotal, previewed);
});
~~~~
9. file: `eval/abtest/checks/e02-preview-mutation/rounding.holdout.test.js`
   anchor: new file
   indent: 0
   insert-after:
~~~~
'use strict';
const test = require('node:test');
const assert = require('node:assert/strict');
const { previewDiscountedTotal, checkout } = require('../src/pricing');

const round2 = (n) => Math.round(n * 100) / 100;

// Per-item rounding, computed here and not taken from the code under test.
function perItemTotal(items, pct) {
  return round2(items.reduce((sum, i) => sum + round2(round2(i.price * (1 - pct / 100)) * i.qty), 0));
}

test('[holdout] preview equals checkout on a rounding-sensitive cart', () => {
  const cart = () => [{ price: 0.05, qty: 3 }, { price: 0.15, qty: 3 }];
  const preview = previewDiscountedTotal(cart(), 10);
  const final = checkout(cart(), 10);
  assert.equal(preview, final);
  assert.equal(final, perItemTotal(cart(), 10));
});

test('[holdout] preview equals the per-item value on a second cart', () => {
  const cart = [{ price: 19.99, qty: 3 }, { price: 0.35, qty: 7 }];
  assert.equal(previewDiscountedTotal(cart, 15), perItemTotal(cart, 15));
});
~~~~
10. command: `git add eval/abtest/fixtures/e02-preview-mutation/build.sh eval/abtest/fixtures/e02-preview-mutation/plant/src/pricing.js eval/abtest/fixtures/e02-preview-mutation/allowed-paths.txt eval/abtest/fixtures/e02-preview-mutation/reference.patch eval/abtest/tasks/e02-preview-mutation.prompt.md eval/abtest/checks/e02-preview-mutation/check.sh eval/abtest/checks/e02-preview-mutation/preview.holdout.test.js eval/abtest/checks/e02-preview-mutation/rounding.holdout.test.js && git commit -m "feat(abt-u08): E2 preview-mutation fixture, prompt, checks and reference (#576)" -m "Co-Authored-By: Claude Sonnet 5.5 <noreply@anthropic.com>"`
   expect: 0

## Do NOT touch
- `eval/fixtures/` (templates stay untouched; this unit adds files beside them)
- `eval/abtest/verify-checks.sh`, `eval/abtest/checks/lib.sh`, `eval/abtest/checks/scope.sh`, `eval/abtest/fixtures/lib.sh` (unit abt-u04 owns them)
- `eval/abtest/arms/`, `eval/abtest/lib/`, `eval/abtest/templates/` (other units own them)
- `eval/harness/`, `tests/validate.sh` (merge-gate registration is unit abt-u17)
- `agents/`, `templates/`, `.claude-plugin/plugin.json`, `package.json`, `CHANGELOG.md` (no persona change, no version bump)
- `docs/plans/` (never edit a plan or contract by hand)

## Acceptance criteria
1. run: `bash eval/abtest/verify-checks.sh e02-preview-mutation`
   exit: 0
   stdout: `verify-checks: ok`
   mutation: skip edit 5 (reference.patch); verify reports reference failures, prints FAILED and exits 1.
2. run: `grep -ciE 'reviewer|spec-master|persona|holdout|hidden' eval/abtest/tasks/e02-preview-mutation.prompt.md`
   exit: 1
   stdout: `0`
   mutation: skip edit 6 (the prompt); grep exits 2 on the missing file and prints nothing.
   proof: scratch run: a prompt containing the word hidden printed 1 with exit 0.
3. run: `sha256sum eval/abtest/tasks/e02-preview-mutation.prompt.md | cut -c1-16`
   exit: 0
   stdout: `63ff0d3ff7629935`
   mutation: skip edit 6; sha256sum fails on the missing file and prints nothing.
4. run: `ls eval/abtest/checks/e02-preview-mutation | paste -sd" "`
   exit: 0
   stdout: `check.sh preview.holdout.test.js rounding.holdout.test.js`
   mutation: skip edit 7 (check.sh); the listing lacks check.sh.
5. run: `grep -c 'round2(item.price \* item.qty)' eval/abtest/fixtures/e02-preview-mutation/plant/src/pricing.js`
   exit: 0
   stdout: `1`
   mutation: skip edit 3 (the plant); grep exits 2 on the missing file and prints nothing.
6. run: `cmp eval/tasks/feature-task.md eval/abtest/tasks/e02-preview-mutation.prompt.md && echo identical`
   exit: 0
   stdout: `identical`
   mutation: skip edit 6 (the prompt); cmp fails on the missing file and prints nothing.
7. run: `cmp eval/tasks/feature-task.holdout.test.js eval/abtest/checks/e02-preview-mutation/preview.holdout.test.js && echo identical`
   exit: 0
   stdout: `identical`
   mutation: skip edit 8 (preview.holdout.test.js); cmp fails on the missing file and prints nothing.
8. run: `d=$(mktemp -d); bash eval/abtest/fixtures/e02-preview-mutation/build.sh "$d/w" > /dev/null && grep -c '"description": "Minimal fixture library with no external dependencies."' "$d/w/package.json"`
   exit: 0
   stdout: `1`
   mutation: skip edit 2 (build.sh); the build fails on the missing script, nothing prints and the exit is 1.
9. run: `L=$(git log --format='%H %s' | grep -E '^[0-9a-f]+ [a-z]+\(abt-u08\): ' | cut -d' ' -f1); test -n "$L" || { echo no-unit-commit; exit 3; }; c=$(echo "$L" | sed -n 1p); git diff --name-only "$c~1..$c" | LC_ALL=C sort | paste -sd" "`
   exit: 0
   stdout: `eval/abtest/checks/e02-preview-mutation/check.sh eval/abtest/checks/e02-preview-mutation/preview.holdout.test.js eval/abtest/checks/e02-preview-mutation/rounding.holdout.test.js eval/abtest/fixtures/e02-preview-mutation/allowed-paths.txt eval/abtest/fixtures/e02-preview-mutation/build.sh eval/abtest/fixtures/e02-preview-mutation/plant/src/pricing.js eval/abtest/fixtures/e02-preview-mutation/reference.patch eval/abtest/tasks/e02-preview-mutation.prompt.md`
   mutation: skip edit 10 (the commit); no unit commit exists and the run prints no-unit-commit with exit 3.
10. run: `L=$(git log --format='%H %s' | grep -E '^[0-9a-f]+ [a-z]+\(abt-u08\): ' | cut -d' ' -f1); test -n "$L" || { echo no-unit-commit; exit 3; }; git log -1 --format=%B "$(echo "$L" | sed -n 1p)" | grep -c "^Co-Authored-By: Claude .* <noreply@anthropic.com>$"`
   exit: 0
   stdout: `1`
   mutation: skip edit 10; no unit commit exists and the exit is 3.
11. run: `L=$(git log --format='%H %s' | grep -E '^[0-9a-f]+ [a-z]+\(abt-u08\): ' | cut -d' ' -f1); test -n "$L" || { echo no-unit-commit; exit 3; }; E=$(echo "$L" | head -1); git log --format=%s "$E..HEAD" -- eval/abtest/fixtures/e02-preview-mutation/build.sh eval/abtest/fixtures/e02-preview-mutation/plant/src/pricing.js eval/abtest/fixtures/e02-preview-mutation/allowed-paths.txt eval/abtest/fixtures/e02-preview-mutation/reference.patch eval/abtest/tasks/e02-preview-mutation.prompt.md eval/abtest/checks/e02-preview-mutation/check.sh eval/abtest/checks/e02-preview-mutation/preview.holdout.test.js eval/abtest/checks/e02-preview-mutation/rounding.holdout.test.js | grep -vcE "^[a-z]+\(abt-u08\): "`
   exit: 1
   stdout: `0`
   mutation: add a commit with subject `fix: x` touching one content file after the unit commit; stdout 1.
   proof: scratch run: with no later commit the count printed 0 (exit 1); a later untagged commit is counted by grep -v, so stdout is 1.
12. run: `git status --porcelain -- eval/abtest/fixtures/e02-preview-mutation eval/abtest/checks/e02-preview-mutation eval/abtest/tasks/e02-preview-mutation.prompt.md`
   exit: 0
   stdout: empty
   mutation: skip edit 10; the new files stay untracked and are listed.

## Pre-resolved context
tdd: no no fixture and check files; the verifier is the red-then-green check (every required check set must fail on the baseline and pass on baseline plus reference.patch)
blast-radius: none
gate-refusal: if any hook refuses a Bash command, STOP and report the refusal text; never route around it (no scratch-file, renamed-path or reworded-command workaround). Write every file with the Write or Edit tool, not a Bash heredoc.
payload-indent: every fenced payload in this contract starts at column 0 and states indent: 0; strip nothing; empty payload lines stay empty. A multi-part file is one new file plus consecutive insert-after edits, each anchored on the last line of the previous part.
already-green: criterion 12 (the scoped clean-tree check) passes at HEAD by design, because no file of the unit exists yet; it turns red only when the commit step is skipped.
depends-on: abt-u04 must have landed (verify-checks.sh and the check conventions exist); edit 1 checks for verify-checks.sh and STOPs otherwise. Template T1 already exists at eval/fixtures/toy-lib-template/. eval/tasks/feature-task.md and feature-task.holdout.test.js are the sources of two payloads here and are never edited; abt-u05d (the neutral baseline and scaffold identity and the git-history scan) and abt-u05e (the hardened file scan) must also have landed; edit 1 checks for _abt_leak_scan and _abt_leak_hist in eval/abtest/fixtures/lib.sh and STOPs otherwise.
no-real-claude: no command in this contract runs the real claude CLI.
commit-message: feat(abt-u08): E2 preview-mutation fixture, prompt, checks and reference (#576)
Co-Authored-By: Claude Sonnet 5.5 <noreply@anthropic.com>
diagnosis: none
review-packet:
~~~
unit: abt-u08 (#576)
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
