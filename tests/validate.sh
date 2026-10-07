#!/usr/bin/env bash
# Validates the antislop plugin's own files. Run locally before pushing,
# or via .github/workflows/validate.yml. Exits non-zero on any failure.
# This is a best-effort sanity net for a plugin whose "code" is mostly
# prose/config, not a substitute for the empirical smoke tests noted in
# README.md.
set -uo pipefail
cd "$(dirname "$0")/.."
fail=0
# >>> skip-summary wrapper (hyg-1): re-run this script with its output teed to
# a temp file, then count the lines that start with SKIP. Advisory only: the
# count never changes the exit code. Lines a suite captures and discards never
# reach this output and are not counted.
if [ -z "${ANTISLOP_VALIDATE_INNER:-}" ]; then
  skip_log="$(mktemp)" || { echo "FAIL could not create the SKIP-summary temp file"; exit 1; }
  trap 'rm -f "$skip_log"' EXIT
  trap 'exit 143' TERM
  trap 'exit 130' INT
  ANTISLOP_VALIDATE_INNER=1 bash "tests/$(basename "$0")" "$@" 2>&1 | tee "$skip_log"
  inner_rc=${PIPESTATUS[0]}
  echo
  echo "== skipped checks (advisory, never affects the exit code) =="
  echo "Skipped checks: $(grep -c '^SKIP' "$skip_log")"
  grep '^SKIP' "$skip_log" | sed 's/^/     /'
  exit "$inner_rc"
fi
# <<< skip-summary wrapper

echo "== bash syntax =="
for f in hooks/scripts/*.sh hooks/scripts/lib/*.sh; do
  if bash -n "$f"; then
    echo "OK   $f"
  else
    echo "FAIL $f"
    fail=1
  fi
done

echo
echo "== hook script executable bits =="
# hooks.json (and both adapter ports' hooks.json) invoke these scripts
# DIRECTLY, with no `bash` prefix, so a lost +x silently disables that gate
# (issue #273; regressed twice inside unit #262). */lib/*.sh are sourced,
# never executed, and are 644 by design - the non-recursing glob excludes
# them.
for d in hooks/scripts adapters/codex/hooks/scripts adapters/cursor/hooks/scripts; do
  n=0
  for f in "$d"/*.sh; do
    [ -e "$f" ] || break
    n=$((n + 1))
    if [ -x "$f" ]; then
      echo "OK   $f executable"
    else
      echo "FAIL $f is not executable (invoked directly; a lost +x disables this gate)"
      fail=1
    fi
  done
  if [ "$n" -eq 0 ]; then
    echo "FAIL no *.sh found under $d/ - executable-bit check would be vacuous"
    fail=1
  fi
done
# The git index is what actually ships, and it is immune to a checkout
# filesystem that cannot represent the bit.
if git rev-parse --is-inside-work-tree >/dev/null 2>&1; then
  bad=$(git ls-files -s hooks/scripts adapters/codex/hooks/scripts adapters/cursor/hooks/scripts \
        | grep -v '/lib/' | awk '$1 != "100755" { print $1 "  " $4 }')
  if [ -z "$bad" ]; then
    echo "OK   git index records mode 100755 for every directly-invoked hook script"
  else
    echo "FAIL git index records a non-executable mode:"
    echo "$bad"
    fail=1
  fi
else
  echo "SKIP git index mode check (not inside a git work tree)"
fi

echo
echo "== JSON validity =="
for f in .claude-plugin/plugin.json .claude-plugin/marketplace.json hooks/hooks.json \
         templates/persona-config.schema.json templates/settings-fragment.json; do
  if python3 -m json.tool "$f" >/dev/null 2>&1; then
    echo "OK   $f"
  else
    echo "FAIL $f"
    fail=1
  fi
done

echo
echo "== package.json / plugin.json version sync =="
pkg_version=$(python3 -c "import json; print(json.load(open('package.json'))['version'])")
plugin_version=$(python3 -c "import json; print(json.load(open('.claude-plugin/plugin.json'))['version'])")
if [ "$pkg_version" = "$plugin_version" ]; then
  echo "OK   package.json version ($pkg_version) matches .claude-plugin/plugin.json version ($plugin_version)"
else
  echo "FAIL package.json version ($pkg_version) != .claude-plugin/plugin.json version ($plugin_version)"
  fail=1
fi

echo
echo "== npm pack: dev-scratch dirs excluded, shipped dirs included =="
if npm pack --dry-run --json 2>/dev/null | python3 -c "
import json, sys
files = [f['path'] for f in json.load(sys.stdin)[0]['files']]
excluded = ['docs/', 'eval/', 'prototype/', 'specs/', '.claude/']
included = ['agents/', 'hooks/', 'templates/', 'skills/']
present = [d for d in excluded if any(f.startswith(d) for f in files)]
missing = [d for d in included if not any(f.startswith(d) for f in files)]
if present or missing:
    sys.stderr.write('excluded-dirs-present=%s included-dirs-missing=%s\n' % (present, missing))
    sys.exit(1)
" 2>/tmp/npm_pack_err; then
  echo "OK   npm pack tarball excludes dev-scratch dirs, includes shipped dirs"
else
  echo "FAIL npm pack tarball composition ($(cat /tmp/npm_pack_err))"
  fail=1
fi
rm -f /tmp/npm_pack_err

echo
echo "== marketplace.json / plugin.json consistency =="
if python3 -c "
import json
plugin = json.load(open('.claude-plugin/plugin.json'))
marketplace = json.load(open('.claude-plugin/marketplace.json'))
entries = [p for p in marketplace['plugins'] if p.get('name') == plugin['name']]
assert entries, 'no marketplace entry named %r' % plugin['name']
assert entries[0].get('source') == './', 'marketplace entry source is %r, expected \"./\"' % entries[0].get('source')
" 2>/tmp/marketplace_err; then
  echo "OK   marketplace.json plugin entry matches plugin.json name and source"
else
  echo "FAIL marketplace.json / plugin.json mismatch ($(cat /tmp/marketplace_err | tail -1))"
  fail=1
fi
rm -f /tmp/marketplace_err

echo
echo "== claude plugin tag (advisory - cross-validates plugin.json vs marketplace entry; run manually before release) =="
source tests/lib/claude-tag-filter.sh
if command -v claude >/dev/null 2>&1; then
  claude plugin tag --dry-run >/tmp/claude_plugin_tag_out 2>&1
  claude_tag_residual=$(filter_known_claude_tag_noise </tmp/claude_plugin_tag_out)
  if [ -z "$claude_tag_residual" ]; then
    echo "OK   claude plugin tag --dry-run (known-permanent notices suppressed)"
  else
    echo "WARN claude plugin tag --dry-run reported an issue (advisory only, not failing this run):"
    echo "$claude_tag_residual" | sed 's/^/     /'
  fi
else
  echo "SKIP (claude CLI not on PATH - run \`claude plugin tag --dry-run\` manually before release)"
fi
rm -f /tmp/claude_plugin_tag_out

echo
echo "== claude plugin tag noise-filter fixture test (Bash) =="
if bash tests/claude-tag-filter.test.sh; then
  echo "OK   tests/claude-tag-filter.test.sh"
else
  echo "FAIL tests/claude-tag-filter.test.sh"
  fail=1
fi

echo
echo "== agent/template frontmatter has name: and description: =="
for f in agents/*.md templates/researcher.md.tmpl; do
  if grep -q '^name:' "$f" && grep -q '^description:' "$f"; then
    echo "OK   $f"
  else
    echo "FAIL $f (missing name: or description: in frontmatter)"
    fail=1
  fi
done

echo
echo "== agent frontmatter parses as valid YAML =="
# Catches an unquoted plain scalar containing a ": " (colon-space) sequence,
# which YAML's grammar treats as a nested mapping key and fails to parse -
# e.g. an unescaped 'description: ... ("agent": "orchestrator") ...' (#276).
for f in agents/*.md templates/*.md.tmpl; do
  head -1 "$f" | grep -q '^---$' || continue
  if python3 -c "
import re, sys, yaml
c = open('$f').read()
m = re.match(r'^---\n(.*?)\n---\n', c, re.S)
assert m, 'no frontmatter block found'
yaml.safe_load(m.group(1))
" 2>/tmp/frontmatter_yaml_err; then
    echo "OK   $f"
  else
    echo "FAIL $f ($(cat /tmp/frontmatter_yaml_err | tail -1))"
    fail=1
  fi
done
rm -f /tmp/frontmatter_yaml_err

echo
echo "== reviewer/task-master: cacheTtl nested under experimental:, not top-level =="
# Claude Code only recognizes this field under experimental: - a top-level
# cacheTtl: is silently dropped (see cache-ttl-gapped-personas Defect 1).
for f in agents/reviewer.md agents/task-master.md; do
  if grep -qE '^cacheTtl:' "$f"; then
    echo "FAIL $f (cacheTtl at top level of frontmatter - must nest under experimental:)"
    fail=1
  elif grep -qE '^experimental:' "$f" && grep -qE '^ +cacheTtl: 1h' "$f"; then
    echo "OK   $f"
  else
    echo "FAIL $f (missing experimental:/cacheTtl: 1h nesting)"
    fail=1
  fi
done

echo
echo "== skill frontmatter has name: and description: =="
for f in skills/*/SKILL.md; do
  if grep -q '^name:' "$f" && grep -q '^description:' "$f"; then
    echo "OK   $f"
  else
    echo "FAIL $f (missing name: or description: in frontmatter)"
    fail=1
  fi
