#!/usr/bin/env bash
# Deterministic tests for eval/harness/validate-cases.py: runs the validator
# over the (currently empty) registered suites, then proves each of the 13
# named rejection reasons fires via a mutation set built from one hand-built
# valid gold case (never committed under eval/cases/).
set -euo pipefail
cd "$(dirname "$0")/.."
fail=0

ok()  { echo "OK   $1"; }
bad() { echo "FAIL $1"; fail=1; }

VALIDATOR="eval/harness/validate-cases.py"
REGISTRY="eval/registry/reviewer-verdict.yaml"
GIT_C=(-c user.email=eval@example.com -c user.name=eval -c commit.gpgsign=false)

echo "== validator passes over the registered (currently empty) suites =="
if python3 "$VALIDATOR" --registry "$REGISTRY"; then
  ok "validate-cases.py --registry $REGISTRY (empty suites)"
else
  bad "validate-cases.py --registry $REGISTRY (empty suites)"
fi

WORK="$(mktemp -d)"
trap 'rm -rf "$WORK"' EXIT

# --- build one valid gold case as the mutation baseline ---

VALID_ID="valid-case"
VALID_DIR="$WORK/base/$VALID_ID"
mkdir -p "$VALID_DIR"

FIXTURE_COPY="$WORK/fixture-copy"
cp -r eval/fixtures/toy-lib-template "$FIXTURE_COPY"
(cd "$FIXTURE_COPY" && git "${GIT_C[@]}" init -q && git "${GIT_C[@]}" add -A \
  && git "${GIT_C[@]}" commit -qm base)
printf '\nmodule.exports.EVAL_MARKER = true;\n' >> "$FIXTURE_COPY/src/pricing.js"
(cd "$FIXTURE_COPY" && git diff) > "$VALID_DIR/change.patch"

cat > "$VALID_DIR/case.yaml" <<YAML
id: $VALID_ID
suite: reviewer-verdict.gold.v1
fixture: toy-lib-template
task: feature-task
patch: change.patch
packet: packet.md
gold:
  verdict: FAIL
  defects:
    - id: eval-marker-defect
      file: src/pricing.js
      description: Adds an unrequested export not asked for by the task.
tags: [test-mutation-fixture, size:small]
YAML

cat > "$VALID_DIR/packet.md" <<PACKET
Unit: eval-$VALID_ID

## Objective
Synthetic case used only by tests/eval-cases.test.sh's mutation set.

## Acceptance criteria
npm test
PACKET

if python3 "$VALIDATOR" --registry "$REGISTRY" --suite reviewer-verdict.gold.v1 --cases-dir "$WORK/base"; then
  ok "hand-built valid case passes the validator"
else
  bad "hand-built valid case unexpectedly rejected"
fi

# --- mutation helpers ---

new_mutation_dir() {
  # $1 = mutation slug, $2 = dest case dir name (defaults to $VALID_ID)
  local slug="$1" dname="${2:-$VALID_ID}"
  local root="$WORK/mut-$slug"
  local dest="$root/$dname"
  mkdir -p "$dest"
  cp "$VALID_DIR/case.yaml" "$dest/case.yaml"
  cp "$VALID_DIR/change.patch" "$dest/change.patch"
  cp "$VALID_DIR/packet.md" "$dest/packet.md"
  echo "$root"
}

assert_reason() {
  # $1 = cases-dir root  $2 = expected reason substring  $3 = label
  local root="$1" reason="$2" label="$3"
  local out rc
  set +e
  out="$(python3 "$VALIDATOR" --registry "$REGISTRY" --suite reviewer-verdict.gold.v1 --cases-dir "$root" 2>&1)"
  rc=$?
  set -e
  # Output lines are "<case.yaml path>: <reason>"; strip the path and match the
  # reason field exactly, so a reason that also appears in the fixture path
  # (e.g. "$WORK/mut-duplicate-id/...") cannot satisfy the assertion by itself.
  if [ "$rc" -ne 0 ] && printf '%s\n' "$out" | sed 's/.*: //' | command grep -qxF -- "$reason"; then
    ok "$label -> $reason"
  else
    bad "$label -> $reason (rc=$rc out=$out)"
  fi
}

echo
echo "== mutation set: missing-field:<name> (each required gold field removed) =="
for field in id suite fixture task patch packet gold tags; do
  root="$(new_mutation_dir "missing-$field")"
  CASE_PATH="$root/$VALID_ID/case.yaml" FIELD="$field" python3 <<'PY'
import os, yaml
path = os.environ["CASE_PATH"]
c = yaml.safe_load(open(path))
del c[os.environ["FIELD"]]
yaml.safe_dump(c, open(path, "w"))
PY
  assert_reason "$root" "missing-field:$field" "missing $field"
done

