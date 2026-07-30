# Probe: hook payload shapes (2026-07-13)

Empirical probes for the persona-review-hardening plan
(`docs/plans/2026-07-13-persona-review-hardening.md`, step 1), following the
repo's "confirmed empirically, not assumed" practice already used for
`reviewer-route-gate.sh:6-13`. The probe wiring itself (temporary logging
hooks) was never added to this repo — it was registered only in a disposable
scratch fixture built by `eval/harness/scaffold.sh` outside the working tree,
and deleted after capture. This document is the only durable artifact.

## Method

1. Scaffolded a fresh fixture with `eval/harness/scaffold.sh` (installs
   explorer, lead-programmer, planner, reviewer via `bin/cli.js`).
2. Appended two temporary hook entries to the scaffolded fixture's own
   `.claude/settings.json` (not this repo's `hooks/hooks.json`):
   - `PreToolUse` matcher `Bash` → a probe script that appends its raw stdin
     payload to `.claude/probe-pretooluse-bash.jsonl` and exits 0.
   - `SubagentStop` (no matcher, alongside the existing `stop-gate.sh` entry)
     → a probe script that appends its raw stdin payload to
     `.claude/probe-subagentstop.jsonl` and exits 0.
3. Ran one headless task (`claude -p`, `--model sonnet`,
   `--permission-mode acceptEdits`) instructing the main session
   (`orchestrator`) to spawn `lead-programmer` via the `Agent` tool to run the
   Bash command `git status` and report back — never running the command in
   the main session itself, so any captured `Bash` PreToolUse payload is
   necessarily subagent-issued.
4. Captured the resulting JSONL files, then discarded the whole scratch
   fixture (including the probe hook scripts and settings.json edits).

## Probe A — does subagent-issued `Bash` PreToolUse carry `agent_type`?

Raw captured payload (one `PreToolUse` event, `tool_name: "Bash"`, fired
while `lead-programmer` executed `git status`):

```json
probe-a-payload
{"session_id":"c1660582-2afa-43ff-b657-07d0d00acaf9","transcript_path":"/home/user/.claude/projects/-tmp-claude-1000--home-sebas-seb-claude-setup-25cd00be-2665-422e-8b29-27bb3ec75763-scratchpad-probe-fixture/c1660582-2afa-43ff-b657-07d0d00acaf9.jsonl","cwd":"/tmp/claude-1000/-home-sebas-seb-claude-setup/25cd00be-2665-422e-8b29-27bb3ec75763/scratchpad/probe-fixture","prompt_id":"370c349c-343b-4a05-86d0-985b31a255fc","permission_mode":"acceptEdits","agent_id":"a18677c5b7c94db1a","agent_type":"lead-programmer","effort":{"level":"high"},"hook_event_name":"PreToolUse","tool_name":"Bash","tool_input":{"command":"git status","description":"Show working tree status"},"tool_use_id":"toolu_019kBMrmi3YHs4mtFBwAcvKY"}
```

The top-level `agent_type` key is present and set to `"lead-programmer"` (the
caller's identity), exactly mirroring the already-confirmed `PreToolUse`
(`Agent`) shape at `reviewer-route-gate.sh:6-13`. `tool_input.command` also
carries the literal command string, which step 4's design needs for the
substring match on `.claude/reviewed`.

Probe A verdict: agent_type present

**Scope caveat (added post-hoc, see the 2026-07-28 agent-identity namespace
plan):** Probe A establishes only that the `agent_type` field is *present* on
a subagent-issued `Bash` PreToolUse payload. It does not establish what
*values* that field can take. The fixture that captured `probe-a-payload` was
built by `eval/harness/scaffold.sh`, which installs personas as project-local
`.claude/agents/*.md` copies only — a bare-name-only dispatch path — so the
single observed value, `"lead-programmer"`, is a bare persona name by
construction of the fixture, not by anything the field itself guarantees.
Treating that one observed form as the field's only possible shape was the
actual defect the namespace-gate-fix plan corrected: a marketplace-installed
plugin's own dispatch surface can produce a namespaced value instead (e.g.
`antislop:lead-programmer`), which this probe never exercised. See Probe C
below.

Branch decision for step 4: build `reviewed-path-gate.sh` on the
`agent_type`-present branch — attribute the caller from the top-level
`agent_type` field and apply the allow/block rules keyed on it (reviewer →
allow, empty + no-reviewer-fallback → allow, any other persona → block).

## Probe B — does `SubagentStop` carry a final-message field?

Raw captured payload (the `SubagentStop` event for the same
`lead-programmer` invocation):

```json
probe-b-payload
{"session_id":"c1660582-2afa-43ff-b657-07d0d00acaf9","transcript_path":"/home/user/.claude/projects/-tmp-claude-1000--home-sebas-seb-claude-setup-25cd00be-2665-422e-8b29-27bb3ec75763-scratchpad-probe-fixture/c1660582-2afa-43ff-b657-07d0d00acaf9.jsonl","cwd":"/tmp/claude-1000/-home-sebas-seb-claude-setup/25cd00be-2665-422e-8b29-27bb3ec75763/scratchpad/probe-fixture","prompt_id":"370c349c-343b-4a05-86d0-985b31a255fc","permission_mode":"acceptEdits","agent_id":"a18677c5b7c94db1a","agent_type":"lead-programmer","effort":{"level":"high"},"hook_event_name":"SubagentStop","stop_hook_active":false,"agent_transcript_path":"/home/user/.claude/projects/-tmp-claude-1000--home-sebas-seb-claude-setup-25cd00be-2665-422e-8b29-27bb3ec75763-scratchpad-probe-fixture/c1660582-2afa-43ff-b657-07d0d00acaf9/subagents/agent-a18677c5b7c94db1a.jsonl","last_assistant_message":"On branch master\nUntracked files:\n  (use \"git add <file>...\" to include in what will be committed)\n\t.claude/probe-pretooluse-bash.jsonl\n\nnothing added to commit but untracked files present (use \"git add\" to track)","background_tasks":[],"session_crons":[]}
```

Keys present: `session_id`, `transcript_path`, `cwd`, `prompt_id`,
`permission_mode`, `agent_id`, `agent_type`, `effort`, `hook_event_name`,
`stop_hook_active`, `agent_transcript_path`, `last_assistant_message`,
`background_tasks`, `session_crons`.

`last_assistant_message` carries the subagent's final assistant-turn text
verbatim (here, the `git status` output the task asked it to relay back) —
a usable field for a literal "ready-for-review" substring check.

Probe B verdict: field present (last_assistant_message)

This is a refinement, not a dependency, per the plan (step 5 does not
require this): step 5's flag-setting logic MAY additionally suppress the
pending-review flag when `last_assistant_message` does not match
`ready-for-review`, since the field exists and is populated in practice.
Given step 5's own scope note ("a refinement, not a dependency"), and to
keep the mechanism simple and hard to silently defeat (an agent could phrase
its final message to dodge a substring check), step 5 as implemented in this
pass does NOT add the suppression refinement — the flag is set for every
gated-agent stop not exempted by a WIP sentinel, exactly as the
no-refinement fallback the plan describes.

## Probe C — what identity form does namespaced dispatch actually produce? (2026-07-30)

**Status: RUN. All six acceptance criteria (P-C1–P-C6) hold; the R8 provenance
assertion holds.** Executed as Step 9 of
`docs/plans/2026-07-28-agent-identity-namespace-gate-fix.md`, the plan's
blocking acceptance gate.

**The question Probe A never asked:** when a persona is dispatched via its
`antislop:`-prefixed marketplace form rather than a bare project-local copy,
what literal values do `agent_type`, `subagent_type`, and settings.json's
`.agent` actually carry on the resulting hook payloads? Probe A's fixture
could not answer this — see the scope caveat on Probe A's verdict above.

### Method as executed

1. Refreshed this machine's marketplace plugin cache to the working tree's
   version through the supported CLI only — no file was hand-copied into the
   cache (constitution P2). `.claude-plugin/marketplace.json` declares
   `source: "./"`, so pointing the marketplace at the working tree serves the
   plugin from it:

   ```
   $ claude plugin marketplace add /home/sebas/AntiSlop
   Adding marketplace…✔ Successfully added marketplace: antislop-marketplace (declared in user settings)

   $ claude plugin update antislop@antislop-marketplace --scope user
   Checking for updates for plugin "antislop@antislop-marketplace" at user scope…
   ✔ Plugin "antislop" updated from 0.13.16 to 0.13.18 for scope user. Restart to apply changes.
   ```

   (The pre-existing registration pointed at the GitHub repo, whose `master`
   was still at 0.13.16 — Step 8's bump is unpushed local history. A GitHub-
   sourced refresh would therefore have served the stale, unfixed scripts:
   exactly the R8 trap, hit for real.)

2. Provisioned the fixture with `eval/harness/probe-namespaced-dispatch.sh`
   (new, this step), which scaffolds `eval/harness/scaffold.sh`'s disposable
   toy-lib fixture and then adds the thing Probe A never had — namespaced
   dispatch — by enabling the marketplace plugin in the **fixture's own**
   `.claude/settings.json`:

   ```json
   "enabledPlugins": { "antislop@antislop-marketplace": true }
   ```

   `bin/cli.js` skips its own standalone hook merge when the plugin is already
   enabled, so the fixture's settings.json carries **no**
   `${CLAUDE_PROJECT_DIR}/.claude/hooks/scripts/` registration; the script
   asserts this. The plugin's `${CLAUDE_PLUGIN_ROOT}` registrations are the
   only ones present — no double-firing, and no absolute-path re-registration
   shortcut.

3. Registered two temporary logging hooks — `PreToolUse` matcher `Agent`, and
   `SubagentStop` — in the **fixture's** `.claude/settings.json`, exactly as
   Probe A did, never in this repo's `hooks/hooks.json`. They append raw stdin
   to files **outside** the fixture, so the probe's own captures do not dirty
   the fixture's git tree.

4. Ran three headless `claude -p` tasks in the fixture
   (`--output-format json --permission-mode acceptEdits --model sonnet
   --max-budget-usd … --no-session-persistence`, the `eval/harness/run.sh`
   shape), each dispatching **exclusively** via the `antislop:`-prefixed form.
   Total spend **$0.6285** (`$0.32236 + $0.22941 + $0.07675`), against a $5
   cap.

The fixture, its probe hooks and its captures were discarded afterward. This
document is the only durable artifact.

### R8 — provenance assertion (gates all six criteria)

`installed_plugins.json` records `installPath` — the value
`${CLAUDE_PLUGIN_ROOT}` expands to for hooks fired by this plugin — as
`/home/sebas/.claude/plugins/cache/antislop-marketplace/antislop/0.13.18`.
sha256 of each of the four executing gate scripts there, against the
corresponding working-tree file (verbatim output of
`probe-namespaced-dispatch.sh`):

```
CLAUDE_PLUGIN_ROOT (resolved install path) = /home/sebas/.claude/plugins/cache/antislop-marketplace/antislop/0.13.18

script                                 sha256(plugin-root)                                              sha256(working-tree)                                             verdict
lib/agent-identity.sh                  e91921594a70bb85616d0bbe1be74fb71037f67add37315402f79504cc229496 e91921594a70bb85616d0bbe1be74fb71037f67add37315402f79504cc229496 EQUAL
stop-gate.sh                           d070edf75e866b022c676d3191be38ce722d0fdf6cfbf64e40a17f840ae0b9cf d070edf75e866b022c676d3191be38ce722d0fdf6cfbf64e40a17f840ae0b9cf EQUAL
reviewer-route-gate.sh                 5fcd27415100bb9236a28e5276b1715c137394620d6c5ece344bf2cd4f00a2e0 5fcd27415100bb9236a28e5276b1715c137394620d6c5ece344bf2cd4f00a2e0 EQUAL
reviewed-path-gate.sh                  bd76c92b0b8127c0266ceb4daf8edd3e17424df1b26ffe73d74af65ce9e5c4ac bd76c92b0b8127c0266ceb4daf8edd3e17424df1b26ffe73d74af65ce9e5c4ac EQUAL

R8 OK — fixture ready at …/probe-c-fixture (captures -> …/probe-c-capture)
```

`diff -r` over the whole `hooks/` tree reports no differences either.

**Live corroboration that the executing scripts really are these, not the
stale cache copy.** The 0.13.16 copy is still on disk, and it is behaviorally
distinguishable, not merely different:

```
$ grep -n 'check_name\|= "reviewer"' ~/.claude/plugins/cache/antislop-marketplace/antislop/0.13.16/hooks/scripts/stop-gate.sh
90:if [ "$hook_event" = "SubagentStop" ] && [ "$agent_type" = "reviewer" ]; then
148:    [ -n "$name" ] && [ "$name" = "$check_name" ] && match=true
$ grep -n '= "lead-programmer"' ~/.claude/plugins/cache/antislop-marketplace/antislop/0.13.16/hooks/scripts/reviewer-route-gate.sh
27:if [ "$agent_type" = "lead-programmer" ] && [ "$target_type" = "reviewer" ]; then
$ ls ~/.claude/plugins/cache/antislop-marketplace/antislop/0.13.16/hooks/scripts/lib
ls: cannot access '…/0.13.16/hooks/scripts/lib': No such file or directory
```

Under those bare-string comparisons an `antislop:`-prefixed identity matches
nothing: no flag would be created (P-C2), no dispatch blocked (P-C3/P-C5), no
flag cleared (P-C4). All four were observed live below, so the scripts that
ran cannot have been the 0.13.16 copies. `claude plugin details
antislop@antislop-marketplace` independently reports `antislop 0.13.18 …
Hooks (6)` for the loaded plugin.

### P-C1 — payload capture: the literal identity values namespaced dispatch produces

Raw `PreToolUse` (`tool_name: "Agent"`) payload, main session dispatching the
namespaced lead-programmer:

```json
probe-c-pretooluse-agent-payload
{"session_id":"6f98aa6c-14a7-4b71-a7a9-9e029d9df9cc","transcript_path":"/home/sebas/.claude/projects/-tmp-claude-1000--home-sebas-AntiSlop-96d3fb3b-4051-4d08-aa4f-33fddf416a4f-scratchpad-probe-c-fixture/6f98aa6c-14a7-4b71-a7a9-9e029d9df9cc.jsonl","cwd":"/tmp/claude-1000/-home-sebas-AntiSlop/96d3fb3b-4051-4d08-aa4f-33fddf416a4f/scratchpad/probe-c-fixture","prompt_id":"bce8a32f-6bca-45a0-ac8f-1cb9f1c7ece5","permission_mode":"acceptEdits","agent_type":"orchestrator","effort":{"level":"high"},"hook_event_name":"PreToolUse","tool_name":"Agent","tool_input":{"description":"Run git log oneline","prompt":"Run `git log --oneline -1` with Bash and report the one-line output. Change nothing.","subagent_type":"antislop:lead-programmer","run_in_background":false},"tool_use_id":"toolu_01PfcYKrh8rN6GxXQ68wx6Rv"}
```

Raw `SubagentStop` payload for that same subagent:

```json
probe-c-subagentstop-payload
{"session_id":"6f98aa6c-14a7-4b71-a7a9-9e029d9df9cc","transcript_path":"/home/sebas/.claude/projects/-tmp-claude-1000--home-sebas-AntiSlop-96d3fb3b-4051-4d08-aa4f-33fddf416a4f-scratchpad-probe-c-fixture/6f98aa6c-14a7-4b71-a7a9-9e029d9df9cc.jsonl","cwd":"/tmp/claude-1000/-home-sebas-AntiSlop/96d3fb3b-4051-4d08-aa4f-33fddf416a4f/scratchpad/probe-c-fixture","prompt_id":"bce8a32f-6bca-45a0-ac8f-1cb9f1c7ece5","permission_mode":"acceptEdits","agent_id":"a66f714bb0b62439d","agent_type":"antislop:lead-programmer","effort":{"level":"high"},"hook_event_name":"SubagentStop","stop_hook_active":false,"agent_transcript_path":"/home/sebas/.claude/projects/-tmp-claude-1000--home-sebas-AntiSlop-96d3fb3b-4051-4d08-aa4f-33fddf416a4f-scratchpad-probe-c-fixture/6f98aa6c-14a7-4b71-a7a9-9e029d9df9cc/subagents/agent-a66f714bb0b62439d.jsonl","last_assistant_message":"`0ff1da1 probe fixture: namespaced dispatch enabled`\n\nNothing was changed.","background_tasks":[],"session_crons":[]}
```

Raw `PreToolUse` (`Agent`) payload for a **nested** dispatch — the namespaced
lead-programmer attempting to spawn the namespaced reviewer. Both identity
fields are namespaced simultaneously:

```json
probe-c-nested-agent-payload
{"session_id":"678ac29a-9770-4a18-ac22-a3de99f854dd","transcript_path":"/home/sebas/.claude/projects/-tmp-claude-1000--home-sebas-AntiSlop-96d3fb3b-4051-4d08-aa4f-33fddf416a4f-scratchpad-probe-c-fixture/678ac29a-9770-4a18-ac22-a3de99f854dd.jsonl","cwd":"/tmp/claude-1000/-home-sebas-AntiSlop/96d3fb3b-4051-4d08-aa4f-33fddf416a4f/scratchpad/probe-c-fixture","prompt_id":"b28459c4-31f8-4423-8397-242ea07691c0","permission_mode":"acceptEdits","agent_id":"accdfb771c0ca7fe9","agent_type":"antislop:lead-programmer","effort":{"level":"high"},"hook_event_name":"PreToolUse","tool_name":"Agent","tool_input":{"description":"probe","prompt":"probe","subagent_type":"antislop:reviewer"},"tool_use_id":"toolu_01ALt2qehXEctqGyR4UhTpWk"}
```

Every distinct identity value observed across the whole probe:

```
$ grep -o '"agent_type":"[^"]*"' probe-subagentstop.jsonl | sort | uniq -c
      2 "agent_type":"antislop:lead-programmer"
      2 "agent_type":"antislop:reviewer"
$ grep -o '"subagent_type":"[^"]*"' probe-pretooluse-agent.jsonl | sort | uniq -c
      3 "subagent_type":"antislop:lead-programmer"
      3 "subagent_type":"antislop:reviewer"
```

**Finding.** `agent_type` and `tool_input.subagent_type` carry the dispatch
identity **verbatim, prefix included** — `antislop:lead-programmer`,
`antislop:reviewer`. The field is *not* normalized to a bare persona name
anywhere in the payload path. This is the value form Probe A never observed
and the shipped gates assumed could not occur.

One asymmetry worth recording: the **main session's** `agent_type` is the
bare `"orchestrator"` even with the plugin enabled, because settings.json's
`.agent` is set to the bare name. So both forms genuinely coexist in one
session — which is exactly why the gates must compare canonically rather than
picking a side.

P-C1 verdict: **PASS** — namespaced dispatch produces namespace-prefixed
literal values in both fields.

### P-C2 — flag creation (S4 live)

After the namespaced lead-programmer's `SubagentStop` above (agent_id
`a66f714bb0b62439d`):

