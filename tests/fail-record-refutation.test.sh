#!/usr/bin/env bash
# rfp-u3: the FAIL record's refutation telemetry line and the `[unconfirmed]` prefix leave every reader of
# the record unaffected (fail-count, ladder-tier, escalation-card, unit-outcomes' FAIL classes), and the
# canonical protocol spells the grammar the fixture uses. Fixtures live under mktemp -d only.
set -uo pipefail
cd "$(dirname "$0")/.."
root="$(pwd)"
fail=0
ok()  { echo "OK   $*"; }
bad() { echo "FAIL $*"; fail=1; }

tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT
proj="$tmp/proj"
mkdir -p "$proj/.claude/reviewed"
rec="$proj/.claude/reviewed/u7.fail"
cat > "$rec" <<'EOF'
FAIL u7 2026-02-01T00:00:00Z
tier: haiku
- src/a.sh:2 first defect
- [unconfirmed] src/a.sh:5 second defect
refutation: confirmed=1 refuted=1 uncertain=1

FAIL u7 2026-02-02T00:00:00Z
tier: sonnet
- review-precheck printed a criterion failure line
refutation: skipped=mechanical

EOF

# (a) fail-count counts blocks, not lines
n="$(bash bin/fail-count.sh u7 "$proj")"
[ "$n" = 2 ] && ok "(a) fail-count prints 2" || bad "(a) fail-count printed [$n]"

# (b) ladder-tier reads n=2
lt="$(bash bin/ladder-tier.sh u7 --project "$proj")"
printf '%s' "$lt" | grep -q ' n=2 ' && ok "(b) ladder-tier n=2" || bad "(b) ladder-tier: $lt"

# (c) escalation-card prints each block's first defect line, never the telemetry line
card="$(bash bin/escalation-card.sh u7 "$proj")"
if printf '%s\n' "$card" | grep -qx '  - src/a.sh:2 first defect' \
   && printf '%s\n' "$card" | grep -qx '  - review-precheck printed a criterion failure line' \
   && ! printf '%s\n' "$card" | grep -q 'refutation:'; then
  ok "(c) escalation-card unaffected"
else
  bad "(c) escalation-card: $card"
fi

# (d) no telemetry token matches a unit-outcomes FAIL class substring (read from the live table)
d="$(node -e '
const s = require("fs").readFileSync("scripts/unit-outcomes.js", "utf8");
const m = s.match(/const CLASSES = (\[[\s\S]*?\n\]);/);
if (!m) { console.log("no-classes"); process.exit(0); }
const C = eval(m[1]);
const toks = ["refutation: confirmed=1 refuted=1 uncertain=1", "[unconfirmed]"]
  .concat(["mechanical", "over-cap", "resume", "no-subagent"].map((r) => "refutation: skipped=" + r));
const hits = [];
for (const t of toks) for (const [c, subs] of C) for (const x of subs) if (t.toLowerCase().includes(x)) hits.push(c + ":" + x);
console.log(hits.length ? "hits " + hits.join(",") : "clean");
')"
[ "$d" = clean ] && ok "(d) no FAIL-class collision" || bad "(d) $d"

# (e) every block ends with exactly one well-formed refutation line, and the protocol spells the grammar
shape="$(awk '
  /^FAIL u7 / { if (inb) { print last }; inb = 1; last = ""; next }
  inb && NF > 0 { last = $0 }
  END { if (inb) print last }
' "$rec" | grep -cvE '^refutation: (confirmed=[0-9]+ refuted=[0-9]+ uncertain=[0-9]+|skipped=(mechanical|over-cap|resume|no-subagent))$')"
flat="$(tr -s ' \n' ' ' < templates/persona-protocol.md)"
if [ "$shape" = 0 ] \
   && printf '%s' "$flat" | grep -qF 'then a last line `refutation: confirmed=<a> refuted=<b> uncertain=<c>`, or `refutation: skipped=<mechanical|over-cap|resume|no-subagent>`'; then
  ok "(e) grammar: fixture and canonical protocol agree"
else
  bad "(e) grammar: non-matching last lines=$shape, or the protocol lacks the grammar"
fi

if [ "$fail" -eq 0 ]; then echo "All fail-record-refutation checks passed."; else echo "fail-record-refutation: FAILED"; fi
exit "$fail"