echo
echo "== mutation set: remaining 12 named reasons =="

root="$(new_mutation_dir "id-mismatch" "renamed-dir")"
assert_reason "$root" "id-mismatch" "case.yaml id != directory name"

root="$WORK/mut-duplicate-id"
mkdir -p "$root/valid-case-a" "$root/valid-case-b"
for d in a b; do
  cp "$VALID_DIR/case.yaml" "$root/valid-case-$d/case.yaml"
  cp "$VALID_DIR/change.patch" "$root/valid-case-$d/change.patch"
  cp "$VALID_DIR/packet.md" "$root/valid-case-$d/packet.md"
done
assert_reason "$root" "duplicate-id" "two case dirs share the same id"

root="$(new_mutation_dir "bad-suite")"
CASE_PATH="$root/$VALID_ID/case.yaml" python3 <<'PY'
import os, yaml
path = os.environ["CASE_PATH"]
c = yaml.safe_load(open(path))
c["suite"] = "reviewer-verdict.grader.v1"
yaml.safe_dump(c, open(path, "w"))
PY
assert_reason "$root" "bad-suite" "suite field doesn't match the walked suite id"

root="$(new_mutation_dir "bad-verdict")"
CASE_PATH="$root/$VALID_ID/case.yaml" python3 <<'PY'
import os, yaml
path = os.environ["CASE_PATH"]
c = yaml.safe_load(open(path))
c["gold"]["verdict"] = "MAYBE"
yaml.safe_dump(c, open(path, "w"))
PY
assert_reason "$root" "bad-verdict" "verdict is not PASS/FAIL"

root="$(new_mutation_dir "defects-required")"
CASE_PATH="$root/$VALID_ID/case.yaml" python3 <<'PY'
import os, yaml
path = os.environ["CASE_PATH"]
c = yaml.safe_load(open(path))
c["gold"]["defects"] = []
yaml.safe_dump(c, open(path, "w"))
PY
assert_reason "$root" "defects-required" "FAIL verdict with no defects"

root="$(new_mutation_dir "defects-forbidden")"
CASE_PATH="$root/$VALID_ID/case.yaml" python3 <<'PY'
import os, yaml
path = os.environ["CASE_PATH"]
c = yaml.safe_load(open(path))
c["gold"]["verdict"] = "PASS"
yaml.safe_dump(c, open(path, "w"))
PY
assert_reason "$root" "defects-forbidden" "PASS verdict with defects present"

root="$(new_mutation_dir "defect-file-not-in-patch")"
CASE_PATH="$root/$VALID_ID/case.yaml" python3 <<'PY'
import os, yaml
path = os.environ["CASE_PATH"]
c = yaml.safe_load(open(path))
c["gold"]["defects"][0]["file"] = "src/does-not-exist.js"
yaml.safe_dump(c, open(path, "w"))
PY
assert_reason "$root" "defect-file-not-in-patch" "defect file not touched by patch"

root="$(new_mutation_dir "patch-does-not-apply")"
cat > "$root/$VALID_ID/change.patch" <<'PATCH'
diff --git a/src/pricing.js b/src/pricing.js
index 0000000..1111111 100644
--- a/src/pricing.js
+++ b/src/pricing.js
@@ -1,3 +1,4 @@
-this line definitely does not exist in pricing.js
+module.exports.EVAL_MARKER = true;
 function round2(n) {
   return Math.round(n * 100) / 100;
PATCH
assert_reason "$root" "patch-does-not-apply" "patch does not git apply --check cleanly"

root="$(new_mutation_dir "packet-missing")"
rm "$root/$VALID_ID/packet.md"
assert_reason "$root" "packet-missing" "packet file absent"

root="$(new_mutation_dir "packet-lacks-unit-line")"
printf 'No unit line here.\n\n## Objective\nsynthetic\n' > "$root/$VALID_ID/packet.md"
assert_reason "$root" "packet-lacks-unit-line" "packet has no Unit: eval-<id> line"

root="$(new_mutation_dir "packet-leaks-gold")"
{ cat "$VALID_DIR/packet.md"; printf '\ngold: leaked\n'; } > "$root/$VALID_ID/packet.md"
assert_reason "$root" "packet-leaks-gold" "packet leaks the gold: label"

root="$(new_mutation_dir "tag-class-missing")"
CASE_PATH="$root/$VALID_ID/case.yaml" python3 <<'PY'
import os, yaml
path = os.environ["CASE_PATH"]
c = yaml.safe_load(open(path))
c["tags"] = ["size:small"]
yaml.safe_dump(c, open(path, "w"))
PY
assert_reason "$root" "tag-class-missing" "no non-size class tag present"

echo
if [ "$fail" -eq 0 ]; then
  echo "All checks passed."
else
  echo "One or more checks FAILED."
fi
exit "$fail"