```
$ ls -la .claude/ | grep -i pending
-rw-r--r-- 1 sebas sebas   45 Jul 30 12:08 .pending-review.a66f714bb0b62439d
```

The flag's id matches the payload's `agent_id`, so it was created by that
stop. P-C2 verdict: **PASS**.

### P-C3 — route block (S7 live)

With that flag standing, the main session's next dispatch of
`antislop:lead-programmer` (payload captured — `"subagent_type":"antislop:lead-programmer"`,
`tool_use_id: toolu_01Cx5aydovxsiCDLdFqoQUoq`) was blocked. Verbatim from the
run transcript:

```
PreToolUse:Agent hook error: [${CLAUDE_PLUGIN_ROOT}/hooks/scripts/reviewer-route-gate.sh]: BLOCKED: a completed unit is awaiting review - route it to the reviewer first, or use the defer:/skip: escape in the flag file (.claude/.pending-review.*), per persona-protocol.md's Pending-review flag section.
```

P-C3 verdict: **PASS**.

### P-C4 — flag clearing (S3 live)

Directly observed across one `antislop:reviewer` dispatch (the third run,
whose only action was that dispatch):

```
=== BEFORE: pending flags ===
.pending-review.accdfb771c0ca7fe9
=== AFTER: pending flags ===
NONE — no .pending-review.* remains
=== .claude/review-audit.log ===
2026-07-30T17:10:13Z cleared-by=reviewer
2026-07-30T17:11:30Z cleared-by=reviewer
```

