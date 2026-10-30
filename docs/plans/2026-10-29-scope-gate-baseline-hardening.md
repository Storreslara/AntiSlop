# Scope-gate baseline hardening (sgb)

## Goal
`hooks/scripts/writer-scope-gate.sh` judges a writer's changes against a baseline commit (`$start`). Today the gate derives `$start` from things the writer controls. After this plan, `$start` is the **dispatch baseline**: the main session's `HEAD` at the moment it dispatched the writer. A PreToolUse(Agent) hook records it under the Agent call's `tool_use_id` in `.claude/reviewed/dispatch-baseline.log`, a path the writer's tools cannot write. Every forgery variant the tg-u2 reviewer found (five, plus the contract-read form and one graft form found here) then blocks with exit 2. All other tg-u1/tg-u2 behaviour stays the same.

Goal clauses mapped to criteria:
- G1 "the dispatch hook records the baseline": sgb-u1 criteria 1, 2.
- G2 "the gate takes `$start` only from the record": sgb-u2 criteria 1, 2.
- G3 "all five variants (and the contract read) give rc=2": sgb-u2 criterion 2.
- G4 "existing flows stay green": sgb-u1 criterion 2 and sgb-u2 criterion 3 (all 114 labels of the f566aeef suite still print; none is replaced).
- G5 "mirrors, fileHashes and version stamp": criteria 3 to 7 of each unit.

## Context

### The defect, re-verified 2026-10-29 against the gate at f566aeef
The reviewer's finding is the NOTE[code] D1 in `.claude/reviewed/tg-u2.pass`. Reproduced in a scratch repo (`mktemp -d`, never deleted). A lead-programmer dispatch lists `src/a.js`, and the writer edits `CONTEXT.md` with the Edit tool. In every variant below the edit lands inside the forged baseline. The current gate gives **rc=0 in all five**, and the uncommitted control gives rc=2:

| # | Variant | How `$start` is forged (gate lines 118-139) | current rc |
|---|---|---|---|
| V1 | backdated quiet commit | the writer commits the edit with a committer date before the transcript's first timestamp `t0`, and the transcript shows no commit line. `rev-list -1 --before=t0` picks the writer's own commit. | 0 |
| V2 | same-second commit | committer date equal to `t0` (`--before` includes it) | 0 |
| V3 | forged `[x <sha>]` line, orphan parent | `commit-tree` makes an orphan O holding the edit and a child C of O. The writer prints `[x C]`. `first`=O, `merge-base` fails, and the fallback sets `start`=O. | 0 |
| V4 | `git replace` | `git replace <t0 baseline> <commit whose tree holds the edit>`. `git diff` reads the replacement. | 0 |
| V5 | no timestamps | a transcript with no `timestamp` field and no commit line gives `start=HEAD`, after the writer's commit | 0 |
| V6 | contract read (tg-u2 consequence) | V4's primitive with a forged tree whose `contracts/u9.md` lists `CONTEXT.md`. `cfile` reads `git show "$start:…"` from the forged tree. | 0 |
| V7 | graft rewrite (found here) | `.git/info/grafts` makes a rewritten root look like a descendant of the baseline | 0 |

Script: the scratch file `variants2.sh` (end to end: the real `dispatch-hygiene.sh` records, the writer forges, the gate judges). It was run against the current tree and against a scratch prototype of the design below. With the prototype, V1-V7 all give rc=2, the in-scope committed control gives rc=0, the uncommitted out-of-scope control gives rc=2, no record with a candidate gives rc=2, and no record with no candidate gives rc=0. These numbers come from a prototype in a scratch clone. They are evidence that the criteria can be met, not code to copy.