done

echo
echo "== agents/*.md skills: frontmatter tokens resolve to skills/<x>/SKILL.md =="
for f in agents/*.md; do
  line=$(grep '^skills:' "$f" || true)
  [ -z "$line" ] && continue
  for t in $(echo "$line" | grep -oE 'antislop:[a-zA-Z0-9-]+'); do
    slug="${t#antislop:}"
    if [ -f "skills/$slug/SKILL.md" ]; then
      echo "OK   $f: $t -> skills/$slug/SKILL.md"
    else
      echo "FAIL $f: $t has no skills/$slug/SKILL.md"
      fail=1
    fi
  done
done

echo
echo "== optional-persona references must be phrased conditionally =="
# scribe/reviewer/researcher are opt-out (see README.md); a bare
# unconditional reference to one of them is exactly the class of bug that
# hard-errors when a project skips that persona. Checked per-PARAGRAPH
# (blank-line-separated, wrapped lines joined) rather than per physical line,
# since a conditional qualifier often lands on the next wrapped line.
# NOTE: spec-master/task-master are also opt-out but deliberately excluded
# from this loop — agents/orchestrator.md references them far more densely,
# with "(if present)" qualifiers scoped per-section rather than repeated
# every paragraph, which this paragraph-scoped checker would false-positive
# on.
for p in scribe reviewer researcher agent-auditor; do
  bad=0
  for f in agents/orchestrator.md agents/lead-programmer.md commands/start-feature-team.md; do
    [ -f "$f" ] || continue
    while IFS= read -r para; do
      case "$para" in
        *"\`$p\`"*)
          case "$para" in
            *"if present"*|*"this project"*|*"it exists"*|*"doesn't exist"*|*"does not exist"*|*"otherwise"*|*"if there's no"*|*"if there is no"*|*"if no "*)
              ;;
            *)
              echo "FAIL: unconditional reference to optional persona '$p' in $f:"
              echo "  $para"
              bad=1
              ;;
          esac
          ;;
      esac
    done < <(awk -v RS='' '{gsub(/\n/, " "); print}' "$f")
  done
  [ "$bad" -eq 0 ] && echo "OK   all references to '$p' are conditionally phrased" || fail=1
done

echo
echo "== Cursor adapter: bash syntax =="
for f in adapters/cursor/hooks/scripts/*.sh adapters/cursor/hooks/scripts/lib/*.sh; do
  if bash -n "$f"; then
    echo "OK   $f"
  else
    echo "FAIL $f"
    fail=1
  fi
done

echo
echo "== Cursor adapter: JSON validity =="
for f in adapters/cursor/hooks/hooks.json \
         adapters/cursor/.cursor-plugin/plugin.json \
         adapters/cursor/.cursor-plugin/marketplace.json; do
  if python3 -m json.tool "$f" >/dev/null 2>&1; then
    echo "OK   $f"
  else
    echo "FAIL $f"
    fail=1
  fi
done

echo
echo "== Cursor adapter: agent/rule frontmatter has name/description or alwaysApply =="
for f in adapters/cursor/agents/*.md; do
  if grep -q '^name:' "$f" && grep -q '^description:' "$f"; then
    echo "OK   $f"
  else
    echo "FAIL $f (missing name: or description: in frontmatter)"
    fail=1
  fi
done
if grep -q '^alwaysApply:' adapters/cursor/rules/persona-protocol.mdc; then
  echo "OK   adapters/cursor/rules/persona-protocol.mdc"
else
  echo "FAIL adapters/cursor/rules/persona-protocol.mdc (missing alwaysApply:)"
  fail=1
fi

echo
echo "== Codex adapter: bash syntax =="
for f in adapters/codex/hooks/scripts/*.sh adapters/codex/hooks/scripts/lib/*.sh; do
  if bash -n "$f"; then
    echo "OK   $f"
  else
    echo "FAIL $f"
    fail=1
  fi
done

echo
echo "== shared hook libs: three platform copies byte-identical =="
# The agent-identity library is byte-identical by design (it derives its
# recognized namespace from its own on-disk location rather than a per-platform
# path), so any divergence between the copies is drift, not a port.
for f in adapters/cursor/hooks/scripts/lib/agent-identity.sh \
         adapters/codex/hooks/scripts/lib/agent-identity.sh; do
  if diff -q hooks/scripts/lib/agent-identity.sh "$f" >/dev/null 2>&1; then
    echo "OK   $f byte-identical to hooks/scripts/lib/agent-identity.sh"
  else
    echo "FAIL $f differs from hooks/scripts/lib/agent-identity.sh"
    fail=1
  fi
done

echo
echo "== this repo's hook-script mirror is at parity with hooks/scripts/ =="
# Since 0.31.28 `--update` manages `.claude/hooks/scripts/**` as content-hash-
# tracked files. A mirror that drifts freezes this repo's own gates at an old
# version, which is exactly the defect that made the standalone gap invisible.
if diff -rq hooks/scripts .claude/hooks/scripts; then
  echo "OK   .claude/hooks/scripts is byte-identical to hooks/scripts"
else
  echo "FAIL .claude/hooks/scripts diverged from hooks/scripts (run \`node bin/cli.js --update\`)"
  fail=1
fi

echo
echo "== .claude/skills mirrors are at parity with skills/ =="
for d in .claude/skills/*/; do
  d=$(basename "$d")
  if [ ! -d "skills/$d" ]; then
    echo "SKIP .claude/skills/$d (no skills/ source; graph-generated)"
  elif diff -rq "skills/$d" ".claude/skills/$d"; then
    echo "OK   .claude/skills/$d is byte-identical to skills/$d"
  else
    echo "FAIL .claude/skills/$d diverged from skills/$d (copy skills/$d over it and commit both)"
    fail=1
  fi
