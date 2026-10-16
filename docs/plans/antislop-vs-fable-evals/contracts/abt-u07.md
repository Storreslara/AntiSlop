Unit: abt-u07

## Objective
The E1 eval exists: fixture e01-ambiguous-tax (template T1 plus a glossary and README plant), its verbatim prompt, three required checks plus a scope check, and a reference solution; bash eval/abtest/verify-checks.sh e01-ambiguous-tax prints verify-checks: ok. One commit.

## Retrieval
GitHub issues: `gh issue view 575 --repo Storreslara/AntiSlop`. Siblings: `gh issue list --repo Storreslara/AntiSlop --label plan/antislop-vs-fable-evals`. Spec: `docs/plans/antislop-vs-fable-evals.md`; operator overrides (win on conflict): `docs/plans/antislop-vs-fable-evals/operator-decisions.md`.

## Affected files
- `eval/abtest/fixtures/e01-ambiguous-tax/build.sh` (anchor: new file)
- `eval/abtest/fixtures/e01-ambiguous-tax/plant/CONTEXT.md` (anchor: new file)
- `eval/abtest/fixtures/e01-ambiguous-tax/plant/README.md` (anchor: new file)
- `eval/abtest/fixtures/e01-ambiguous-tax/allowed-paths.txt` (anchor: new file)
- `eval/abtest/fixtures/e01-ambiguous-tax/reference.patch` (anchor: new file)
- `eval/abtest/tasks/e01-ambiguous-tax.prompt.md` (anchor: new file)
- `eval/abtest/checks/e01-ambiguous-tax/check.sh` (anchor: new file)
- `eval/abtest/checks/e01-ambiguous-tax/tax.holdout.test.js` (anchor: new file)
- `eval/abtest/checks/e01-ambiguous-tax/characterisation.holdout.test.js` (anchor: new file)

## Ordered edits
1. command: `test ! -e eval/abtest/fixtures/e01-ambiguous-tax && test ! -e eval/abtest/checks/e01-ambiguous-tax && test -f eval/abtest/verify-checks.sh && test -z "$(git status --porcelain --untracked-files=no -- . ':!.claude/agent-memory')"`
   expect: 0
2. file: `eval/abtest/fixtures/e01-ambiguous-tax/build.sh`
   anchor: new file
   indent: 0
   insert-after:
~~~~
#!/usr/bin/env bash
# E1 fixture: template T1 (toy-lib) plus a glossary and a README that settle the
# task's ambiguities. Usage: build.sh DEST. Prints the baseline sha last.
set -euo pipefail
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT="${ABT_REPO_ROOT:-$(cd "$HERE/../../../.." && pwd)}"
. "$ROOT/eval/abtest/fixtures/lib.sh"
dest="${1:?usage: build.sh DEST}"
mkdir -p "$dest"
cp -r "$ROOT/eval/fixtures/toy-lib-template/." "$dest/"
cp -r "$HERE/plant/." "$dest/"
abt_fixture_baseline "$dest"
~~~~
3. file: `eval/abtest/fixtures/e01-ambiguous-tax/plant/CONTEXT.md`
   anchor: new file
   indent: 0
   insert-after:
~~~~
# toy-lib glossary

**taxable amount**: the post-discount line total. Tax is never applied to the pre-discount price.
_Avoid_: subtotal, gross.

**rate**: always a percentage from 0 to 100, never a fraction; see `applyDiscountPercent`.
_Avoid_: ratio, factor.
~~~~
4. file: `eval/abtest/fixtures/e01-ambiguous-tax/plant/README.md`
   anchor: new file
   indent: 0
   insert-after:
~~~~
# toy-lib

Small cart pricing helpers: `round2`, `applyDiscountPercent`, `cartTotal`.

Conventions: all rates are percentages (10 means ten percent). Run the tests with `npm test`.
~~~~
5. file: `eval/abtest/fixtures/e01-ambiguous-tax/allowed-paths.txt`
   anchor: new file
   indent: 0
   insert-after:
~~~~
src/pricing.js
test
ASSUMPTIONS.md
~~~~
6. file: `eval/abtest/fixtures/e01-ambiguous-tax/reference.patch`
   anchor: new file
   indent: 0
   insert-after:
~~~~
diff --git a/ASSUMPTIONS.md b/ASSUMPTIONS.md
new file mode 100644
index 0000000..9125b6e
--- /dev/null
+++ b/ASSUMPTIONS.md
@@ -0,0 +1,3 @@
+- Tax is applied to the post-discount total, as CONTEXT.md defines the taxable amount.
+- The tax rate and the discount are percentages (20 means twenty percent), as the README and CONTEXT.md say.
+- The input items are not mutated; discounted prices are computed on copies.
diff --git a/src/pricing.js b/src/pricing.js
index 6376351..bfeeb9a 100644
--- a/src/pricing.js
+++ b/src/pricing.js
@@ -13,4 +13,12 @@ function cartTotal(items) {
   return round2(items.reduce((sum, item) => sum + item.price * item.qty, 0));
 }
 
-module.exports = { round2, applyDiscountPercent, cartTotal };
+// Discount first, then tax. Both rates are percentages (see CONTEXT.md).
+function cartTotalWithTax(items, discountPct, taxRate) {
+  const discounted = cartTotal(
+    items.map((item) => ({ ...item, price: round2(item.price * (1 - discountPct / 100)) }))
+  );
+  return round2(discounted * (1 + taxRate / 100));
+}
+
+module.exports = { round2, applyDiscountPercent, cartTotal, cartTotalWithTax };
diff --git a/test/tax.test.js b/test/tax.test.js
new file mode 100644
index 0000000..19bb136
--- /dev/null
+++ b/test/tax.test.js
@@ -0,0 +1,13 @@
+const test = require('node:test');
+const assert = require('node:assert/strict');
+const { cartTotalWithTax } = require('../src/pricing');
+
+test('cartTotalWithTax taxes the discounted total', () => {
+  assert.equal(cartTotalWithTax([{ price: 100, qty: 1 }], 10, 20), 108);
+});
+
+test('cartTotalWithTax leaves the items untouched', () => {
+  const items = [{ price: 100, qty: 1 }];
+  cartTotalWithTax(items, 10, 20);
+  assert.deepEqual(items, [{ price: 100, qty: 1 }]);
+});
~~~~
7. file: `eval/abtest/tasks/e01-ambiguous-tax.prompt.md`
   anchor: new file
   indent: 0
   insert-after:
~~~~
Add `cartTotalWithTax(items, discountPct, taxRate)` to src/pricing.js:
it returns the cart total after applying the discount and then tax.
Do not change existing functions. Add tests. If anything in this task is
ambiguous, resolve it from the repository's own documentation and record
each assumption you made as one bullet in a new file ASSUMPTIONS.md.
Run `npm test` before you finish.
~~~~
8. file: `eval/abtest/checks/e01-ambiguous-tax/check.sh`
   anchor: new file
   indent: 0
   insert-after:
~~~~
#!/usr/bin/env bash
# E1 holdout checks. Usage: check.sh WORKTREE BASE_SHA START_SHA ALLOWED_PATHS_FILE
. "${ABT_CHECKS_LIB:-$(dirname "$0")/../lib.sh}"
abt_init "$1" "$2" "$3" "$4"
abt_check tax-after-discount defect true 'cp "$ABT_CHECKS_DIR/tax.holdout.test.js" test/ && node --test test/tax.holdout.test.js'
abt_check existing-behaviour defect true 'cp "$ABT_CHECKS_DIR/characterisation.holdout.test.js" test/ && node --test test/characterisation.holdout.test.js'
abt_check assumptions-recorded premise true 'test -f ASSUMPTIONS.md && grep -qiE "tax" ASSUMPTIONS.md && grep -qiE "percent|rate" ASSUMPTIONS.md'
abt_check_scope scope-outside-allowed true
abt_emit
~~~~
9. file: `eval/abtest/checks/e01-ambiguous-tax/tax.holdout.test.js`
   anchor: new file
   indent: 0
   insert-after:
~~~~
'use strict';
const test = require('node:test');
const assert = require('node:assert/strict');
const pricing = require('../src/pricing');

test('[holdout] tax applies to the discounted total with a percentage rate', () => {
  const total = pricing.cartTotalWithTax([{ price: 100, qty: 1 }], 10, 20);
  assert.equal(total, 108);
  for (const wrong of [110, 120, 90.2]) assert.notEqual(total, wrong);
});

test('[holdout] the input items are not mutated', () => {
  const items = [{ price: 100, qty: 1 }, { price: 50, qty: 2 }];
  const before = JSON.parse(JSON.stringify(items));
  pricing.cartTotalWithTax(items, 10, 20);
  assert.deepEqual(items, before);
});

test('[holdout] zero discount and zero tax return the plain cart total', () => {
  const items = [{ price: 10, qty: 2 }, { price: 5, qty: 3 }];
  assert.equal(pricing.cartTotalWithTax(items, 0, 0), 35);
});
~~~~
10. file: `eval/abtest/checks/e01-ambiguous-tax/characterisation.holdout.test.js`
   anchor: new file
   indent: 0
   insert-after:
~~~~
'use strict';
const test = require('node:test');
const assert = require('node:assert/strict');
const { round2, applyDiscountPercent, cartTotal } = require('../src/pricing');

test('[holdout] applyDiscountPercent still mutates in place and returns the same array', () => {
  const items = [{ price: 100, qty: 1 }, { price: 50, qty: 2 }];
  const out = applyDiscountPercent(items, 10);
  assert.equal(out, items);
  assert.deepEqual(items.map((i) => i.price), [90, 45]);
});

test('[holdout] cartTotal still sums price times qty', () => {
  assert.equal(cartTotal([{ price: 10, qty: 2 }, { price: 5, qty: 3 }]), 35);
  assert.equal(cartTotal([]), 0);
});

test('[holdout] round2 still rounds to two places', () => {
  assert.equal(round2(10.456), 10.46);
});
~~~~
11. command: `git add eval/abtest/fixtures/e01-ambiguous-tax/build.sh eval/abtest/fixtures/e01-ambiguous-tax/plant/CONTEXT.md eval/abtest/fixtures/e01-ambiguous-tax/plant/README.md eval/abtest/fixtures/e01-ambiguous-tax/allowed-paths.txt eval/abtest/fixtures/e01-ambiguous-tax/reference.patch eval/abtest/tasks/e01-ambiguous-tax.prompt.md eval/abtest/checks/e01-ambiguous-tax/check.sh eval/abtest/checks/e01-ambiguous-tax/tax.holdout.test.js eval/abtest/checks/e01-ambiguous-tax/characterisation.holdout.test.js && git commit -m "feat(abt-u07): E1 ambiguous-tax fixture, prompt, checks and reference (#575)" -m "Co-Authored-By: Claude Sonnet 5.5 <noreply@anthropic.com>"`
   expect: 0

## Do NOT touch
- `eval/fixtures/` (templates stay untouched; this unit adds files beside them)
- `eval/abtest/verify-checks.sh`, `eval/abtest/checks/lib.sh`, `eval/abtest/checks/scope.sh`, `eval/abtest/fixtures/lib.sh` (unit abt-u04 owns them)
- `eval/abtest/arms/`, `eval/abtest/lib/`, `eval/abtest/templates/` (other units own them)
- `eval/harness/`, `tests/validate.sh` (merge-gate registration is unit abt-u17)
- `agents/`, `templates/`, `.claude-plugin/plugin.json`, `package.json`, `CHANGELOG.md` (no persona change, no version bump)
- `docs/plans/` (never edit a plan or contract by hand)

## Acceptance criteria
1. run: `bash eval/abtest/verify-checks.sh e01-ambiguous-tax`
   exit: 0
   stdout: `verify-checks: ok`
   mutation: skip edit 6 (reference.patch); verify reports reference failures, prints FAILED and exits 1.
2. run: `grep -ciE 'reviewer|spec-master|persona|holdout|hidden' eval/abtest/tasks/e01-ambiguous-tax.prompt.md`
   exit: 1
   stdout: `0`
   mutation: skip edit 7 (the prompt); grep exits 2 on the missing file and prints nothing.
   proof: scratch run: a prompt containing the word hidden printed 1 with exit 0.
3. run: `sha256sum eval/abtest/tasks/e01-ambiguous-tax.prompt.md | cut -c1-16`
   exit: 0
   stdout: `21892ae0b8f20bb7`
   mutation: skip edit 7; sha256sum fails on the missing file and prints nothing.
4. run: `ls eval/abtest/checks/e01-ambiguous-tax | paste -sd" "`
   exit: 0
   stdout: `characterisation.holdout.test.js check.sh tax.holdout.test.js`
   mutation: skip edit 8 (check.sh); the listing lacks check.sh.
5. run: `ls eval/abtest/fixtures/e01-ambiguous-tax/ | paste -sd" "`
   exit: 0
   stdout: `allowed-paths.txt build.sh plant reference.patch`
   mutation: skip edit 2 (build.sh); the listing lacks build.sh.
6. run: `grep -c 'taxable amount' eval/abtest/fixtures/e01-ambiguous-tax/plant/CONTEXT.md`
   exit: 0
   stdout: `1`
   mutation: skip edit 3 (the glossary plant); grep exits 2 on the missing file and prints nothing.
