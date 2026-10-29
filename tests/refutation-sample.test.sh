#!/usr/bin/env bash
# rfp-u4: the milestone-auditor's refutation-sample commands count what the plan's Cost model defines
# (prevented FAILs: .pass markers carrying a `NOTE[code]: refuted:` note; FAILs that survived a pass:
# FAIL-block lines starting `refutation: confirmed=`), on a fixture with decoys, and
# agents/milestone-auditor.md and its mirror ship exactly these commands. Fixtures live under mktemp -d only.
set -uo pipefail
cd "$(dirname "$0")/.."
root="$(pwd)"
fail=0
ok()  { echo "OK   $*"; }
bad() { echo "FAIL $*"; fail=1; }

LIST="grep -rnF 'NOTE[code]: refuted: ' --include='*.pass' .claude/reviewed | sort"
PREVENTED="grep -rlF 'NOTE[code]: refuted: ' --include='*.pass' .claude/reviewed | wc -l"
SURVIVED="grep -rh '^refutation: confirmed=' --include='*.fail' .claude/reviewed | wc -l"

tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT
proj="$tmp/proj"
d="$proj/.claude/reviewed"
mkdir -p "$d"
cat > "$d/m1.pass" <<'EOF'
PASS m1 2026-11-01T00:00:00Z commit: none criteria: x
NOTE[code]: refuted: D1 src/a.sh:2 b is unquoted — src/a.sh:1 quotes it — the quote is on this path
NOTE[code]: refuted: D2 src/a.sh:5 no empty check — src/a.sh:4 returns early — it runs first
EOF
cat > "$d/m2.pass" <<'EOF'
PASS m2 2026-11-01T00:00:00Z commit: none criteria: x
NOTE[code]: unconfirmed: D1 src/b.sh:3 maybe racy
NOTE[code]: the wrap width is ragged
EOF
cat > "$d/m3.pass" <<'EOF'
PASS m3 2026-11-01T00:00:00Z commit: none criteria: x
NOTE[code]: refuted: D1 src/c.sh:7 off by one — tests/c.test.sh:12 covers the bound — it fails on the claimed input
EOF
cat > "$d/m4.fail" <<'EOF'
FAIL m4 2026-11-01T00:00:00Z
tier: haiku
- src/d.sh:2 a defect whose prose quotes refutation: confirmed=9 mid-line
refutation: confirmed=1 refuted=0 uncertain=0

FAIL m4 2026-11-02T00:00:00Z
tier: haiku
- review-precheck printed a criterion failure line
refutation: skipped=mechanical

EOF
cat > "$d/m5.fail" <<'EOF'
FAIL m5 2026-11-01T00:00:00Z
tier: sonnet
- src/e.sh:4 first
- [unconfirmed] src/e.sh:9 second
refutation: confirmed=1 refuted=1 uncertain=1

NOTE[code]: refuted: D9 a decoy outside any .pass marker
EOF
cat > "$d/m6.blocked" <<'EOF'
NOTE[code]: refuted: D1 a decoy in a .blocked marker
EOF

run() { (cd "$proj" && bash -c "$1"); }

# (a) the list holds the three refuted notes of the .pass markers, sorted, and no decoy
list="$(run "$LIST")"
want='.claude/reviewed/m1.pass:2:NOTE[code]: refuted: D1 src/a.sh:2 b is unquoted — src/a.sh:1 quotes it — the quote is on this path
.claude/reviewed/m1.pass:3:NOTE[code]: refuted: D2 src/a.sh:5 no empty check — src/a.sh:4 returns early — it runs first
.claude/reviewed/m3.pass:2:NOTE[code]: refuted: D1 src/c.sh:7 off by one — tests/c.test.sh:12 covers the bound — it fails on the claimed input'
[ "$list" = "$want" ] && ok "(a) sample list" || bad "(a) sample list: [$list]"

# (b) prevented FAILs: two .pass markers carry a refuted note (m1 counts once)
p="$(run "$PREVENTED" | tr -d ' ')"
[ "$p" = 2 ] && ok "(b) prevented=2" || bad "(b) prevented=[$p]"

# (c) FAILs that survived a pass: m4's first block and m5; the skipped block and the mid-line quote do not count
f="$(run "$SURVIVED" | tr -d ' ')"
[ "$f" = 2 ] && ok "(c) survived=2" || bad "(c) survived=[$f]"

# (d) the persona source and its mirror ship exactly these three commands and the summary line
for file in agents/milestone-auditor.md .claude/agents/milestone-auditor.md; do
  flat="$(tr -s ' \n' ' ' < "$root/$file")"
  miss=""
  for c in "$LIST" "$PREVENTED" "$SURVIVED" 'refutation-sample: sampled=<s> held=<h> prevented=<p> eligible=<p+f>'; do
    printf '%s' "$flat" | grep -qF -- "$c" || miss="$miss [$c]"
  done
  [ -z "$miss" ] && ok "(d) $file ships the commands" || bad "(d) $file lacks:$miss"
done

if [ "$fail" -eq 0 ]; then echo "All refutation-sample checks passed."; else echo "refutation-sample: FAILED"; fi
exit "$fail"