done

echo
echo "== persona-config fileHashes baselines match on-disk content =="
if node tests/filehashes-currency.test.js; then
  echo "OK   tests/filehashes-currency.test.js"
else
  echo "FAIL tests/filehashes-currency.test.js"
  fail=1
fi

echo
echo "== agent-identity library: identity_drift_log behaviour (Bash) =="
if bash tests/agent-identity-lib.test.sh; then
  echo "OK   tests/agent-identity-lib.test.sh"
else
  echo "FAIL tests/agent-identity-lib.test.sh"
  fail=1
fi

echo
echo "== harness_armed: six trust gates refuse a config-deleted adapted project (Bash) =="
if bash tests/harness-arm.test.sh; then
  echo "OK   tests/harness-arm.test.sh"
else
  echo "FAIL tests/harness-arm.test.sh"
  fail=1
fi

echo
echo "== harness-integrity-gate.sh: configless write-deny on the harness's own control surface (Bash) =="
if bash tests/harness-integrity-gate.test.sh; then
  echo "OK   tests/harness-integrity-gate.test.sh"
else
  echo "FAIL tests/harness-integrity-gate.test.sh"
  fail=1
fi

echo
echo "== audit-log.sh: audit_append/audit_seal_verify/audit_rotate (Bash, item15-2) =="
if bash tests/audit-seal.test.sh; then
  echo "OK   tests/audit-seal.test.sh"
else
  echo "FAIL tests/audit-seal.test.sh"
  fail=1
fi

echo
echo "== bin/audit-seal-verify.sh: seal-verification consumer, mutation-proven (Bash, item15-2) =="
if bash tests/audit-seal-verify.test.sh; then
  echo "OK   tests/audit-seal-verify.test.sh"
else
  echo "FAIL tests/audit-seal-verify.test.sh"
  fail=1
fi

echo
echo "== bin/harness-integrity.sh --self-report tally, wired into session-start.sh (Bash) =="
if bash tests/self-report-tally.test.sh; then
  echo "OK   tests/self-report-tally.test.sh"
else
  echo "FAIL tests/self-report-tally.test.sh"
  fail=1
fi

echo
echo "== disarm-surface config-drift comparison (Step 4) (Bash) =="
if bash tests/harness-config-drift.test.sh; then
  echo "OK   tests/harness-config-drift.test.sh"