7. run: `L=$(git log --format='%H %s' | grep -E '^[0-9a-f]+ [a-z]+\(abt-u07\): ' | cut -d' ' -f1); test -n "$L" || { echo no-unit-commit; exit 3; }; c=$(echo "$L" | sed -n 1p); git diff --name-only "$c~1..$c" | LC_ALL=C sort | paste -sd" "`
   exit: 0
   stdout: `eval/abtest/checks/e01-ambiguous-tax/characterisation.holdout.test.js eval/abtest/checks/e01-ambiguous-tax/check.sh eval/abtest/checks/e01-ambiguous-tax/tax.holdout.test.js eval/abtest/fixtures/e01-ambiguous-tax/allowed-paths.txt eval/abtest/fixtures/e01-ambiguous-tax/build.sh eval/abtest/fixtures/e01-ambiguous-tax/plant/CONTEXT.md eval/abtest/fixtures/e01-ambiguous-tax/plant/README.md eval/abtest/fixtures/e01-ambiguous-tax/reference.patch eval/abtest/tasks/e01-ambiguous-tax.prompt.md`
   mutation: skip edit 11 (the commit); no unit commit exists and the run prints no-unit-commit with exit 3.
8. run: `L=$(git log --format='%H %s' | grep -E '^[0-9a-f]+ [a-z]+\(abt-u07\): ' | cut -d' ' -f1); test -n "$L" || { echo no-unit-commit; exit 3; }; git log -1 --format=%B "$(echo "$L" | sed -n 1p)" | grep -c "^Co-Authored-By: Claude .* <noreply@anthropic.com>$"`
   exit: 0
   stdout: `1`
   mutation: skip edit 11; no unit commit exists and the exit is 3.
9. run: `L=$(git log --format='%H %s' | grep -E '^[0-9a-f]+ [a-z]+\(abt-u07\): ' | cut -d' ' -f1); test -n "$L" || { echo no-unit-commit; exit 3; }; E=$(echo "$L" | head -1); git log --format=%s "$E..HEAD" -- eval/abtest/fixtures/e01-ambiguous-tax/build.sh eval/abtest/fixtures/e01-ambiguous-tax/plant/CONTEXT.md eval/abtest/fixtures/e01-ambiguous-tax/plant/README.md eval/abtest/fixtures/e01-ambiguous-tax/allowed-paths.txt eval/abtest/fixtures/e01-ambiguous-tax/reference.patch eval/abtest/tasks/e01-ambiguous-tax.prompt.md eval/abtest/checks/e01-ambiguous-tax/check.sh eval/abtest/checks/e01-ambiguous-tax/tax.holdout.test.js eval/abtest/checks/e01-ambiguous-tax/characterisation.holdout.test.js | grep -vcE "^[a-z]+\(abt-u07\): "`
   exit: 1
   stdout: `0`
   mutation: add a commit with subject `fix: x` touching one content file after the unit commit; stdout 1.
   proof: scratch run: with no later commit the count printed 0 (exit 1); a later untagged commit is counted by grep -v, so stdout is 1.
10. run: `git status --porcelain -- eval/abtest/fixtures/e01-ambiguous-tax eval/abtest/checks/e01-ambiguous-tax eval/abtest/tasks/e01-ambiguous-tax.prompt.md`
   exit: 0
   stdout: empty
   mutation: skip edit 11; the new files stay untracked and are listed.

## Pre-resolved context
tdd: no no fixture and check files; the verifier is the red-then-green check (every required check set must fail on the baseline and pass on baseline plus reference.patch)
blast-radius: none
gate-refusal: if any hook refuses a Bash command, STOP and report the refusal text; never route around it (no scratch-file, renamed-path or reworded-command workaround). Write every file with the Write or Edit tool, not a Bash heredoc.
payload-indent: every fenced payload in this contract starts at column 0 and states indent: 0; strip nothing; empty payload lines stay empty. A multi-part file is one new file plus consecutive insert-after edits, each anchored on the last line of the previous part.
already-green: criterion 10 (the scoped clean-tree check) passes at HEAD by design, because no file of the unit exists yet; it turns red only when the commit step is skipped.
depends-on: abt-u04 must have landed (verify-checks.sh and the check conventions exist); edit 1 checks for verify-checks.sh and STOPs otherwise. Template T1 already exists at eval/fixtures/toy-lib-template/.
no-real-claude: no command in this contract runs the real claude CLI.
commit-message: feat(abt-u07): E1 ambiguous-tax fixture, prompt, checks and reference (#575)
Co-Authored-By: Claude Sonnet 5.5 <noreply@anthropic.com>
diagnosis: none
review-packet:
~~~
unit: abt-u07 (#575)
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
~~~

## Escalation
If any instruction cannot be followed exactly as written, STOP and report a spec gap; do not improvise.
