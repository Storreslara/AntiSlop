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
# A recorded graph launch command keeps explorer.md renderable, so --dry-run can reach its exit code.
jq '.substitutions.graphMcpLaunch = {"command":"npx","args":["code-review-graph-mcp"]}' "$C" > "$C.tmp" && mv "$C.tmp" "$C"
# Reach an already-current project: the first --update bootstraps hashes, the second may still write files.
(cd "$T" && node "$ROOT/bin/cli.js" --update >/dev/null 2>&1)
(cd "$T" && node "$ROOT/bin/cli.js" --update >/dev/null 2>&1)
cur=$(cd "$T" && node "$ROOT/bin/cli.js" --update 2>&1)
case "$cur" in *'already current'*) ok "fixture is already current" ;; *) bad "fixture is already current" ;; esac
tree_sum() { (cd "$T" && find . -path ./.git -prune -o -type f ! -name persona-config.json -print0 | sort -z | xargs -0 sha256sum | sha256sum | cut -d' ' -f1); }
tree_before=$(tree_sum)
(cd "$T" && node "$ROOT/bin/cli.js" --update --knowledge-writes=apply >/dev/null 2>&1)
[ "$(jq -r .knowledgeWrites "$C")" = apply ] && ok "--knowledge-writes=apply sets key" || bad "--knowledge-writes=apply sets key"
before=$(sha256sum "$C" | cut -d' ' -f1)
if (cd "$T" && node "$ROOT/bin/cli.js" --update --knowledge-writes=bogus >/dev/null 2>&1); then bad "bogus value exits non-zero"; else ok "bogus value exits non-zero"; fi
[ "$(sha256sum "$C" | cut -d' ' -f1)" = "$before" ] && ok "bogus value leaves config unchanged" || bad "bogus value leaves config unchanged"
[ "$(jq -r .knowledgeWrites "$C")" = apply ] && ok "bogus value leaves the stored value apply" || bad "bogus value leaves the stored value apply"
[ "$(tree_sum)" = "$tree_before" ] && ok "already-current flag run touches no other file" || bad "already-current flag run touches no other file"
(cd "$T" && node "$ROOT/bin/cli.js" --update --knowledge-writes=scoped >/dev/null 2>&1)
[ "$(jq -r .knowledgeWrites "$C")" = scoped ] && ok "--knowledge-writes=scoped reverts on an already-current project" || bad "--knowledge-writes=scoped reverts on an already-current project"
before=$(sha256sum "$C" | cut -d' ' -f1)
dry=$(cd "$T" && node "$ROOT/bin/cli.js" --update --dry-run --knowledge-writes=apply 2>&1); rc=$?
[ "$rc" = 3 ] && ok "dry-run of a changing flag exits 3" || bad "dry-run of a changing flag exits 3 (got $rc)"
case "$dry" in *'would be set to "apply"'*) ok "dry-run says would be set" ;; *) bad "dry-run says would be set" ;; esac
[ "$(sha256sum "$C" | cut -d' ' -f1)" = "$before" ] && ok "dry-run writes nothing" || bad "dry-run writes nothing"
(cd "$T" && node "$ROOT/bin/cli.js" --update --dry-run --knowledge-writes=scoped >/dev/null 2>&1) && ok "dry-run of an unchanged flag exits 0" || bad "dry-run of an unchanged flag exits 0"

for f in agents/scribe.md .claude/agents/scribe.md; do has "$f" 'Knowledge writes follow unit scope'; done
for f in agents/spec-master.md .claude/agents/spec-master.md; do has "$f" "otherwise record it in the plan's Scribe update hint as a knowledge proposal"; done
for f in agents/orchestrator.md .claude/agents/orchestrator.md; do
  has "$f" 'dispatches the scribe once, after the last unit'
  has "$f" 'Skip the scribe dispatch entirely when'
done
if tr -s ' \n' ' ' < agents/orchestrator.md | grep -qF 'dispatches the scribe once per unit'; then bad "orchestrator no longer says once per unit"; else ok "orchestrator no longer says once per unit"; fi
exit $fail