else
  echo "FAIL tests/harness-config-drift.test.sh"
  fail=1
fi
if bash tests/harness-config-drift.test.sh --session-start; then
  echo "OK   tests/harness-config-drift.test.sh --session-start"
else
  echo "FAIL tests/harness-config-drift.test.sh --session-start"
  fail=1
fi

echo
echo "== stop-gate.sh: gated SubagentStop blocks on disarm-surface config drift (Step 4, RD3) (Bash) =="
if bash tests/stop-gate-config-drift.test.sh; then
  echo "OK   tests/stop-gate-config-drift.test.sh"
else
  echo "FAIL tests/stop-gate-config-drift.test.sh"
  fail=1
fi

echo
echo "== refusal-disclosure hygiene: reviewed-path-gate.sh / human-decision-gate.sh denial stderr (Bash) =="
if bash tests/refusal-disclosure.test.sh; then
  echo "OK   tests/refusal-disclosure.test.sh"
else
  echo "FAIL tests/refusal-disclosure.test.sh"
  fail=1
fi

echo
echo "== stop-gate .blocked-marker behaviour (Bash) =="
if bash tests/stop-gate-blocked.test.sh; then
  echo "OK   tests/stop-gate-blocked.test.sh"
else
  echo "FAIL tests/stop-gate-blocked.test.sh"
  fail=1
fi

echo
echo "== stop-gate .escalated-marker behaviour (Bash) =="
if bash tests/stop-gate-escalated.test.sh; then
  echo "OK   tests/stop-gate-escalated.test.sh"
else
  echo "FAIL tests/stop-gate-escalated.test.sh"
  fail=1
fi

echo
echo "== reviewGating.mode off: stop-gate + reviewer-route-gate review enforcement inert (Bash) =="
if bash tests/review-gating-off.test.sh; then
  echo "OK   tests/review-gating-off.test.sh"
else
  echo "FAIL tests/review-gating-off.test.sh"
  fail=1
fi

echo
echo "== SessionStart microworld layer status reporting (Bash) =="
if bash tests/session-start-microworld-status.test.sh; then
  echo "OK   tests/session-start-microworld-status.test.sh"
else
  echo "FAIL tests/session-start-microworld-status.test.sh"
  fail=1
fi

echo
echo "== stop-gate deferred microworld result surfacing (Bash, Unit A) =="
if bash tests/stop-gate-deferred-microworld.test.sh; then
  echo "OK   tests/stop-gate-deferred-microworld.test.sh"
else
  echo "FAIL tests/stop-gate-deferred-microworld.test.sh"
  fail=1
fi

echo
echo "== stop-gate testAndLintCommand skip precondition (Bash, Unit B) =="
if bash tests/stop-gate-microworld-skip.test.sh; then
  echo "OK   tests/stop-gate-microworld-skip.test.sh"
else
  echo "FAIL tests/stop-gate-microworld-skip.test.sh"
  fail=1
fi

echo
echo "== microworld reactive rerun hook + relocation proof (Bash) =="
if bash tests/microworld/microworld-rerun.test.sh; then
  echo "OK   tests/microworld/microworld-rerun.test.sh"
else
  echo "FAIL tests/microworld/microworld-rerun.test.sh"
  fail=1
fi

echo
echo "== timing harness assert_budget discriminates on budget (Bash) =="
if bash tests/timing-harness.test.sh; then
  echo "OK   tests/timing-harness.test.sh"
else
  echo "FAIL tests/timing-harness.test.sh"
  fail=1
fi

echo
echo "== PostToolUse latency budget, real hooks + watch-map (Bash, Unit A AC-A1) =="
if bash tests/hook-latency-budget.test.sh; then
  echo "OK   tests/hook-latency-budget.test.sh"
else
  echo "FAIL tests/hook-latency-budget.test.sh"
  fail=1
fi

echo
echo "== watch-map.json run[] commands are registered in tests/validate.sh (Bash) =="
if bash tests/watch-map-registration.test.sh; then
  echo "OK   tests/watch-map-registration.test.sh"
else
  echo "FAIL tests/watch-map-registration.test.sh"
  fail=1
fi

echo
echo "== microworld audit log contract test: bash hook ↔ Node parser (Node) =="
if node tests/microworld/microworld-audit-contract.test.js; then
  echo "OK   tests/microworld/microworld-audit-contract.test.js"
else
  echo "FAIL tests/microworld/microworld-audit-contract.test.js"
  fail=1
fi

echo
echo "== reviewer-route-gate review-join stamps (Bash) =="
if bash tests/review-join.test.sh; then
  echo "OK   tests/review-join.test.sh"
else
  echo "FAIL tests/review-join.test.sh"
  fail=1
fi

echo
echo "== pending-review flag resurrection (Bash) =="
if bash tests/pending-review-resurrection.test.sh; then
  echo "OK   tests/pending-review-resurrection.test.sh"
else
  echo "FAIL tests/pending-review-resurrection.test.sh"
  fail=1
fi

echo
echo "== reviewer-route-gate caller allowlist (Bash) =="
if bash tests/reviewer-route-gate-caller.test.sh; then
  echo "OK   tests/reviewer-route-gate-caller.test.sh"
else
  echo "FAIL tests/reviewer-route-gate-caller.test.sh"
  fail=1
fi

echo
echo "== adapter stop-gate behavioural parity: claude/codex/cursor (Bash) =="
if bash tests/adapter-stop-gate-parity.test.sh; then
  echo "OK   tests/adapter-stop-gate-parity.test.sh"
else
  echo "FAIL tests/adapter-stop-gate-parity.test.sh"
  fail=1
fi

echo
echo "== dispatch-hygiene token gate: H1/H2/H3 behaviour (Bash) =="
if bash tests/dispatch-hygiene.test.sh; then
  echo "OK   tests/dispatch-hygiene.test.sh"
else
  echo "FAIL tests/dispatch-hygiene.test.sh"
  fail=1