The corresponding `SubagentStop` payload confirms the clearing agent's
identity was the namespaced form:

```json
probe-c-reviewer-subagentstop-payload
{"session_id":"0871c8a4-71d2-4410-a484-62297258d58e","transcript_path":"/home/sebas/.claude/projects/-tmp-claude-1000--home-sebas-AntiSlop-96d3fb3b-4051-4d08-aa4f-33fddf416a4f-scratchpad-probe-c-fixture/0871c8a4-71d2-4410-a484-62297258d58e.jsonl","cwd":"/tmp/claude-1000/-home-sebas-AntiSlop/96d3fb3b-4051-4d08-aa4f-33fddf416a4f/scratchpad/probe-c-fixture","prompt_id":"78abcd69-eb47-4a89-b4a1-8d47d5a92a9f","permission_mode":"acceptEdits","agent_id":"a0200674432306650","agent_type":"antislop:reviewer","effort":{"level":"high"},"hook_event_name":"SubagentStop","stop_hook_active":false,"agent_transcript_path":"/home/sebas/.claude/projects/-tmp-claude-1000--home-sebas-AntiSlop-96d3fb3b-4051-4d08-aa4f-33fddf416a4f-scratchpad-probe-c-fixture/0871c8a4-71d2-4410-a484-62297258d58e/subagents/agent-a0200674432306650.jsonl","last_assistant_message":"probe acknowledged","background_tasks":[],"session_crons":[]}
```

