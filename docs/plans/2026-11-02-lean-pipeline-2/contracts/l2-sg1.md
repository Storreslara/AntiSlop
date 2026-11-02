Unit: l2-sg1

## Objective
Plan unit 10a, (a) and (c); tests `(l2-s1)`-`(l2-s6)` as listed there. (a) `stop-gate-core.sh`: gated SubagentStop: compute `tripped` before the WIP rule; tripped plus a sentinel: delete it, log `<utc> wip-ignored d6-trip agent=<id>` to `wip-audit.log`, then rule 6. Update header rules 5-6. (c) `state-access.sh`: exported `state_replace_pending_review <id> <content>`: unless the path is a dir, `mktemp "${dot}/.pending-review-tmp.XXXXXX"`, write, `chmod 644`, `mv -f` onto the path; else or on failure, `rm -f` the path and create it under `set -C`, else return 1. Rule 6 calls it `|| block` naming `${dot_label}/.pending-review.<id>`. `state_write_pending_review` and C3 stay. Also: `(l2-s7)` flag path a dir → rc 2, stderr names it; `(l2-s8)` a symlink to an outside dir → nothing written there, flag regular; `(l2-c1)` replace over a `defer:` file → new content, mode 644; `(l2-c2)` over a dir → non-zero. One `[Unreleased]` CHANGELOG bullet naming `l2-sg1`.

## Retrieval
No tracker issue; spec in `docs/plans/2026-11-02-lean-pipeline-2.md`, unit 10a.

## Affected files
- `hooks/scripts/lib/stop-gate-core.sh`
- `hooks/scripts/lib/state-access.sh`
- `tests/stop-gate.test.sh`
- `tests/state-access-constraints.test.sh`
- `CHANGELOG.md`
- `.claude/` and `adapters/` copies, only through `node bin/cli.js --update --force-render`

## Do NOT touch
- `hooks/scripts/stop-gate.sh`, `hooks/scripts/dispatch-hygiene.sh`, `bin/`

## Acceptance criteria
1. run: `a=$(bash tests/stop-gate.test.sh 2>&1); r=$?; b=$(bash tests/state-access-constraints.test.sh 2>&1); s=$?; printf '%s\n%s\n' "$a" "$b" | grep '^OK ' | grep -oE '\(l2-[sc][1-8]\)|C3: pending' | sort -u | wc -l | tr -d ' '; exit $((r + s))`
   exit: 0
   stdout: `11`
   mutation: rule 6 calls `state_write_pending_review` → s3, s4, s8 FAIL, exit 1.
2. run: `d=$(mktemp -d); c=$d/.claude; mkdir -p $c/reviewed; echo '{}' > $c/persona-config.json; touch -d 2026-01-01 $c/reviewed/.writer-dispatch-stamp; echo P > $c/reviewed/u.pass; touch -d 2026-01-02 $c/reviewed/u.pass; echo red > $c/wip-handoff.lp-1; echo '{"hook_event_name":"SubagentStop","agent_type":"lead-programmer","agent_id":"lp-1"}' | CLAUDE_PROJECT_DIR=$d bash hooks/scripts/stop-gate.sh 2>/dev/null; echo "rc=$? $(ls -A $c | grep -c '^\.pending-review\.lp-1$') $(ls -A $c | grep -c '^wip-h') $(grep -c ' wip-ignored d6-trip agent=lp-1$' $c/wip-audit.log)"`
   exit: 0
   stdout: `rc=2 1 0 1`
   mutation: WIP rule before D6 → `rc=0 0 0 0`.
3. run: `for f in stop-gate-core.sh state-access.sh; do for p in adapters/codex/ adapters/cursor/ .claude/; do cmp -s hooks/scripts/lib/$f ${p}hooks/scripts/lib/$f && echo same; done; done | grep -c same`
   exit: 0
   stdout: `6`
   mutation: no re-render → `0`, exit 1.
4. run: `sed -n '/^## \[Unreleased\]/,/^## \[0\.33\.0\]/p' CHANGELOG.md | grep -c 'l2-sg1'`
   exit: 0
   stdout: `1`
   mutation: bullet under 0.33.0 → `0`, exit 1.
5. run: `bash tests/validate.sh >/dev/null 2>&1` (timeout 600000 ms; once, after the final commit)
   exit: 0
   stdout: empty