fi

echo
echo "== reviewed-path gate: write-intent allowlist + Write/Edit path (Bash) =="
if bash tests/reviewed-path-gate.test.sh; then
  echo "OK   tests/reviewed-path-gate.test.sh"
else
  echo "FAIL tests/reviewed-path-gate.test.sh"
  fail=1
fi

echo
echo "== human-decision gate: DECISION unwritable + sanctioned marker-write template (Bash) =="
if bash tests/human-decision-gate.test.sh; then
  echo "OK   tests/human-decision-gate.test.sh"
else
  echo "FAIL tests/human-decision-gate.test.sh"
  fail=1
fi

echo
echo "== marker-commit-check classifier: ok/mismatch/unverifiable states (Bash) =="
if bash tests/marker-commit-check.test.sh; then
  echo "OK   tests/marker-commit-check.test.sh"
else
  echo "FAIL tests/marker-commit-check.test.sh"
  fail=1
fi

echo
echo "== marker-commit-audit: enumerate and report on all .pass markers (Bash) =="
if bash tests/marker-commit-audit.test.sh; then
  echo "OK   tests/marker-commit-audit.test.sh"
else
  echo "FAIL tests/marker-commit-audit.test.sh"
  fail=1
fi

echo
echo "== marker-verify: --list/--execute re-run of a marker's criteria (Bash) =="
if bash tests/marker-verify.test.sh; then
  echo "OK   tests/marker-verify.test.sh"
else
  echo "FAIL tests/marker-verify.test.sh"
  fail=1
fi

echo
echo "== marker-write: single-call PASS/FAIL/BLOCKED helper (Bash, spec2-unitC) =="
if bash tests/marker-write.test.sh; then
  echo "OK   tests/marker-write.test.sh"
else
  echo "FAIL tests/marker-write.test.sh"
  fail=1
fi

echo
echo "== fail-count: deterministic FAIL-block count command (Bash, item12-2) =="
if bash tests/fail-count.test.sh; then
  echo "OK   tests/fail-count.test.sh"
else
  echo "FAIL tests/fail-count.test.sh"
  fail=1
fi

echo
echo "== fail-marker-format-parity: heredoc vs marker-write.sh (Bash, item12-4) =="
if bash tests/fail-marker-format-parity.test.sh; then
  echo "OK   tests/fail-marker-format-parity.test.sh"
else
  echo "FAIL tests/fail-marker-format-parity.test.sh"
  fail=1
fi

echo
echo "== human-review-cleanup: resolved-packet sweep (Bash) =="
if bash tests/human-review-cleanup.test.sh; then
  echo "OK   tests/human-review-cleanup.test.sh"
else
  echo "FAIL tests/human-review-cleanup.test.sh"
  fail=1
fi

echo
echo "== agent-identity namespacing across gate sites S1-S13 (Bash) =="
if bash tests/agent-identity-namespace.test.sh; then
  echo "OK   tests/agent-identity-namespace.test.sh"
else
  echo "FAIL tests/agent-identity-namespace.test.sh"
  fail=1
fi

echo
echo "== reviewer-tier: fail-closed tier selection + boundary sweep (Bash) =="
if bash tests/reviewer-tier.test.sh; then
  echo "OK   tests/reviewer-tier.test.sh"
else
  echo "FAIL tests/reviewer-tier.test.sh"
  fail=1
fi

echo
echo "== task-gate: TaskCompleted PASS-marker gate (Bash, gate-audit-step5) =="
if bash tests/task-gate.test.sh; then
  echo "OK   tests/task-gate.test.sh"
else
  echo "FAIL tests/task-gate.test.sh"
  fail=1
fi

echo
echo "== heavy-trigger: deterministic measured heavy-unit surface script (Bash) =="
if bash tests/heavy-trigger.test.sh; then
  echo "OK   tests/heavy-trigger.test.sh"
else
  echo "FAIL tests/heavy-trigger.test.sh"
  fail=1
fi

echo
echo "== version-stamp-check: agents/templates diff requires a plugin.json version bump (Bash) =="
if bash tests/version-stamp-check.test.sh; then
  echo "OK   tests/version-stamp-check.test.sh"
else
  echo "FAIL tests/version-stamp-check.test.sh"
  fail=1
fi

echo
echo "== scribe issue-closing duty: trigger/never-close conditions (Bash) =="
if bash tests/scribe-issue-closing.test.sh; then
  echo "OK   tests/scribe-issue-closing.test.sh"
else
  echo "FAIL tests/scribe-issue-closing.test.sh"
  fail=1
fi

echo "== agent-audit.sh test fixtures + mutation proof (Bash) =="
if bash tests/agent-auditor.test.sh; then
  echo "OK   tests/agent-auditor.test.sh"
else
  echo "FAIL tests/agent-auditor.test.sh"
  fail=1
fi
echo
echo "== session-start.sh version-direction message =="
if bash tests/session-start-version-direction.test.sh; then
  echo "OK   tests/session-start-version-direction.test.sh"
else
  echo "FAIL tests/session-start-version-direction.test.sh"
  fail=1
fi
echo
echo "== Codex adapter: JSON validity =="
for f in adapters/codex/hooks/hooks.json \
         adapters/codex/.codex-plugin/plugin.json \
         adapters/codex/.codex-plugin/marketplace.json; do
  if python3 -m json.tool "$f" >/dev/null 2>&1; then
    echo "OK   $f"
  else
    echo "FAIL $f"
    fail=1
  fi
done