This is the GRANT (conservative) matcher succeeding on a real plugin install:
`antislop:reviewer` resolved to *this* plugin's namespace and was granted the
clear privilege. The earlier `17:10:13Z` line is the same behavior from the
second run. P-C4 verdict: **PASS**.

### P-C5 — caller block (S6 live)

The namespaced lead-programmer's attempt to spawn `antislop:reviewer`
(nested payload quoted under P-C1) was blocked. Verbatim, as the subagent
reported it in its own `last_assistant_message`:

```
PreToolUse:Agent hook error: [${CLAUDE_PLUGIN_ROOT}/hooks/scripts/reviewer-route-gate.sh]: BLOCKED: lead-programmer may not spawn the reviewer directly. Report 'ready-for-review' and let the orchestrator (or team lead) route it, per persona-protocol.md's Review Ownership section.
```

Both sides of that comparison were namespaced at once — caller
`antislop:lead-programmer`, target `antislop:reviewer` — so this exercises the
independent normalization of both fields, not just one. P-C5 verdict:
**PASS**.

### P-C6 — no false drift

The fixture's complete `.claude/review-audit.log` after all three runs:

```
$ cat .claude/review-audit.log
2026-07-30T17:10:13Z cleared-by=reviewer
2026-07-30T17:11:30Z cleared-by=reviewer
$ grep -n identity-drift .claude/review-audit.log ; echo "grep exit=$?"
grep exit=1
```

