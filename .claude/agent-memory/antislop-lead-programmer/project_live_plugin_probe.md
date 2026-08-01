---
name: live-plugin-probe
description: How to run a live headless probe against the REAL marketplace plugin install (Probe C / Step 9 of the 2026-07-28 namespace plan) and the stale-cache trap it exists to catch
metadata:
  type: project
---

Any probe that must exercise the *shipped* hook scripts (not the working
tree's) has to defeat one trap: `hooks/hooks.json` points at
`${CLAUDE_PLUGIN_ROOT}/hooks/scripts/…`, which for a marketplace install is a
**versioned cache copy**, `~/.claude/plugins/cache/antislop-marketplace/antislop/<version>/`.

**Why the obvious refresh silently serves stale scripts:** the
`antislop-marketplace` registration defaults to the GitHub repo, and this
project's version bumps commonly sit in *unpushed* local history. `claude
plugin update antislop@antislop-marketplace` then fetches `origin/master` and
"succeeds" at an older version. Hit for real on 2026-07-30 (origin was
0.13.16, working tree 0.13.18).

**How to apply.** Repoint the marketplace at the working tree —
`.claude-plugin/marketplace.json` declares `source: "./"`, so this is the
supported path and does not violate P2's no-hand-copying rule:

```
claude plugin marketplace add /home/sebas/AntiSlop      # replaces the github entry in-place
claude plugin update antislop@antislop-marketplace --scope user
```

Restore afterwards with `claude plugin marketplace add Storreslara/AntiSlop`
once the version is pushed. Then always sha256 the executing scripts under the
recorded `installPath` (`~/.claude/plugins/installed_plugins.json`) against
the working tree before trusting any result.

**Current live state (observed 2026-07-31): the marketplace is still pointed at
the working tree** — `${CLAUDE_PLUGIN_ROOT}` resolves to `/home/sebas/AntiSlop/`,
so an edit to `hooks/scripts/*.sh` takes effect on the *very next* tool call of
the session that made it. Two consequences: a syntax error there breaks every
subsequent Bash call until fixed (`bash -n` before anything else), and you get
free live end-to-end proof of a hook change without any probe scaffolding.

**Consequence for mutation controls.** A mutation test that edits a live
`hooks/scripts/*.sh` mutates the gate your own next Bash call runs through.
Apply the mutation, run the suite, and restore inside **one** Bash invocation,
then prove restoration with `git diff --quiet -- <script>` — never leave a
mutated or syntactically broken gate across a tool-call boundary.

**Hook matchers are REGEXes, not exact tool names.** `"Write|Edit"` in
`hooks/hooks.json` therefore also fires for `MultiEdit` (carries `file_path`)
and `NotebookEdit` (carries `notebook_path`, no `file_path`). Any new gate on
that matcher must decide what it does for a payload with no `file_path` key —
blocking there would break notebook editing project-wide. Settled while
implementing #178; see that commit for the chosen split.

**Two fixture facts that are not obvious:**

- `~/.claude/settings.json` already sets
  `enabledPlugins["antislop@antislop-marketplace"] = true` on this machine, so
  `bin/cli.js` **skips its own standalone hook merge** in every scaffolded
  fixture — there is nothing for `--dedupe-hooks` to remove and no
  double-firing. Don't plan around a collision that isn't there.
- Fixture-local `.claude/settings.json` hooks do **not** receive
  `CLAUDE_PLUGIN_ROOT` in their environment (it is plugin-scoped), and
  `--debug hooks` / `--debug-file` did not emit the expanded path either. The
  workable live proof is *behavioral*: keep the previous cache version around
  and show its bare-string comparisons could not have produced the observed
  blocks. See [[agent-identity-lib]].

Evidence and the reusable provisioning script:
`docs/experiments/2026-07-probe-hook-payloads.md` (Probe C) and
`eval/harness/probe-namespaced-dispatch.sh`.

**Settled empirically, do not re-derive:** namespaced dispatch puts the
identity on the wire *verbatim with prefix* (`antislop:lead-programmer`) in
both `agent_type` and `tool_input.subagent_type`, while the main session's
`agent_type` stays bare because settings.json's `.agent` is bare. Both forms
coexist in one session.