echo
echo "== Codex adapter: TOML validity + name/description present =="
if python3 -c "import tomllib" >/dev/null 2>&1; then
  for f in adapters/codex/agents/*.toml; do
    if python3 -c "
import sys, tomllib
with open('$f', 'rb') as fh:
    d = tomllib.load(fh)
assert 'name' in d and d['name'], 'missing name'
assert 'description' in d and d['description'], 'missing description'
assert 'developer_instructions' in d and d['developer_instructions'].strip(), 'missing developer_instructions'
" 2>/tmp/codex_toml_err; then
      echo "OK   $f"
    else
      echo "FAIL $f ($(cat /tmp/codex_toml_err | tail -1))"
      fail=1
    fi
  done
  rm -f /tmp/codex_toml_err
else
  echo "SKIP (no python3 tomllib available - needs Python 3.11+; TOML validity not checked this run)"
fi

echo
echo "== Codex adapter: agents-md-fragment.md is clean of scaffold-time markers =="
# The ANTISLOP:BEGIN/END markers are added by bin/cli.js's upsertMarkedBlock
# at scaffold time (with a version number baked in) - the SOURCE fragment
# must never bake them in itself, or a scaffold run would nest one pair
# inside another instead of doing a clean version-agnostic replace.
if grep -q 'ANTISLOP:BEGIN\|ANTISLOP:END' adapters/codex/agents-md-fragment.md; then
  echo "FAIL adapters/codex/agents-md-fragment.md contains a literal ANTISLOP:BEGIN/END marker - remove it, markers are scaffold-time-only"
  fail=1
else
  echo "OK   adapters/codex/agents-md-fragment.md"
fi

echo
echo "== bin/cli.js legacy-backfill logic (Node) =="
if node tests/cli-backfill.test.js; then
  echo "OK   tests/cli-backfill.test.js"
else
  echo "FAIL tests/cli-backfill.test.js"
  fail=1
fi

echo
echo "== bin/cli.js --update hook-script propagation (Node) =="
if node tests/cli-hook-propagation.test.js; then
  echo "OK   tests/cli-hook-propagation.test.js"
else
  echo "FAIL tests/cli-hook-propagation.test.js"
  fail=1
fi

echo
echo "== adapter protocol-port parity vs canonical template (Node) =="
if node tests/adapter-protocol-parity.test.js; then
  echo "OK   tests/adapter-protocol-parity.test.js"
else
  echo "FAIL tests/adapter-protocol-parity.test.js"
  fail=1
fi

echo
echo "== adapter inlined-skill byte-parity vs skills/ (Node) =="
if node tests/adapter-skill-parity.test.js; then
  echo "OK   tests/adapter-skill-parity.test.js"
else
  echo "FAIL tests/adapter-skill-parity.test.js"
  fail=1
fi

echo
echo "== protocol cross-references: no dangling section reference (Node) =="
if node tests/protocol-cross-references.test.js; then
  echo "OK   tests/protocol-cross-references.test.js"
else
  echo "FAIL tests/protocol-cross-references.test.js"
  fail=1
fi

echo
echo "== writer-tier consistency: sonnet default stated consistently across surfaces (Node) =="
if node tests/writer-tier-consistency.test.js; then
  echo "OK   tests/writer-tier-consistency.test.js"
else
  echo "FAIL tests/writer-tier-consistency.test.js"
  fail=1
fi

echo
echo "== default-implementer-model: defaultImplementerModel field + precedence (Node) =="
if node tests/default-implementer-model.test.js; then
  echo "OK   tests/default-implementer-model.test.js"
else
  echo "FAIL tests/default-implementer-model.test.js"
  fail=1
fi

echo
echo "== effort-tier consistency: effort: frontmatter tiers stated consistently across source + mirror (Node) =="
if node tests/effort-tier-consistency.test.js; then
  echo "OK   tests/effort-tier-consistency.test.js"
else
  echo "FAIL tests/effort-tier-consistency.test.js"
  fail=1
fi

echo
echo "== trust-model bijection: docs/trust-model.md vs hooks/scripts/*.sh (Node) =="
if node tests/trust-model-bijection.test.js; then
  echo "OK   tests/trust-model-bijection.test.js"
else
  echo "FAIL tests/trust-model-bijection.test.js"
  fail=1
fi

echo
echo "== protocol doc-drift: CONTEXT.md/wiki section counts vs live templates (Node) =="
if node tests/protocol-doc-drift.test.js; then
  echo "OK   tests/protocol-doc-drift.test.js"
else
  echo "FAIL tests/protocol-doc-drift.test.js"
  fail=1
fi

echo
echo "== ubiquitous-language SKILL.md structural/distinguishability checks (Node) =="
if node tests/ubiquitous-language.test.js; then
  echo "OK   tests/ubiquitous-language.test.js"
else
  echo "FAIL tests/ubiquitous-language.test.js"
  fail=1
fi

echo
echo "== CONTEXT.md / docs/harness-glossary.md: [[link]] integrity (Node) =="
if node tests/context-glossary-links.test.js; then
  echo "OK   tests/context-glossary-links.test.js"
else
  echo "FAIL tests/context-glossary-links.test.js"
  fail=1
fi

echo
echo "== microworld dashboard server (Node) =="
if node tests/microworld/dashboard-server.test.js; then
  echo "OK   tests/microworld/dashboard-server.test.js"
else
  echo "FAIL tests/microworld/dashboard-server.test.js"
  fail=1
fi

echo
echo "== microworld dashboard client (Node) =="
if node tests/microworld/dashboard-client.test.js; then
  echo "OK   tests/microworld/dashboard-client.test.js"
else
  echo "FAIL tests/microworld/dashboard-client.test.js"
  fail=1
fi

echo
echo "== microworld dashboard invoke (Node) =="
if node tests/microworld/dashboard-invoke.test.js; then
  echo "OK   tests/microworld/dashboard-invoke.test.js"
else
  echo "FAIL tests/microworld/dashboard-invoke.test.js"
  fail=1
fi

echo
echo "== microworld dashboard notebook (Node) =="
if node tests/microworld/dashboard-notebook.test.js; then
  echo "OK   tests/microworld/dashboard-notebook.test.js"
else
  echo "FAIL tests/microworld/dashboard-notebook.test.js"
  fail=1
fi

echo
echo "== microworld dashboard feedback (Node) =="
if node tests/microworld/dashboard-feedback.test.js; then
  echo "OK   tests/microworld/dashboard-feedback.test.js"
else
  echo "FAIL tests/microworld/dashboard-feedback.test.js"
  fail=1
fi

echo
echo "== microworld dashboard packets (Node) =="
if node tests/microworld/dashboard-packets.test.js; then
  echo "OK   tests/microworld/dashboard-packets.test.js"
else
  echo "FAIL tests/microworld/dashboard-packets.test.js"
  fail=1
fi

echo
echo "== microworld dashboard decisions (Node) =="
if node tests/microworld/dashboard-decisions.test.js; then
  echo "OK   tests/microworld/dashboard-decisions.test.js"
else
  echo "FAIL tests/microworld/dashboard-decisions.test.js"
  fail=1
fi

echo
echo "== microworld dashboard decision-block (Node) =="
if node tests/microworld/dashboard-decision-block.test.js; then
  echo "OK   tests/microworld/dashboard-decision-block.test.js"
else
  echo "FAIL tests/microworld/dashboard-decision-block.test.js"
  fail=1
fi

echo
echo "== microworld dashboard markdown-lite (Node) =="
if node tests/microworld/dashboard-markdown-lite.test.js; then
  echo "OK   tests/microworld/dashboard-markdown-lite.test.js"
else
  echo "FAIL tests/microworld/dashboard-markdown-lite.test.js"
  fail=1
fi

echo
echo "== microworld dashboard decisions client (Node) =="
if node tests/microworld/dashboard-decisions-client.test.js; then
  echo "OK   tests/microworld/dashboard-decisions-client.test.js"
else
  echo "FAIL tests/microworld/dashboard-decisions-client.test.js"
  fail=1
fi

echo "== microworld dashboard decision-run (Node) =="
if node tests/microworld/dashboard-decision-run.test.js; then
  echo "OK   tests/microworld/dashboard-decision-run.test.js"
else
  echo "FAIL tests/microworld/dashboard-decision-run.test.js"
  fail=1
fi

echo
echo "== microworld dashboard capability register bijection (Node) =="
if node tests/microworld/dashboard-capability-register.test.js; then
  echo "OK   tests/microworld/dashboard-capability-register.test.js"
else
  echo "FAIL tests/microworld/dashboard-capability-register.test.js"
  fail=1
fi

echo
echo "== protected-paths.sh coverage (Node) =="
if node tests/protected-paths-coverage.test.js; then
  echo "OK   tests/protected-paths-coverage.test.js"
else
  echo "FAIL tests/protected-paths-coverage.test.js"
  fail=1
fi

echo
echo "== protected-paths.sh gate functionality (Bash) =="
if bash tests/protected-paths-gate.test.sh; then
  echo "OK   tests/protected-paths-gate.test.sh"
else
  echo "FAIL tests/protected-paths-gate.test.sh"
  fail=1
fi

echo
echo "== rollout wave-graph preflight checker (Bash, scaffolding) =="
rollout_test="tests/rollout-preflight.test.sh"
if bash "$rollout_test"; then
  echo "OK   $rollout_test"
else
  echo "FAIL $rollout_test"
  fail=1
fi

echo
echo "== state-access.sh ordering/atomicity constraints (Bash) =="
if bash tests/state-access-constraints.test.sh; then
  echo "OK   tests/state-access-constraints.test.sh"
else
  echo "FAIL tests/state-access-constraints.test.sh"
  fail=1
fi

echo
echo "== state-access.sh distinctions manifest (Bash) =="
if bash tests/state-distinctions-manifest.test.sh; then
  echo "OK   tests/state-distinctions-manifest.test.sh"
else
  echo "FAIL tests/state-distinctions-manifest.test.sh"
  fail=1
fi

echo
echo "== state-access.sh species enumeration (Bash) =="
if bash tests/state-species-enumeration.test.sh; then
  echo "OK   tests/state-species-enumeration.test.sh"
else
  echo "FAIL tests/state-species-enumeration.test.sh"
  fail=1
fi

echo
echo "== state-access.sh per-unit concurrency, ADR-0016 (Bash) =="
if bash tests/state-access-concurrency.test.sh; then
  echo "OK   tests/state-access-concurrency.test.sh"
else
  echo "FAIL tests/state-access-concurrency.test.sh"
  fail=1
fi

echo
echo "== state-access.sh escalation-path capability regression (Bash) =="
if bash tests/state-access-capability-regression.test.sh; then
  echo "OK   tests/state-access-capability-regression.test.sh"
else
  echo "FAIL tests/state-access-capability-regression.test.sh"
  fail=1
fi

echo
echo "== reviewed-dir leak guard: no suite leaks fixtures into .claude/reviewed/ (Bash, gh425) =="
if bash tests/reviewed-dir-leak-guard.test.sh; then
  echo "OK   tests/reviewed-dir-leak-guard.test.sh"
else
  echo "FAIL tests/reviewed-dir-leak-guard.test.sh"
  fail=1
fi

echo
echo "== eval/harness/validate-cases.py: 13-reason case.yaml validator (Bash, gh-eval-step1) =="
if bash tests/eval-cases.test.sh; then
  echo "OK   tests/eval-cases.test.sh"
else
  echo "FAIL tests/eval-cases.test.sh"
  fail=1
fi

echo
echo "== bin/agent-memory-size-check.sh: warn-only over-threshold/absent-dir behaviour (Bash, item05-3) =="
if bash tests/agent-memory-size-check.test.sh; then
  echo "OK   tests/agent-memory-size-check.test.sh"
else
  echo "FAIL tests/agent-memory-size-check.test.sh"
  fail=1
fi

echo
echo "== agent-memory namespace size warning (advisory only, never affects exit code) =="
bash bin/agent-memory-size-check.sh --project-dir "$(pwd)"

echo
echo "== memory-commit sentinel: header/sentence file-count parity (Guard 1) =="
mem_scope="templates/ .claude/agents/ .claude/persona-protocol.md .claude/persona-protocol-slim.md"
header_files=$(git grep -F -l '## A note on `memory`' -- $mem_scope | sort)
sentence_files=$(git grep -F -l 'Commit your own memory-scope writes before ending your turn.' -- $mem_scope | sort)
if [ -z "$header_files" ]; then header_count=0; else header_count=$(echo "$header_files" | wc -l); fi
if [ -z "$sentence_files" ]; then sentence_count=0; else sentence_count=$(echo "$sentence_files" | wc -l); fi
missing=$(comm -23 <(echo "$header_files") <(echo "$sentence_files"))
if [ "$header_count" -eq "$sentence_count" ] && [ -z "$missing" ]; then
  echo "OK   memory-note header and sentinel sentence both appear in $header_count file(s)"
else
  echo "FAIL memory-note header/sentinel-sentence count mismatch (header=$header_count sentence=$sentence_count)"
  if [ -n "$missing" ]; then
    echo "$missing" | sed 's/^/     header without sentinel: /'
  fi
  fail=1
fi

echo
echo "== memory-commit sentinel: reviewer.md narrowed-command branch agreement (Guard 2) =="
for f in agents/reviewer.md .claude/agents/reviewer.md; do
  bare_count=$(git grep -F -c 'git diff --quiet HEAD' -- "$f" | cut -d: -f2)
  narrowed_count=$(git grep -F -c 'exclude,top).claude/agent-memory' -- "$f" | cut -d: -f2)
  bare_count=${bare_count:-0}
  narrowed_count=${narrowed_count:-0}
  if [ "$bare_count" -eq "$narrowed_count" ]; then
    echo "OK   $f: 'git diff --quiet HEAD' count ($bare_count) matches narrowed-exclusion count ($narrowed_count)"
  else
    echo "FAIL $f: 'git diff --quiet HEAD' count ($bare_count) != narrowed-exclusion count ($narrowed_count)"
    fail=1
  fi
done

echo
echo "== docs/harness-glossary.md: frozen family table residual pins exist (Python, hyg-1) =="
if python3 -c "
import re, sys
g = open('docs/harness-glossary.md', encoding='utf-8').read().split('\n')
suite = open('tests/human-decision-gate.test.sh', encoding='utf-8').read()
i = next((k for k, l in enumerate(g) if l.startswith('**frozen family table**:')), None)
if i is None:
    print('FAIL frozen family table entry not found'); sys.exit(1)
j = i
while j < len(g) and g[j].strip():
    j += 1
t = re.sub(r'\s+', ' ', ' '.join(g[i:j]))
def verdict(rid):
    m = re.search(r'^(?:bash|write)_case \"' + re.escape(rid) + r' [^\"\n]*\" (allowed|blocked)\b', suite, re.M)
    return m.group(1) if m else None
bad = 0
pins = re.findall(r'\bpin ([A-Z][A-Za-z0-9-]*)', t)
for need in ('N21', 'R5'):
    if need not in pins:
        print('FAIL entry no longer names pin ' + need); bad = 1
for rid in pins:
    v = verdict(rid)
    if v == 'allowed':
        print('OK   residual pin ' + rid + ' is an allowed suite row')
    else:
        print('FAIL residual pin ' + rid + ': suite verdict ' + str(v) + ', want allowed'); bad = 1
m = re.search(r'\b([A-Z][A-Za-z0-9-]*) \([^)]*the only \x60TRACKED-OPEN\x60 pin\)', t)
if m:
    rows = re.findall(r'^(?:bash|write)_case \"(\S+) [^\"\n]*tracked-open', suite, re.M | re.I)
    if rows == [m.group(1)] and verdict(m.group(1)) == 'allowed':
        print('OK   ' + m.group(1) + ' is the only tracked-open suite row')
    else:
        print('FAIL only-TRACKED-OPEN claim for ' + m.group(1) + ': tracked-open rows ' + str(rows)); bad = 1
sys.exit(bad)
"; then
  echo "OK   frozen family table residual pins"
else
  echo "FAIL frozen family table residual pins"
  fail=1
fi

echo
echo "== scripts/probe-bash-ask.sh: offline gate/extraction tests (Bash, esf-probe-tests) =="
if bash tests/probe-bash-ask.test.sh; then
  echo "OK   tests/probe-bash-ask.test.sh"
else
  echo "FAIL tests/probe-bash-ask.test.sh"
  fail=1
fi

echo
echo "== scripts/probe-hook-identity.sh: offline classify/outcome tests (Bash, esf-eid-probe) =="
if bash tests/probe-hook-identity.test.sh; then echo "OK   tests/probe-hook-identity.test.sh"; else echo "FAIL tests/probe-hook-identity.test.sh"; fail=1; fi

echo
echo "== bin/contract-score.js: dispatch contract rubric R1-R7 + scribe shape (Node, rgh-u0-1) =="
if node tests/contract-score.test.js; then
  echo "OK   tests/contract-score.test.js"
else
  echo "FAIL tests/contract-score.test.js"
  fail=1
fi

echo
echo "== agents/task-master.md worked examples score 7/7 under --rubric=v2 (Node, rgh-h2) =="
if node tests/contract-examples.test.js; then
  echo "OK   tests/contract-examples.test.js"
else
  echo "FAIL tests/contract-examples.test.js"
  fail=1
fi

echo
echo "== scripts/unit-outcomes.js: read-only unit-outcome export (Node, rgh-u0-2) =="
if node tests/unit-outcomes.test.js; then
  echo "OK   tests/unit-outcomes.test.js"
else
  echo "FAIL tests/unit-outcomes.test.js"
  fail=1
fi

echo
if [ "$fail" -eq 0 ]; then
  echo "All checks passed."
else
  echo "One or more checks FAILED."
fi
exit "$fail"