No `identity-drift` line at all, so in particular none naming an
`antislop:`-prefixed identity — the recognized-namespace resolution
(`${CLAUDE_PLUGIN_ROOT}/.claude-plugin/plugin.json` → `antislop`) works in a
real marketplace install, not only under a test harness's synthetic
`CLAUDE_PLUGIN_ROOT`. Note the log is positively populated by the
`cleared-by=reviewer` lines, so its emptiness of drift lines is not the
emptiness of a log nothing ever wrote to. P-C6 verdict: **PASS**.

### Probe C verdict

| Criterion | Result |
|---|---|
| R8 provenance (gates all six) | **HOLDS** — all four scripts EQUAL |
| P-C1 payload capture | **PASS** |
| P-C2 flag creation (S4) | **PASS** |
| P-C3 route block (S7) | **PASS** |
| P-C4 flag clearing (S3) | **PASS** |
| P-C5 caller block (S6) | **PASS** |
| P-C6 no false drift | **PASS** |

Probe C verdict: namespaced dispatch produces namespace-prefixed identity
values, and the fixed gates handle them correctly end-to-end in a real
marketplace plugin install.

## Cleanup

The scratch fixture (hook scripts, settings.json edits, captured `.jsonl`
files, git history) was deleted after this capture. Nothing under
`hooks/`, `.claude/`, or any other repo-tracked path in this repository was
touched by the probe.

Probe C's fixture and captures were likewise discarded. Probe C additionally
touched state *outside* the repository — this machine's marketplace plugin
cache, refreshed to 0.13.18 via `claude plugin` commands, and the
`antislop-marketplace` registration, repointed from the GitHub repo to the
local working tree so `source: "./"` would serve the unpushed Step 8 version.
Restore the original registration with
`claude plugin marketplace add Storreslara/AntiSlop` once 0.13.18 is pushed.
