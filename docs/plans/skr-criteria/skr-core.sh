#!/usr/bin/env bash
# Usage: skr-core.sh
# The tests/validate.sh sections and suites a skills change can break, run
# standalone (the full validate.sh exceeds the 600 s Bash cap here).
# Exit 0 iff every check passes.
set -uo pipefail
cd "$(git rev-parse --show-toplevel)" || exit 2
fail=0
ok() { echo "OK   $1"; }
no() { echo "FAIL $1"; fail=1; }

for f in skills/*/SKILL.md; do
  grep -q '^name:' "$f" && grep -q '^description:' "$f" && ok "$f frontmatter" || no "$f frontmatter"
done
for f in agents/*.md; do
  line=$(grep '^skills:' "$f" || true)
  for t in $(echo "$line" | grep -oE 'antislop:[a-zA-Z0-9-]+'); do
    [ -f "skills/${t#antislop:}/SKILL.md" ] && ok "$f $t" || no "$f $t unresolved"
  done
  head -1 "$f" | grep -q '^---$' || continue
  python3 -c "
import re, yaml
c = open('$f').read()
m = re.match(r'^---\n(.*?)\n---\n', c, re.S)
yaml.safe_load(m.group(1))" 2>/dev/null && ok "$f yaml" || no "$f yaml"
done
for d in .claude/skills/*/; do
  d=$(basename "$d")
  [ -d "skills/$d" ] || continue
  diff -rq "skills/$d" ".claude/skills/$d" >/dev/null && ok ".claude/skills/$d parity" || no ".claude/skills/$d parity"
done
diff -rq hooks/scripts .claude/hooks/scripts >/dev/null && ok "hook mirror parity" || no "hook mirror parity"

for t in adapter-skill-parity filehashes-currency contract-examples context-glossary-links \
         protocol-cross-references ubiquitous-language protocol-doc-drift \
         effort-tier-consistency adapter-protocol-parity writer-tier-consistency; do
  node "tests/$t.test.js" >/dev/null 2>&1 && ok "tests/$t.test.js" || no "tests/$t.test.js"
done
for t in version-stamp-check heavy-trigger; do
  bash "tests/$t.test.sh" >/dev/null 2>&1 && ok "tests/$t.test.sh" || no "tests/$t.test.sh"
done
[ "$fail" -eq 0 ] && echo "skr-core: ok" || echo "skr-core: FAIL"
[ "$fail" -eq 0 ]
