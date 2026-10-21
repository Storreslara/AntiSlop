#!/usr/bin/env bash
# Pins knowledgeWrites (aof-u4): schema enum, --update flag, and the scoped-knowledge-writes / scribe-once prose.
set -u
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"
fail=0
ok() { echo "ok   $1"; }
bad() { echo "FAIL $1"; fail=1; }
has() { # <file> <phrase>
  if [ -f "$1" ] && tr -s ' \n' ' ' < "$1" | grep -qF -- "$2"; then ok "$1 $2"; else bad "$1 $2"; fi
}

[ "$(jq -c '.properties.knowledgeWrites.enum' templates/persona-config.schema.json)" = '["scoped","apply"]' ] && ok "schema enum" || bad "schema enum"

T=$(mktemp -d); trap 'rm -rf "$T"' EXIT
git -C "$T" init -q
(cd "$T" && node "$ROOT/bin/cli.js" --personas=spec-master,task-master,reviewer,scribe >/dev/null 2>&1)
C="$T/.claude/persona-config.json"
[ -f "$C" ] && [ "$(jq 'has("knowledgeWrites")' "$C")" = false ] && ok "fresh install has no knowledgeWrites" || bad "fresh install has no knowledgeWrites"
(cd "$T" && node "$ROOT/bin/cli.js" --update --knowledge-writes=apply >/dev/null 2>&1)
[ "$(jq -r .knowledgeWrites "$C")" = apply ] && ok "--knowledge-writes=apply sets key" || bad "--knowledge-writes=apply sets key"
before=$(sha256sum "$C" | cut -d' ' -f1)
if (cd "$T" && node "$ROOT/bin/cli.js" --update --knowledge-writes=bogus >/dev/null 2>&1); then bad "bogus value exits non-zero"; else ok "bogus value exits non-zero"; fi
[ "$(sha256sum "$C" | cut -d' ' -f1)" = "$before" ] && ok "bogus value leaves config unchanged" || bad "bogus value leaves config unchanged"

for f in agents/scribe.md .claude/agents/scribe.md; do has "$f" 'Knowledge writes follow unit scope'; done
for f in agents/spec-master.md .claude/agents/spec-master.md; do has "$f" "otherwise record it in the plan's Scribe update hint as a knowledge proposal"; done
for f in agents/orchestrator.md .claude/agents/orchestrator.md; do
  has "$f" 'dispatches the scribe once, after the last unit'
  has "$f" 'Skip the scribe dispatch entirely when'
done
if tr -s ' \n' ' ' < agents/orchestrator.md | grep -qF 'dispatches the scribe once per unit'; then bad "orchestrator no longer says once per unit"; else ok "orchestrator no longer says once per unit"; fi
exit $fail