### Design decisions (evidence-backed)
- **D1. Who records.** `hooks/scripts/dispatch-hygiene.sh` records, the existing PreToolUse(Agent) hook (`hooks/hooks.json`: `PreToolUse matcher=Agent` runs `reviewer-route-gate.sh | dispatch-hygiene.sh`). Reasons: it already reads `.tool_input.prompt` and `subagent_type`, sources `agent-identity.sh` and `audit-log.sh` (which gives `_portable_sha256`), and is Claude-only. It has no adapter copies, so there is one mirror (`.claude/hooks/scripts/dispatch-hygiene.sh`). `reviewer-route-gate.sh` was rejected: its logic sits in the port-invariant core `lib/reviewer-route-gate-core.sh`, which has five copies (adapters + mirror), and it runs `set -e` throughout. The record is written right after `[ -f "$config" ] || exit 0` (line 123), before `mode` is read, so `dispatchHygiene.mode: off` (line 138), an honoured override (exits at ~174/234) and every H1-H4 block still record. A block makes the dispatch not happen, and the orphan record that remains is never matched. No other hook is needed.
- **D2. Where.** `.claude/reviewed/dispatch-baseline.log`. `reviewed-path-gate.sh` (registered on PreToolUse `Write|Edit` and `Bash`) denies every non-reviewer identity a write there. Observed in this session: two of my own spec-master Bash commands that merely redirected `2>/dev/null` while naming the path were refused with "'spec-master' may not write .claude/reviewed/ via Bash". The directory is gitignored (`.gitignore:16`), so it leaves no repo dirt. Every reader of the directory globs by suffix (`*.pass`, `*.fail`, `*.blocked`, `*.escalated`, `*.directed`; `stop-gate-core.sh:422-434`, `marker-audit.sh:79`, `ladder-tier.sh:135`, `human-review-cleanup.sh:93`), so a `.log` file is invisible to them. `.claude/dispatch-audit.log` (Set A of `harness-integrity-gate.sh`, also writer-unwritable) was rejected for two reasons. `bin/human-review-cleanup.sh:224` and `bin/harness-integrity.sh` rotate it, which would drop live records and block in-flight writers. It also mixes the record into a log with its own seal lifecycle and readers. A first guess that it would break `tests/dispatch-hygiene.test.sh`'s "log absent" assertions was **measured false**: those payloads carry no `tool_use_id`, so they never record. A new Set-A file would need an edit to `harness-integrity-gate.sh`, a Set B path that no subagent can edit ("both tiers never emit ask from a subagent").
- **D3. Keyed by what.** The Agent call's `tool_use_id`. PreToolUse carries `tool_use_id` (`docs/experiments/2026-10-03-probe-hook-identity.md`, key rows for main, subagent and teams-on main). The writer's transcript sibling `<transcript>.meta.json` carries the same id as `toolUseId`; the gate already reads that file for `agentType`, at line 27. Measured on this machine, 2026-10-29: 2488 of 2488 subagent meta files carry `toolUseId` (the oldest dated 2026-09-23). In 341 of 341 dispatches whose parent transcript was readable, the subagent's first user message equals `tool_input.prompt` once trailing newlines are stripped. Each record also binds `prompt=<sha256 of the dispatch message>`, and the gate requires that hash to match its own dispatch message. A record can therefore never lend its baseline to a different scope text.
  - **Fix rounds, re-dispatches, concurrency.** Every Agent call has a new `tool_use_id`, so every dispatch (original, fix round, re-dispatch) gets a fresh record at its own HEAD. A resumed writer (SendMessage) keeps its transcript and meta file, and with them its original record. Concurrent units never share a key.
  - **Cannot move forward.** The record is written in PreToolUse, before the subagent exists, so it precedes every commit the writer makes. Only main-session callers are recorded: `agent_type` empty, or matching `orchestrator` through `persona_matches_gate`. A writer that has the Agent tool (spec-master, scribe) cannot mint a record by spawning a nested Agent. The gate takes the **first** line for the id, so a later line appended for the same id (which needs a gate bypass anyway) loses. No persona other than the orchestrator dispatches a writer: `grep` of `agents/*.md` for spawns of lead-programmer, scribe and spec-master outside orchestrator.md finds none.
  - **Which dispatches.** Only those whose `subagent_type` or `name` resolves, through `identity_persona_name`, to `lead-programmer`, `scribe` or `spec-master` (the gate's own writer set, gate:29). This keeps the log from growing on explorer and reviewer dispatches.
- **D4. No record: fail closed.** When no usable record exists and the candidate set (Write/Edit paths plus commit-line files) is non-empty, the gate blocks (exit 2) with `BLOCKED (writer-scope-gate): no dispatch baseline for this writer (<why>) …` and logs `blocked: no dispatch baseline (<why>)`. "No usable record" covers: no `toolUseId`, no line for it, a prompt-hash mismatch, a malformed head, a missing commit, and a head that is not an ancestor of HEAD. With an empty candidate set the gate allows and logs, as today. Justification:
  1. The fallback is exactly the forgeable derivation, and the writer can create the "no record" state in-band. `git clean -fdX` deletes the gitignored `.claude/reviewed/`, its command text never names the path, and so `reviewed-path-gate.sh` lets it through. With a fallback, deleting the record would restore V1-V7. With fail closed, deleting it only blocks the writer itself.
  2. The gate already fails closed when it cannot judge (library missing: lines 62-66; transcript unreadable: lines 73-77).
  3. The real no-record cases are rare and recoverable. (a) A writer dispatched before the update lands (in flight at upgrade) blocks once if it changed files; the dispatcher re-dispatches, which records. (b) A nested writer spawned by a non-main caller: no such flow exists. (c) A harness whose meta file lacks `toolUseId`: none observed in 2488.
  - **Existing flows.** `tests/writer-scope-gate.test.sh` gets a `disp` helper that runs the real `dispatch-hygiene.sh` at each flow's dispatch point. The flows keep their verdicts, and one label changes (Step 2).
  - **agent-teams mode.** The lead is the main session (empty `agent_type`), so a teammate spawned through the Agent tool gets a record like any subagent. The 2026-10-03 probe classified the teammate's SubagentStop as "subagent-shaped". Whether a teammate's meta file carries `toolUseId` is **unmeasured** (the probe's teammate row is INCOMPLETE). If it does not, a teammate writer that changed files blocks with "no dispatch baseline (no record)". Recorded as Open Question 1, with a default.
  - **codex/cursor ports.** The gate is Claude-only (it needs `agent_transcript_path`), and so is `dispatch-hygiene.sh`. No change.
- **D5. `git replace` and graft immunity, ancestry.** After `cd "$project_dir"` the gate exports `GIT_NO_REPLACE_OBJECTS=1` and `GIT_GRAFT_FILE="$W/no-grafts"` (a path that never exists). Measured with git 2.43.0: `GIT_NO_REPLACE_OBJECTS=1` does **not** disable `.git/info/grafts`. `GIT_GRAFT_FILE=/dev/null` does disable it but prints the deprecation hint on stderr, which would pollute the block message. A non-existent path disables grafts silently. The dispatch hook reads HEAD with `GIT_NO_REPLACE_OBJECTS=1 git rev-parse --verify -q 'HEAD^{commit}'`. The gate then requires `git cat-file -e <head>^{commit}` and `git merge-base --is-ancestor <head> HEAD`, and otherwise blocks (D4). The scope verdict is tree-based (`git diff <start> -- <path>`) and never depends on ancestry. The ancestry check exists because the gate's restore advice (`git checkout $start -- p`) and its foreign-commit note (`rev-list $start..HEAD`) are wrong on a rewritten history, so the gate stops rather than print wrong advice. A record `head=none` (no commit at dispatch time) uses the empty tree (`git hash-object -t tree /dev/null`, the idiom of line 131) and skips the ancestry check.
- **D6. What stays.** Commit lines (`[<branch> <sha>]`) still add their commit's files to the candidate set (gate:126). They no longer move `$start`: `first` and the merge-base go away, and so does `t0` (gate:90), which no longer has a consumer. `cfile` still reads a contract with `git show "$start:<path>"`. Its `$start` is now the dispatch baseline, which closes V6. Everything else is unchanged: the scope rules, `in_scope`, `foreign`, the messages, the bare-bullet parse and the own-contract rule (tg-u2), and the library checks. `_portable_sha256` is added to the `declare -F` list (gate:62), so a missing hash function fails closed like the other library functions. The hash is the same on both sides: sha256 of `printf '%s' "$text"`, where `$text` is a command substitution of `jq -r` output (trailing newlines stripped). In the hook the text is the `prompt` variable (dispatch-hygiene:119). In the gate it is `$(cat "$W/prompt")`.

### Record format (one line, fields in this order, single spaces)
```
<UTC YYYY-MM-DDTHH:MM:SSZ> tool_use_id=<[A-Za-z0-9_]{1,128}> head=<40 hex|none> prompt=<64 hex> target=<lead-programmer|scribe|spec-master>
```
The gate matches field 2 exactly (`awk '$2 == "tool_use_id=<id>" {print; exit}'`), takes the first match, and checks field 4 against its own hash. `target` is recorded for audit and is not checked (the gate's persona comes from `agent_type` or the meta file). The tool_use_id class is deliberately `[A-Za-z0-9_]`, not the unit-id grammar, so `tests/state-access-constraints.test.sh` M5 sees no second spelling of `UNIT_ID_CHARCLASS`. Measured: that suite stays green on the prototype.

### Residual risks NOT closed by this plan (named, deferred)
- Writing the log by an obfuscated route that `reviewed-path-gate.sh` documents as STILL OPEN (a path built from a variable, a write relative to the directory after `cd`). Doing so is a self-authorized bypass under the protocol. Fail closed on a deleted log and first-match-wins on an appended one blunt it. A line inserted before the dispatcher's own line is not detected.
- Rewriting the writer's own transcript or meta file. The gate already trusts the transcript completely for the scope text, so this is outside the gate's threat model, as before.
- Content filters: a writer-set `filter.<x>.clean` or textconv in `.git/config` plus `.git/info/attributes` can make `git diff --quiet` report "no change". This is a separate hardening (`-c` overrides on the diff), out of scope here.
- Quiet Bash writes with no Write/Edit tool call and no commit line never become candidates (attribution comes from the transcript, by design since st-u3). Unchanged.
- Worktree-isolated writers: the hook records the main project's HEAD and the gate judges the main project tree (`CLAUDE_PROJECT_DIR`), as today.

### Prior defect history (`.claude/reviewed/` sweep, all records enumerated)
17 `.fail` records mention one of the two hooks. Those on this gate's own units: rp-u15 (1 FAIL, sonnet), tg-u1 (1 FAIL, sonnet), tg-u2 (1 FAIL, sonnet: the working-tree contract read that this plan's V6 extends). Each unit that hardened this gate failed review once on the sonnet tier. The orchestrator must not tag sgb-u2 cheaper than sonnet, and should consider opus. The `marker-audit.sh --notes` sweep: see Risks. The `.pass` notes of tg-u2 carry two NOTE[spec] lines (stale `ac=6` text in tg-u2.md; the 4-of-5 replay count). Both are disposed of as not affecting this plan, because neither touches the baseline.

## Clarifications
1. Functional scope & success criteria: Clear
2. Domain entities / data model: Partial
3. User interaction flow: Clear
4. Non-functional attributes (perf, security, scale): Partial
5. External dependencies & integrations: Partial
6. Edge cases / failure handling: Partial
7. Technical constraints & tradeoffs: Partial
8. Terminology consistency: Partial
9. Completion / acceptance signals: Clear

- 2026-10-29 Domain entities / data model: Q What key links a writer's stop to its dispatch record, and what one record holds? → A (self-resolved): the Agent call's `tool_use_id` (PreToolUse `tool_use_id` = meta `toolUseId`; 2488/2488 metas carry it), bound to the sha256 of the dispatch message; fields per "Record format".
- 2026-10-29 Non-functional attributes (perf, security, scale): Q Which path can the writer's tools not write, and what does a log line per dispatch cost? → A (self-resolved): `.claude/reviewed/dispatch-baseline.log` (reviewed-path-gate denies writers on Write/Edit and Bash, observed in this session). One line of ~200 bytes per writer dispatch only, and one `awk` scan per writer stop.
- 2026-10-29 External dependencies & integrations: Q Which dispatch-time hook records, and is any other hook needed? → A (self-resolved): `dispatch-hygiene.sh` only. reviewer-route-gate was rejected (a five-copy port-invariant core). harness-integrity-gate was not needed and is not editable by a subagent.
- 2026-10-29 Edge cases / failure handling: Q With no record, does the gate fail closed or fall back to today's derivation? → A (self-resolved): fail closed when the candidate set is non-empty, and allow when it is empty (D4). The fallback is the forgeable path, and `git clean -fdX` can create the no-record state in-band.
- 2026-10-29 Edge cases / failure handling: Q What happens to fix rounds, re-dispatches, resumes and concurrent units? → A (self-resolved): a new tool_use_id gives a fresh record; a resume keeps its record; concurrent units have distinct keys (D3).
- 2026-10-29 Technical constraints & tradeoffs: Q How is the gate made immune to replace objects and grafts, and what does a non-ancestor baseline do? → A (self-resolved): export `GIT_NO_REPLACE_OBJECTS=1` and `GIT_GRAFT_FILE=<non-existent path>`, measured on git 2.43.0. A non-ancestor baseline blocks (D5).
- 2026-10-29 Terminology consistency: Q Is "baseline" already a glossary term with another meaning? → A (self-resolved): `docs/harness-glossary.md` defines **session baseline commit** (`.claude/.session-baseline.<session_id>`, SessionStart) and **unreachable baseline**. The new artifact is named **dispatch baseline** to keep it apart. Use "dispatch message" for the transcript's first user message, never "contract" (glossary entry **dispatch message**). The new term goes to scribe (Scribe update hint).
- 2026-10-29 Edge cases / failure handling: Q What happens to agent-teams teammates whose meta file may lack `toolUseId`? → A: deferred as Open Question 1 (default: accept fail closed, measure with a probe later).

## Risks/dependencies
- **Sequencing:** sgb-u1 must PASS and be committed before sgb-u2 is dispatched. Both edit `tests/writer-scope-gate.test.sh`, a `.claude/hooks/scripts/` mirror and the persona-selection config's `fileHashes`, so they never run in parallel. sgb-u2 consumes the record format sgb-u1 writes.
- **Upgrade window:** once sgb-u2 lands, any writer dispatched before sgb-u1 landed has no record. It blocks once if it changed files, and recovery is a re-dispatch. The orchestrator should land sgb-u2 when no writer is in flight. sgb-u1 alone is harmless (records written, not yet read).
- **The live gate:** `hooks/scripts/writer-scope-gate.sh` is this project's live SubagentStop gate. Once sgb-u2's commit lands, every writer stop in this repo, sgb-u2's own included, is judged by the new code. sgb-u2's own dispatch happens after sgb-u1 is live, so its record exists. A `bash -n` failure blocks every writer: the contract makes `bash -n` the first check after the gate edit.
- **Validate cost:** `tests/validate.sh` with `ANTISLOP_VALIDATE_LANES=4` takes about 260 s (tg-u2-fix1 measurement). `tests/reviewed-dir-leak-guard.test.sh` (validate.sh:1390) fails if any suite writes into the sandbox's own `.claude/reviewed/`. All four suites that run `dispatch-hygiene.sh` set `CLAUDE_PROJECT_DIR` to their own temp dirs (checked), and on the prototype `dispatch-hygiene`, `review-gating-off`, `state-access-constraints`, `harness-integrity-gate` and `reviewed-path-gate` all stay at fail=0. The full validate run is still the criterion that decides. Measured on the committed prototype of both units together (with mirrors and fileHashes from `node bin/cli.js --update`): `ANTISLOP_VALIDATE_LANES=4 bash tests/validate.sh` gave rc=0, `Counts: OK=3442 FAIL=0 WARN=2 SKIP=0`, in 392 s.
- **Gate-mentions in commands:** a Bash command whose text names the reviewed-marker directory together with a redirect or writer is refused for lead-programmer (observed for spec-master). Contracts therefore keep that path out of every command and use the Edit tool for file content. The persona-selection config is never named in a Bash command (Set A), and is staged with `git add -u -- .claude ':(exclude).claude/agent-memory'`.
- **marker-audit sweep:** `bash bin/marker-audit.sh . --notes --surface=<path>` was started for the three touched source paths. Its result is recorded under "Sweep result" below. The sweep is best-effort; an empty result proves nothing.
- **Replay source:** `docs/audits/unit-outcomes/2026-10-06.jsonl` has one `vacuous`/`host` unit intersecting these files: gh413, on `hooks/scripts/dispatch-hygiene.sh` (see CHK7).

### Sweep result
`marker-audit.sh --notes` (2026-10-29), with the disposition of each note:
- `writer-scope-gate.sh` (3 notes). The tg-u2 NOTE[code] D1 is this plan. The cos-u5 NOTE[spec] (the apostrophe in a name is not caught by the quote case at :238) is unrelated to the baseline and is left as it is. The st-u3 NOTE[code] (one malformed line empties every path) was superseded by rp-u15's line-by-line parse, and is untouched.
- `dispatch-hygiene.sh` (12 untagged or spec notes, units 159-261, fc-2, gh-209, gh-214, all already dispatched). None concerns the insert point. Unit 220's note ("`reason` is interpolated into the audit log unscrubbed") is avoided by design: every record field is validated by regex (`[A-Za-z0-9_]` id, 40-hex head, 64-hex hash, a fixed target set) before it is written.
- `tests/writer-scope-gate.test.sh`: 0 notes. The sweep is best-effort, and an empty result proves nothing.

## Constitution check (.claude/constitution.md v1.1.0)
- P1 "Verify, don't assume": satisfied. The variants, the toolUseId coverage, the prompt equality, the graft behaviour and the neighbouring suites were measured, and every criterion carries a measured mutation.
- P2 "Prefer deterministic scripts over LLM re-derivation": satisfied. Mirrors and `fileHashes` change only through `node bin/cli.js --update`, never by hand.
- P3 "Version-stamp discipline": satisfied. Neither unit touches `agents/*.md` or `templates/`, so `version-stamp-check.sh` reports `touched: no`, which is criterion 6 of each unit. No bump and no CHANGELOG entry is required.
- P5 "`tests/validate.sh` is the merge gate": satisfied. A full validate run is a criterion of each unit.

## Step 1 — sgb-u1: dispatch-hygiene.sh records the dispatch baseline
Contract: [contracts/sgb-u1.md](2026-10-29-scope-gate-baseline-hardening/contracts/sgb-u1.md)
- Affected files: `hooks/scripts/dispatch-hygiene.sh`, `tests/writer-scope-gate.test.sh`, `.claude/hooks/scripts/dispatch-hygiene.sh` (generated), the persona-selection config's `fileHashes` (generated).
- Acceptance: the contract's criteria 1-8 (new `(ad)` cases green, old suite labels all present, `tests/dispatch-hygiene.test.sh` green, mirror parity, modes, commit scope, version stamp, full validate).

## Step 2 — sgb-u2: writer-scope-gate.sh takes `$start` from the dispatch baseline only
Contract: [contracts/sgb-u2.md](2026-10-29-scope-gate-baseline-hardening/contracts/sgb-u2.md)
- Affected files: `hooks/scripts/writer-scope-gate.sh`, `tests/writer-scope-gate.test.sh`, `.claude/hooks/scripts/writer-scope-gate.sh` (generated), the persona-selection config's `fileHashes` (generated).
- No old label changes. Flows that commit as the writer set `BASE` to the commit the dispatch saw (23 cases go red without it, measured). `(ab)`'s re-dated case keeps its label: its transcript is dispatched at `B2`, so the amended commit is a commit after the baseline. The amended-pre-dispatch-commit scenario is a new case `(ae)` 8 (not an ancestor).
- Acceptance: the contract's criteria 1-8.

## Open Questions
1. **agent-teams teammates without `toolUseId`** (CHK6). Unmeasured: does a teammate's `<transcript>.meta.json` carry `toolUseId`? If not, a teammate writer that changed files blocks with "no dispatch baseline (no record)". Options: (a, recommended default) accept fail closed now, and run `scripts/probe-hook-identity.sh`-style probe before the next agent-teams session; (b) add a fallback to "latest record with the same prompt hash" for metas lacking `toolUseId`. (b) reopens a small forward-move window when the dispatcher repeats an identical prompt while the first copy runs. This plan proceeds on (a). Neither unit depends on the answer.

## Self-check
- CHK1: Is the gate's behaviour defined for every "no usable record" cause (no meta id, no line, hash mismatch, malformed head, missing commit, non-ancestor)? — PASS (D4 list; sgb-u2 criteria 2 covers no-line, mismatch and non-ancestor by label)
- CHK2: Do Step 1 and Step 2 agree on the record format and the hash canonicalisation? — PASS (both contracts cite "Record format" and D6's `printf '%s'` of a command substitution; sgb-u2's test drives the real sgb-u1 producer, so drift turns its cases red)
- CHK3: Is "existing flows stay green" machine-checkable, given the suite's labels change? — FAIL (ambiguous) — revised in place: both units carry a `comm` criterion against the f566aeef suite run from `git archive` (114 labels, measured): `missing=0` with `added=8` (sgb-u1) and `added=22` (sgb-u2), both measured on the prototype.
- CHK4: Do D1 and the contract agree that the record precedes `mode off` and override exits? — PASS (sgb-u1 ordered edit anchors on line 123; case `(ad) mode off still records` plus its mutation)
- CHK5: Is the forward-move rule ("cannot move past the writer's own commits") backed by a criterion? — PASS (sgb-u1 nested-caller case; sgb-u2 first-record-wins case, each with a mutation)
- CHK6: Is agent-teams behaviour defined? — FAIL (missing) — converted to Open Question 1
- CHK7: Does sgb-u1 criterion 4 (mirror parity on `dispatch-hygiene.sh`) still fail under its own `mutation:` line, given gh413's recorded class vacuous/host? — PASS (mutation: skipping `--update` makes `cmp` exit 1; the criterion runs in this host, not a nested one)
- CHK8: Does each criterion avoid rm/rmdir/find -delete and deleting traps, and avoid naming the persona-selection config or the reviewed-marker directory in a Bash command? — PASS (checked over both contracts' `run:` lines)
- CHK9: Is every Goal clause mapped to a criterion? — PASS (G1-G5 mapping above)
- Ubiquitous-language (advisory): "dispatch baseline" is new (lens 3, scribe candidate); "baseline" alone is avoided where it could be read as **session baseline commit**; "dispatch prompt" (a synonym under **dispatch message**) is not used in this plan's own prose except in quoting.

## Scribe update hint
- `docs/harness-glossary.md`: add **dispatch baseline**: the main session's HEAD at the moment it dispatched a writer, recorded by `dispatch-hygiene.sh` under the Agent call's `tool_use_id` (with the sha256 of the dispatch message) in `.claude/reviewed/dispatch-baseline.log`. `writer-scope-gate.sh` judges the writer's changes against it and blocks when it has none. Distinct from **session baseline commit**. Link from **dispatch message** (its scope-reading sentence about contracts read "at the baseline").
- README "Known limitations" (scope gate): the residual risks listed in Context.
- Knowledge proposals only. Nothing in this plan writes CONTEXT.md, the glossary or README.

## Dispatch (fast path, 2 units, sequential)
1. [sgb-u1](2026-10-29-scope-gate-baseline-hardening/contracts/sgb-u1.md), first.
2. [sgb-u2](2026-10-29-scope-gate-baseline-hardening/contracts/sgb-u2.md), only after sgb-u1 has PASSed and its commit is on `master`.
