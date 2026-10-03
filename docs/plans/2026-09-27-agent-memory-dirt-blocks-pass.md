# Agent-memory dirt must not block an unrelated unit's PASS

**Date:** 2026-09-27
**Author:** spec-master
**Status:** FINAL — 0 open questions
**Slug:** `agent-memory-dirt-blocks-pass`
**Dispatchable units:** 3 (fast path, ≤5 — no `task-master`, no tracker publish per ADR-0024 Step 3's ≥6 publish threshold)

---

## Goal

Decouple a persona's own **memory-scope write** from the v3 `.pass` marker's
clean-tree precondition, so an uncommitted `.claude/agent-memory/**` file left
behind by one persona's session can never block an unrelated, otherwise-correct
unit's PASS — while keeping memory notes landing in tracked history, by making
the owning persona commit them before its turn ends rather than exporting that
cost to whoever reviews next.

Concretely, three outcomes:

1. The reviewer's precondition stops counting `.claude/agent-memory/**` as
   blocking dirt — except when that unit's own affected-files set names a path
   under it, in which case the unexcluded whole-tree form still applies.
2. Every memory-granted persona is instructed to commit its own memory-scope
   writes before ending its turn.
3. Both changes are guarded against silent drift by a `tests/validate.sh`
   branch-agreement check, and recorded in an ADR + the harness glossary.

## Context

### The measured problem

Across this single long orchestration session, a persona's
`.claude/agent-memory/<persona>/*` write was left uncommitted at the end of that
persona's dispatch at least 5 times. Because the reviewer's v3 PASS precondition
is a **whole-tree** check, that stray dirt repeatedly blocked an unrelated unit's
PASS, forcing the orchestrator to identify the owning session, resume it, and ask
it to commit one file before the blocked unit's review could complete.

Two commits in this very batch are nothing but that remediation:

- `23c0788 docs(agent-memory): commit item04-3's post-commit memory write`
- `c28152f docs(agent-memory): commit item04-2's post-commit addendum`

### Where the precondition actually lives (measured, not assumed)

It is **persona prose, not a hook**. No hook enforces it. Exactly two live files
carry it, in two passages each:

- `agents/reviewer.md:57-58` — "Verify the reviewed state is committed before
  writing a marker — no tracked file carries an uncommitted change."
- `agents/reviewer.md:115-116` — "Run `git diff --quiet HEAD` — it must exit 0,
  so no tracked file carries an uncommitted change."
- `.claude/agents/reviewer.md:58` and `:116` — the generated mirror of both.

`hooks/scripts/lib/stop-gate-core.sh` does sample the tree, but not for this: its
`git status --porcelain` at `:588` feeds the microworld-skip decision, and its
only consumer is the `dirty=false && moved=false` early-allow at `:642`. Memory
dirt therefore costs an unnecessary `testAndLintCommand` run at turn-end, but
does **not** block there. Out of scope.

The codex and cursor ports carry only the **v2** marker instruction
(`adapters/cursor/agents/reviewer.md:65`,
`adapters/codex/agents/reviewer.toml:68`) with no `commit:` field and no
clean-tree check at all. They are out of scope, and
`tests/adapter-protocol-parity.test.js:91,113` already marks the protocol's
memory section `deferred` on both ports.

### The mechanism, measured exactly

`git diff --quiet HEAD` does not see untracked files. Proven in a throwaway repo:
a brand-new, never-added memory note alone leaves it at **exit 0** (invisible);
editing a *tracked* `MEMORY.md` takes it to **exit 1**.

That is precisely why every memory write blocks: the memory protocol's step 2
mandates a pointer line in `MEMORY.md`, and all 8 `MEMORY.md` files are tracked
(`git ls-files '.claude/agent-memory/*/MEMORY.md'` → 8). So *every* compliant
memory write modifies a tracked file, whatever the note file's own status.

### The whole-tree check's original rationale — verified before narrowing

From `docs/plans/2026-08-07-commit-anchored-pass-markers.md:363-367`, verbatim:

> `git diff --quiet HEAD` must exit 0 — no tracked file carries an uncommitted
> change. Deliberately *not* `git status --porcelain`: untracked scratch files
> and the gitignored marker write must not trip it. **Safe as a whole-tree check
> because the protocol guarantees only one unit is ever mid-review**
> (`templates/persona-protocol.md:158-163`).

The whole-tree form rests entirely on the **unit-exclusivity invariant**. That
invariant is about *concurrent review units*. It does not cover a persona's own
memory bookkeeping, because a memory-scope write (a) is never part of any unit's
reviewed deliverable, (b) is produced by personas that are not under review at
all (`spec-master`, `task-master`), and (c) survives its author's session,
outliving the review window entirely. ADR-0015's purpose — anchoring the marker
to a commit so work lost to history is detectable (`commit:` + dispatch-hygiene
H3) — likewise has no stake in a memory note, which is never in the anchored
commit. **Excluding `.claude/agent-memory/**` therefore removes a class the
stated rationale never contemplated; it weakens nothing the check was protecting.**

### This defect was already diagnosed and never actioned

`bash bin/marker-audit.sh . --notes --surface=agents/reviewer.md` surfaces a note
from **unit #257 — the very unit that introduced the v3 format**:

> `agents/reviewer.md:92` — whole-tree `git diff --quiet HEAD` yields
> false-positive FAILs. Live right now: `.claude/agent-memory/spec-master/MEMORY.md`
> is tracked+modified, so a reviewer following the new v3 text literally would FAIL
> this very unit even though `agents/reviewer.md` is committed and clean. Plan
> lines 363-367 chose whole-tree deliberately ("only one unit is ever
> mid-review"), but that reasoning covers concurrent units, not persona
> agent-memory writes. **Suggest scoping to the unit's affected paths.**

Same diagnosis, same remedy, ~7 weeks unactioned — another instance of the
"PASS-note warnings don't propagate" class. This spec closes it.

### Cost the project has already paid working around it

Five separate `lead-programmer` memory notes exist solely to navigate ambient
dirt in the shared tree:
`feedback_cc2_bare_add_blocked_by_sibling_dirt.md`,
`technique_pathspec_exclude_add_a_amid_concurrent_dirt.md`,
`feedback_check_index_before_commit.md`,
`feedback_shared_worktree_stash_race.md`,
`feedback_never_unconditional_stash_pop.md`.
`scribe`'s `feedback_context_commit_before_reviewer.md` states the discipline
rule this spec is codifying — but only in that persona's private memory, never in
its body or the shared protocol.

### Options evaluated

**Option 1 — gitignore `.claude/agent-memory/` entirely. REJECTED.**
The durability question resolves in this option's favour: nothing reads memory
through git. No file under `hooks/scripts/**`, `bin/**`, `agents/**`,
`templates/**`, `adapters/**` or `tests/**` uses `git show`/`git log`/`git
cat-file`/`git blame` against a memory path; `bin/agent-memory-size-check.sh` is
pure filesystem (`du -sk`); `.claude/persona-config.json` references
`.claude/agent-memory` nowhere (empty `protectedPaths`, no `fileHashes` entry);
`.gitattributes` already `export-ignore`s the directory from `git archive`.
Rejected anyway, on four other grounds:

- The **harness-injected** memory system prompt asserts "Since this memory is
  project-scope and **shared with your team via version control**, tailor your
  memories to this project." The project cannot edit that injection; gitignoring
  would make a standing instruction false for every memory-granted persona.
- It discards 218 tracked files / 210 commits of institutional knowledge from
  future clones, with no recovery route — the same shape as
  `project_config_recovery_has_no_automated_route`, where `git restore` is the
  only lossless path.
- `.claude/agent-memory/` is absent from `bin/cli.js`'s
  `OPERATIONAL_GITIGNORE_PATTERNS` (`bin/cli.js:155-171`), so adding it is a
  **cross-repo policy change** for every consumer project's next `--update`, not
  a local fix.
- It fixes one instance of a general class. `docs/plans/**`, `CONTEXT.md` and
  `docs/harness-glossary.md` produce identical blocking dirt — measured live at
  authoring time: `docs/adr/0024-*.md` and `docs/harness-glossary.md` were both
  ` M` from a concurrent session.

Worth recording: `docs/plans/2026-09-25-item05-agent-memory-dedup.md:138,232`
already describes `.claude/agent-memory/*` as "(gitignored, per-clone state)".
That is **false** — the directory is tracked. No unit acted on it destructively
(`2c27976` touched no memory file), but the mis-modelling is itself a cost of
leaving this ambiguous.

**Option 2 — a protocol discipline rule. ADOPTED (as half the fix).**
Cheap, preserves durability, and matches the shape of the WIP-sentinel and
pending-review conventions. Alone it is insufficient — prose is unenforced, and
one missed turn reintroduces the block — which is why it ships together with
Option 3 rather than instead of it.

**Option 3 — narrow the precondition. ADOPTED (as the other half).**
Verified above against the original rationale. Narrowed **only** to
`.claude/agent-memory/**`, and **conditionally**: if the unit's own affected
files name a path under it, the unexcluded form still applies, so a memory file
that genuinely is the deliverable cannot slip. A broader narrowing to "the unit's
affected-files set" is explicitly rejected: it would trust the dispatch packet's
list, discarding the over-approximation that catches an uncommitted file the
packet forgot to name.

**Option 4 — reviewer auto-commits stray memory dirt. REJECTED, decisively.**
The reviewer would author a commit of content it did not review, on behalf of
another agent that may still be mid-write. This repo has measured that race
(`feedback_shared_worktree_stash_race`) and its own memory already forbids the
move: "do not improvise — do not stash it … write the WIP sentinel … and report
the blocker up the chain." It also breaches ADR-0002, which scopes the reviewer's
write custody to `.claude/reviewed/`.

**Adopted: Option 3 + Option 2, together.** 3 removes the false coupling
unconditionally and immediately; 2 keeps memory reaching tracked history by the
owner's own discipline rather than by an unrelated unit's gate.

### Surfaces, counted exactly

The protocol's `## A note on \`memory\`` section exists in **11** live files, in
two wordings, because slim- and full-tier personas are rendered from different
sources:

| Wording | Files |
| --- | --- |
| **full** (5) | `templates/persona-protocol.md:647-653` (source), `.claude/persona-protocol.md`, `.claude/agents/{lead-programmer,spec-master,task-master}.md` |
| **slim** (6) | `templates/persona-protocol-slim.md:85-90` (source), `.claude/persona-protocol-slim.md`, `.claude/agents/{agent-auditor,explorer,researcher,scribe}.md` |

Both sources must be hand-edited: the 4 memory-granted personas are
`lead-programmer`, `spec-master`, `task-master` (full tier, per
`PROTOCOL_SECTIONS_BY_PERSONA` at `bin/cli.js:731+`) and **`scribe`** — which is
slim tier. Editing only the full template would miss `scribe`, the persona whose
own memory already records this rule.

### Measured command choice (this is load-bearing)

Four pathspec forms were tested against git 2.43.0 in a throwaway repo, with
memory-only dirt and with real dirt, from the repo root and from a subdirectory:

| Form | memory-only dirt | real dirt (root) | real dirt (subdir) |
| --- | --- | --- | --- |
| `-- . ':(exclude).claude/agent-memory'` | 0 | 1 | **0 — false clean** |
| `-- ':(exclude).claude/agent-memory'` | 0 | 1 | 1 |
| `-- ':/' ':!.claude/agent-memory'` | 0 | 1 | 1 |
| **`-- ':/' ':(exclude,top).claude/agent-memory'`** | **0** | **1** | **1** |

The intuitive `. ':(exclude)…'` form is **CWD-dependent and silently reports a
clean tree from a subdirectory**. The prescribed form is the last row: `:/`
anchors the inclusion at the repo root and `,top` anchors the exclusion there
too, so the command is correct from any working directory.

## Clarifications

1. Functional scope & success criteria: Missing
2. Domain entities / data model: Partial
3. User interaction flow: Partial
4. Non-functional attributes (perf, security, scale): Clear
5. External dependencies & integrations: Partial
6. Edge cases / failure handling: Missing
7. Technical constraints & tradeoffs: Partial
8. Terminology consistency: Clear
9. Completion / acceptance signals: Partial

(Scored against the request as received; each Partial/Missing category's
resolution is recorded below.)

- 2026-09-27 Functional scope & success criteria: Q Which of the four candidate
  options (or combination) is the fix? → A (self-resolved): Options 3 + 2
  together; 1 and 4 rejected on measured grounds. See "Options evaluated" — the
  deciding evidence is that the whole-tree form's own stated rationale
  (`docs/plans/2026-08-07-commit-anchored-pass-markers.md:363-367`) rests on the
  unit-exclusivity invariant, which does not cover memory writes.
- 2026-09-27 Domain entities / data model: Q Where is the v3 precondition
  actually implemented, and does it see untracked files? → A (self-resolved):
  persona prose only (`agents/reviewer.md:57-58` and `:115-116`, plus the
  generated mirror), no hook. `git diff --quiet HEAD` cannot see untracked
  files — proven in a throwaway repo. The block comes from the tracked
  `MEMORY.md` index line the memory protocol mandates, not from the note file.
- 2026-09-27 User interaction flow: Q Which personas owe the commit, and at
  which point in their turn? → A (self-resolved): the 4 personas with
  `memory: project` (`lead-programmer`, `scribe`, `spec-master`, `task-master`),
  before ending the turn. Delivered via the protocol's existing conditional
  `## A note on \`memory\`` section, so a persona without a `memory:` field
  reads it as inapplicable (satisfies constitution P4 with no new phrasing).
- 2026-09-27 External dependencies & integrations: Q Do the adapters and
  downstream consumer repos need changes? → A (self-resolved): no. The codex and
  cursor reviewer ports carry only the v2 marker instruction with no clean-tree
  check, and `tests/adapter-protocol-parity.test.js:91,113` already marks the
  protocol memory section `deferred` on both. Consumers receive both changes
  automatically through the version bump + their own `--update`; no
  `OPERATIONAL_GITIGNORE_PATTERNS` change is involved (that would have been
  Option 1's cost).
- 2026-09-27 Edge cases / failure handling: Q What if a unit's own deliverable
  is a file under `.claude/agent-memory/`? → A (self-resolved): the exclusion is
  conditional — when the unit's `## Affected files` names a path under it, the
  reviewer runs the unexcluded whole-tree form. Two further edges resolved: the
  CWD-dependent false-clean pathspec (see the measured table — prescribed form
  is root-anchored on both sides), and the pre-existing untracked-file hole
  (`git ls-files --error-unmatch` covers only inspected files) which this spec
  deliberately does **not** touch — see Risks R4.
- 2026-09-27 Technical constraints & tradeoffs: Q What was the whole-tree
  check's original rationale, and does narrowing weaken it? → A (self-resolved):
  quoted verbatim in Context. It rests solely on the unit-exclusivity invariant,
  which is about concurrent review units. Narrowing to exclude only
  `.claude/agent-memory/**` weakens nothing it protected. Unit #257's own
  reviewer reached the same conclusion at the time (see the marker-note quoted
  in Context).
- 2026-09-27 Completion / acceptance signals: Q What are the machine-checkable
  criteria? → A (self-resolved): per-step criteria below. Every criterion's
  baseline was measured RED before authoring: the sentinel sentence, the
  exclusion pathspec, and "ambient dirt" each return 0 hits repo-wide today.

### `ubiquitous-language` (prose mode) — advisory, non-blocking

Checked against the domain glossary `CONTEXT.md`, whose own
**domain glossary (vs. harness glossary)** entry (`CONTEXT.md:498-510`) routes
marker/gate/hook mechanics to `docs/harness-glossary.md` — so most of this
spec's vocabulary is out of this skill's declared scope by construction.

- **Lens 1 (glossary term, divergent meaning):** nothing found. The request's
  "v3 PASS-marker precondition", "WIP-sentinel", "pending-review-flag" and
  "`memory: project` grant" all match repo usage.
- **Lens 2 (new synonym for a defined term):** one finding. "memory-scope
  write" (used throughout the request and this spec) is a synonym for
  `docs/harness-glossary.md:764`'s **agent-memory write**. Resolution: fold, not
  duplicate — Unit 3 adds "memory-scope write" as an explicit synonym line on
  the existing entry rather than creating a second one.
- **Lens 3 (load-bearing new term, no entry):** two findings, both
  harness-mechanics, both routed to `scribe` in Unit 3. **ambient dirt** —
  uncommitted working-tree residue owned by a different persona's session, which
  a later unrelated agent must attribute and clear before its own work can be
  signed off (0 hits repo-wide today). **clean-tree precondition** — the named
  concept is implemented in `agents/reviewer.md` but defined in neither glossary.

## Risks / dependencies

- **R1 — Mirror regeneration is script-owned.** `.claude/agents/*.md`,
  `.claude/persona-protocol{,-slim}.md` and `.claude/persona-config.json`'s
  `fileHashes` must be produced by `node bin/cli.js --update --force-render`,
  never hand-edited (constitution P2). Per
  `project_protocol_amendments_do_not_propagate`, `--update` **short-circuits on
  an unchanged version** — so the order is strictly **bump → CHANGELOG →
  `--update --force-render`**. An implementer reporting "already current" means
  the bump did not land; that is an escalation, never something to work around.
- **R2 — The commit route cannot name the harness config file.**
  `--force-render` rewrites `.claude/persona-config.json`, a Set A literal that
  `harness-integrity-gate.sh` denies in *any* Bash command text, including a
  `git add` or a commit message. Use the route recorded in
  `technique_pathspec_exclude_add_a_amid_concurrent_dirt`: stage every other path
  individually, then `git add -A -- ':/' ':(exclude,top)<other agents' dirt
  dirs>'`, then a plain `git commit -m` that never spells the literal. Do not
  attempt wildcards — the gate's glob-normalizer matches through them and treats
  that as a detected bypass.
- **R3 — Ambient dirt at dispatch time.** At authoring time
  `docs/adr/0024-ceremony-reduction-solo-operator.md` and
  `docs/harness-glossary.md` were both ` M` from a concurrent session. Unit 3
  edits `docs/harness-glossary.md`. If that file is still dirty from another
  session at dispatch, do not stash or sweep it — report and wait.
- **R4 — Two adjacent defects deliberately NOT fixed here.** Both are
  `marker-audit` notes from unit #257 on the same bullet, left standing on
  purpose to keep this change auditable:
  (a) `git ls-files --error-unmatch` covers only files the reviewer *inspected*,
  so a never-added untracked deliverable still slips both checks — a real hole,
  independent of memory dirt, needing its own spec;
  (b) the terminology split "the unit's own **review** range" vs "the unit's own
  **reviewed** range" (`agents/reviewer.md:116` — the exact line Unit 1 edits;
  flagged as a `NOTE[code]` on unit `gh-step13-heavy-trigger-wiring`).
  Disposition for both: out of scope, recorded here so the next reader sees they
  were seen and declined, not missed.
- **R5 — Dirt classes this spec does not cover.** Uncommitted `docs/plans/**`,
  `CONTEXT.md` and `docs/harness-glossary.md` block identically. They are
  deliberately **not** excluded, because for documentation units those files
  *are* the reviewed deliverable, so excluding them would materially weaken the
  precondition. They are covered only by Option 2's discipline, which is why
  Option 2 is not optional.
- **R6 — No prior FAIL on this surface.** `.claude/reviewed/` holds 128 `.fail`
  records; none is for a unit narrowing this precondition (the class exists only
  as unactioned PASS-notes). No Implementer-tier ratchet applies from prior
  defect history. Note `.claude/reviewed/` is gitignored per-clone state, so an
  empty sweep is not proof.
- **R7 — `tests/validate.sh` is not version-stamped.**
  `hooks/scripts/version-stamp-check.sh:62` matches only `agents/*.md` and
  `templates/*`, so Unit 2 requires no version bump. Verified, not assumed.

## Constitution check (.claude/constitution.md v1.1.0)

- P1 "Verify, don't assume" (MUST): satisfied — every load-bearing claim in this
  spec was measured, not inferred: the tracked/untracked asymmetry and all four
  pathspec forms in a throwaway repo; the 11 protocol surfaces and the 5/6
  full/slim split by `git grep`; the original rationale quoted verbatim from the
  2026-08-07 plan; the version-stamped path set read out of
  `version-stamp-check.sh`; every new criterion's baseline confirmed at 0 hits.
- P2 "Prefer deterministic scripts over LLM re-derivation" (MUST): satisfied —
  all mirrors and `fileHashes` are regenerated by `node bin/cli.js --update
  --force-render`; hand-editing them is on every unit's Do-NOT-touch list.
- P3 "Version-stamp discipline" (MUST): satisfied — Unit 1 touches `agents/*.md`
  and `templates/*`, so its bump (`.claude-plugin/plugin.json` +
  `package.json`) and CHANGELOG entry land in the **same commit** as the content,
  per-commit semantics. Unit 2 touches only `tests/validate.sh` (not
  version-stamped, per R7) and needs none. Unit 3 touches only `docs/` and needs
  none.
- P4 "Optional personas degrade gracefully" (SHOULD): satisfied — the new rule
  lands inside the protocol's already-conditional
  `## A note on \`memory\`` section ("If your persona has a `memory` field
  set…"), so it is inert for a persona without the grant. The reviewer-side edit
  names no optional persona.
- P5 "`tests/validate.sh` is the merge gate" (MUST): satisfied — `bash
  tests/validate.sh` exiting 0 is a criterion on all three units, and it is the
  runner for `adapter-protocol-parity` and `context-glossary-links` (no
  `package.json` `scripts` block exists).

---

## Step 1 — Narrow the precondition and add the memory-commit rule

Both halves ship as one unit deliberately: shipping the narrowing alone would
open an interval in which memory dirt no longer blocks but nothing requires
memory to be committed, so notes would quietly stop reaching tracked history.

**Affected files (hand-edited):**
`agents/reviewer.md` (two passages: `:57-58`, `:115-116`),
`templates/persona-protocol.md` (§ `A note on \`memory\``, after `:653`),
`templates/persona-protocol-slim.md` (§ `A note on \`memory\``, after `:90`),
`.claude-plugin/plugin.json`, `package.json`, `CHANGELOG.md`.

**Affected files (script-generated — never hand-edit):**
`.claude/agents/*.md`, `.claude/persona-protocol.md`,
`.claude/persona-protocol-slim.md`, `.claude/protocol-digest.md`, and the harness
config's `fileHashes`.

**Edit A — `agents/reviewer.md:115-116`.** Replace the bare command with the
root-anchored exclusion, and state the exception. The sentence "no tracked file
carries an uncommitted change" becomes "no tracked file **outside
`.claude/agent-memory/`** carries an uncommitted change", and the command becomes
exactly:

```
git diff --quiet HEAD -- ':/' ':(exclude,top).claude/agent-memory'
```

Add, in the same bullet: the exclusion is deliberate and narrow — a persona's own
memory-scope write is never part of a unit's reviewed deliverable, so another
session's uncommitted memory note must not block this unit's PASS; **if this
unit's own `## Affected files` names a path under `.claude/agent-memory/`, drop
the exclusion and run `git diff --quiet HEAD` unexcluded**, because then the
memory file is the deliverable. Note that the form `-- . ':(exclude)…'` is
CWD-dependent and must not be used.

**Edit B — `agents/reviewer.md:57-58`.** Same narrowing in the summary bullet:
"no tracked file outside `.claude/agent-memory/` carries an uncommitted change
(see the On PASS bullet for the exact command and the one exception)."

**Edit C — both protocol sources.** Append to the existing
`## A note on \`memory\`` section, opening with this **sentinel sentence
verbatim, byte-identical in both files** (a validate.sh guard keys off it in
Step 2):

> **Commit your own memory-scope writes before ending your turn.**

Then, in the full template (`templates/persona-protocol.md`), elaborate: the note
file *and* its `MEMORY.md` index line are yours to land, in their own commit
(`docs(agent-memory): …`), staged by explicit path. Leaving them uncommitted
makes them **ambient dirt** — residue in a shared working tree that a later,
unrelated agent has to notice, attribute to you, and get cleared before its own
work can be signed off. This is the same discipline as the WIP sentinel and the
pending-review flag: a cost you pay yourself instead of exporting it to whoever
comes next. Never commit *another* agent's memory files to clear your own path —
report that instead. The slim template (`templates/persona-protocol-slim.md`)
carries the sentinel sentence plus one condensed sentence, matching that file's
tighter register.

Phrase this **without naming another protocol section header**.
`bin/cli.js`'s `assertNoDanglingCrossReferences` throws when a kept section's
text references a header that persona's row drops; keeping the paragraph
self-contained sidesteps that class entirely, and is why the WIP-sentinel
comparison above is phrased descriptively rather than as a cross-reference.

**Ordering (R1):** bump `.claude-plugin/plugin.json` + `package.json` → add the
CHANGELOG entry → `node bin/cli.js --update --force-render`. Reversing this makes
`--update` short-circuit and regenerate nothing.

**Acceptance criteria:**

1. `bash tests/validate.sh` exits 0.
2. With `SCOPE` meaning the pathspec
   `-- templates/ .claude/agents/ .claude/persona-protocol.md .claude/persona-protocol-slim.md`
   (path-scoping is **required**: this plan doc itself contains the sentinel
   sentence, so an unscoped count would read 12 once the doc is committed, and a
   future doc quoting it would drift the count again),
   `git grep -F -l 'Commit your own memory-scope writes before ending your turn.' SCOPE | wc -l`
   prints exactly `11`, and the same command with `| sort` instead of `| wc -l`
   prints exactly these 11 paths:
   `.claude/agents/agent-auditor.md`, `.claude/agents/explorer.md`,
   `.claude/agents/lead-programmer.md`, `.claude/agents/researcher.md`,
   `.claude/agents/scribe.md`, `.claude/agents/spec-master.md`,
   `.claude/agents/task-master.md`, `.claude/persona-protocol-slim.md`,
   `.claude/persona-protocol.md`, `templates/persona-protocol-slim.md`,
   `templates/persona-protocol.md`.
   (Baseline measured at 0 files under `SCOPE` — genuinely RED.)
3. `git grep -F -l "exclude,top).claude/agent-memory" -- agents/reviewer.md .claude/agents/reviewer.md | wc -l`
   prints `2`. (Baseline 0.)
4. **Branch agreement, not existence** — for each of `agents/reviewer.md` and
   `.claude/agents/reviewer.md` separately, the count reported by
   `git grep -F -c 'git diff --quiet HEAD' -- <file>` equals the count reported
   by `git grep -F -c "exclude,top).claude/agent-memory" -- <file>`, so no
   un-narrowed occurrence of the bare command survives alongside a narrowed one.
   Note `git grep -c` prints `<path>:<count>`, not a bare number, and exits 1
   printing nothing when there is no match — compare the counts, do not string-
   match a bare integer.
5. **Both directions of the phrasing flip.**
   `git grep -F -c 'no tracked file outside' -- agents/reviewer.md` reports
   count `2` (both passages updated, not just the On-PASS one; baseline 0), and
   `git grep -F -c 'no tracked file carries' -- agents/reviewer.md` exits 1 with
   no output (count 0; **baseline measured at 2**, so this half is a genuine
   2→0 flip and not a vacuous negative).
6. `git grep -F -l "the exclusion" -- agents/reviewer.md` returns that path and
   `git grep -F -l '## Affected files' -- agents/reviewer.md` returns that path,
   so the conditional memory-is-the-deliverable case is stated in the file.
   (Both baselines measured at 0 — neither is a vacuous existence grep.)
7. **Behavioural proof of the prescribed command** (this is the non-vacuous
   criterion — run it in a throwaway repo under the scratchpad, never against
   this repo): create a repo with one committed tracked file and a committed
   `.claude/agent-memory/x/MEMORY.md`; then assert all four of —
   (a) memory-only dirt, from the repo root → exit 0;
   (b) memory-only dirt, from a subdirectory → exit 0;
   (c) any other tracked file also dirty, from the root → exit 1;
   (d) same as (c) from a subdirectory → exit 1.
   Additionally assert the rejected form `git diff --quiet HEAD -- . ':(exclude).claude/agent-memory'`
   gives exit 0 in case (d) — proving the prescribed form was chosen for a real
   reason and the criterion discriminates between the two.
8. `node bin/cli.js --update --check` exits 0 and reports every mirror already
   current; `git status --porcelain -uno` is empty afterwards.
9. `bash hooks/scripts/version-stamp-check.sh` over this unit's own commit range
   exits 0 (bump + CHANGELOG in the same commit as the content, P3).
10. `node tests/adapter-protocol-parity.test.js` exits 0 and no file under
    `adapters/` appears in this unit's `git diff --name-only`.

## Step 2 — Guard both changes against silent drift

`templates/persona-protocol.md` is trimmed per-persona, so a protocol amendment
can reach nobody and still pass a source-only grep — the exact failure mode
recorded in `project_protocol_amendments_do_not_propagate`. This step makes the
merge gate witness propagation instead of presence.

**Affected files:** `tests/validate.sh` only.

**Guard 1 (propagation).** Every file containing the literal header
`## A note on \`memory\`` must also contain the sentinel sentence from Step 1,
and the two file counts must be **equal**. Report the offending path(s) on
failure. This catches a new persona row, a retrimmed matrix, or a regenerated
mirror that loses the sentence.

**Guard 2 (no un-narrowed command).** In each of `agents/reviewer.md` and
`.claude/agents/reviewer.md`, the occurrence count of `git diff --quiet HEAD`
must equal the occurrence count of `exclude,top).claude/agent-memory`. Report the
file and both counts on failure. This catches a future edit, or a mirror
regenerated from a reverted source, that restores the whole-tree form.

Follow the file's existing check idiom (an `echo "== … =="` banner, then
`OK`/`FAIL` lines feeding the suite's failure counter). Place both checks where a
failure can actually increment that counter — never appended below a
`failures > 0` gate, which would make them unable to ever fail.

**Acceptance criteria:**

1. `bash tests/validate.sh` exits 0 on the shipped tree, and its output contains
   an `OK` line for each of the two new checks.
2. **Mutation proof, Guard 1** — delete the sentinel sentence from exactly one
   mirror (`.claude/agents/scribe.md`); `bash tests/validate.sh` exits non-zero
   and its output names that path. Restore the file
   (`git checkout -- .claude/agents/scribe.md`) and re-run to confirm exit 0.
3. **Mutation proof, Guard 1, second direction** — delete the sentence from the
   slim *source* (`templates/persona-protocol-slim.md`); validate.sh exits
   non-zero naming that path; restore and re-confirm exit 0.
4. **Mutation proof, Guard 2** — in `agents/reviewer.md`, revert one occurrence
   of the narrowed command to the bare `git diff --quiet HEAD`; validate.sh exits
   non-zero naming that file; restore and re-confirm exit 0.
5. **Non-vacuity of placement** — the new checks appear at a line number *above*
   the suite's final failure-count gate in `tests/validate.sh`, verified by
   comparing `git grep -n` line numbers.
6. No version bump is present in this unit's commit, and
   `bash hooks/scripts/version-stamp-check.sh` over this unit's commit range
   exits 0 (confirming `tests/validate.sh` is not a version-stamped path, R7).
7. This unit's `git diff --name-only` names `tests/validate.sh` and nothing else.

## Step 3 — Record the decision (scribe)

**Affected files:** a new `docs/adr/<NNNN>-*.md`,
`docs/adr/0015-commit-anchored-pass-markers.md` (annotation only),
`docs/harness-glossary.md`, `CHANGELOG.md`.

**ADR number:** take the next free number — `0037` at authoring time, but
**re-derive it at execution time**; sibling specs collide, and numbers are never
backfilled into the `0007` hole.

**ADR content.** Title the decision as the narrowing of the v3 clean-tree
precondition. It must contain: ADR-0015's original whole-tree rationale quoted
verbatim (`docs/plans/2026-08-07-commit-anchored-pass-markers.md:363-367`); why
the unit-exclusivity invariant it rests on does not cover memory-scope writes;
the conditional exception when a memory path is the deliverable; and the recorded
rejection of both gitignoring `.claude/agent-memory/` (with the harness-injected
"shared … via version control" instruction as the deciding ground) and
reviewer-side auto-commit (with the ADR-0002 custody breach and the measured
shared-tree race as the grounds). Annotate ADR-0015 in place with an
`**Amended by**` pointer to the new ADR — this amends its *rationale's reach*,
not its mechanism.

This decision meets all three ADR tests: hard to reverse (it relaxes a gate
condition that a later reader would otherwise re-tighten), surprising without
context (a narrower clean-tree check looks like a weakened one), and the result
of a real trade-off (four named options, two rejected on measured grounds).

**Glossary entries (harness glossary — `docs/harness-glossary.md`).** Add
**clean-tree precondition** and **ambient dirt**; add a synonym line folding
**memory-scope write** into the existing `**agent-memory write**` entry at `:764`
rather than creating a second entry. That entry's closing parenthetical
("concurrent writes to `.claude/agent-memory/` can dirty the git tree and fail
marker preconditions") must be updated — it is now historical, and should cite
the new ADR.

**Do not touch `CONTEXT.md`.** All three terms are harness mechanics, and
`CONTEXT.md:498-510` routes them to the harness glossary. A prior unit's
marker-note (unit #231) records that CONTEXT.md scope-leak has already cost two
fix-pass commits in this repo; this criterion is that control.

**Acceptance criteria:**

1. The new ADR file exists, its number is greater than every existing
   `docs/adr/00NN-*.md` number, and it contains the headings/sections this repo's
   ADR format requires (Context or Problem, Decision, and a related-decisions or
   consequences section).
2. The original rationale is quoted, not paraphrased — proven by **two
   wrap-safe anchors**, both of which `git grep -F -l … -- docs/adr/` must
   return the new ADR for: `only one unit is ever` and `Deliberately *not*`.
   (Both baselines measured at 0 files under `docs/adr/`.) Two short anchors
   rather than one long one on purpose: the full sentence spans a line break in
   its source, so a single long fragment cannot match across any reflow — the
   line-wrap trap that has already produced vacuous criteria in this repo.
   Reflow the quote to fit the ADR's own wrapping; do not preserve the source's
   line breaks to satisfy a grep.
3. `git grep -F -l 'Amended by' -- docs/adr/0015-commit-anchored-pass-markers.md`
   returns that path, and the line names the new ADR's filename.
4. `git grep -F -c 'clean-tree precondition' -- docs/harness-glossary.md` ≥ 1 and
   `git grep -F -c 'ambient dirt' -- docs/harness-glossary.md` ≥ 1.
   (Both baselines measured at 0 repo-wide.)
5. `git grep -F -c 'memory-scope write' -- docs/harness-glossary.md` ≥ 1, and it
   appears within the existing `**agent-memory write**` entry — verified by
   `git grep -n` line numbers placing it between that entry's header and the
   following `**` term. No second standalone entry for it exists.
6. `git diff --name-only` for this unit does **not** include `CONTEXT.md`.
7. `bash tests/validate.sh` exits 0 (this is the runner for
   `tests/context-glossary-links.test.js`, so any `[[…]]` reference introduced by
   the new entries must resolve).
8. Every ADR the new file references by `[[…]]` or by path resolves to an
   existing file — checked by resolving each reference.

## Open Questions

None. Every category is resolved above, with the deciding evidence measured
rather than assumed. The one decision that might have been an operator call —
whether to also stop tracking `.claude/agent-memory/` — is resolved **against**
in "Options evaluated", on the ground that it would falsify a harness-injected
instruction the project cannot edit, discard 218 tracked files with no recovery
route, change every consumer project's `--update`, and still leave the
`docs/plans/**` / `CONTEXT.md` instance of the same class unfixed. If the
operator nonetheless wants the churn reduction, that is a separate spec, and
Option 2's discipline rule is its prerequisite either way.

## Self-check

- CHK1: Is the exact command the reviewer must run stated, unambiguously, in one
  place? — PASS (Step 1 Edit A, as a fenced literal; the measured-forms table in
  Context names the rejected variant so the choice cannot be re-litigated by
  guesswork).
- CHK2: Do Step 1 and Step 2 agree on which literal strings are load-bearing? —
  PASS (both key off the same sentinel sentence and the same
  `exclude,top).claude/agent-memory` fragment; Step 2's Guard 2 restates Step 1's
  criterion 4 as a permanent check).
- CHK3: Is the memory-file-as-deliverable case defined? — FAIL (missing on first
  draft: the narrowing had no exception clause) — revised in place (the
  conditional exception now appears in the Goal, in Step 1 Edit A, and as Step 1
  criterion 6).
- CHK4: Does every step have at least one criterion that could fail on a
  plausible wrong implementation? — PASS (Step 1 criterion 7 is a four-way
  behavioural proof that also asserts the rejected form *differs*; Step 2 has
  three mutation proofs plus a placement check; Step 3's criteria 2, 5 and 6 each
  assert content or absence, not mere existence).
- CHK5: Is the count `11` in Step 1 criterion 2 derived or assumed? — PASS
  (derived: `git grep -l` over the live tree, decomposed into the 5-full / 6-slim
  table in Context, cross-checked against `PROTOCOL_SECTIONS_BY_PERSONA` — the 3
  full-tier memory personas plus 4 slim-tier ones equals the 7 agent mirrors).
- CHK6: Does the plan say which files must NOT be hand-edited, and why? — FAIL
  (ambiguous on first draft: "regenerate the mirrors" did not name the
  constitutional ground) — revised in place (Step 1's script-generated list, R1,
  the P2 line, and each unit's `## Do NOT touch`).
- CHK7: Does the plan state the ordering constraint that makes `--update`
  actually regenerate anything? — PASS (R1 and Step 1's "Ordering" paragraph both
  state bump → CHANGELOG → `--update --force-render`, and name the
  "already current" symptom as an escalation).
- CHK8: Is the claim "narrowing weakens nothing" supported by the project's own
  record, not by my reasoning alone? — PASS (the rationale is quoted verbatim
  from the originating plan doc, and unit #257's own reviewer note independently
  reaches the same conclusion; both are quoted in Context).
- CHK9: Are the two adjacent defects on the same bullet explicitly dispositioned
  rather than silently skipped? — FAIL (missing on first draft) — revised in
  place (R4 names both the untracked-file hole and the review/reviewed
  terminology split as seen-and-declined, with their note provenance).
- CHK10: Does the plan distinguish the blocking coupling from the non-blocking
  one, so an implementer does not "fix" `stop-gate-core.sh` too? — PASS (Context
  states the `dirty` flag's only consumer is the `:642` early-allow and is
  therefore a cost, not a block; `hooks/` is on Step 1's Do-NOT-touch list).
- CHK11: Is P4 (optional personas degrade gracefully) satisfied by the new prose,
  and does the plan say how? — PASS (the rule lands inside an
  already-conditional section; stated in the Clarifications user-interaction-flow
  line and in the P4 line).
- CHK12: Does the plan avoid creating a dangling protocol cross-reference? — PASS
  (Step 1 Edit C requires the paragraph be self-contained and names
  `assertNoDanglingCrossReferences` as the reason).

The four items below were found by **running this plan's own criteria against the
live tree** before handoff, rather than by re-reading the prose. Each was a real
defect in a criterion I had written.

- CHK13: Is Step 1's sentinel-count criterion immune to this plan doc itself
  containing the sentinel sentence? — FAIL (missing) — revised in place (the
  count is now path-scoped to the 11-file universe; unscoped it would have read
  12 the moment this doc was committed, making the criterion fail for a reason
  unrelated to the implementation).
- CHK14: Do the criteria describe `git grep -c`'s actual output? — FAIL
  (ambiguous: three criteria said it "prints `2`") — revised in place (`-c`
  prints `<path>:<count>` and exits 1 silently on no match; existence checks
  switched to `-l`, and criterion 4 now says to compare counts rather than
  string-match an integer).
- CHK15: Is Step 3's rationale-quote criterion matchable at all? — FAIL
  (missing: the chosen fragment spans a line break in its source, so it matched
  **0** files repo-wide including the source it was copied from) — revised in
  place (two short wrap-safe anchors, both baselined at 0 under `docs/adr/`).
- CHK16: Does criterion 5 prove the *old* phrasing is gone, not merely that new
  phrasing exists? — FAIL (missing) — revised in place (added the 2→0 half;
  `no tracked file carries` measured at count 2 today, so the negative half is
  discriminating rather than vacuous).

## Scribe update hint

After Step 3 lands: the new ADR, the ADR-0015 annotation, and three harness-
glossary changes (two new entries, one synonym fold with a corrected
parenthetical) are the record. `CONTEXT.md` is deliberately untouched. The
CHANGELOG needs one entry per unit that changes shipped content (Steps 1 and 3;
Step 2 is test-only but a one-line entry is welcome). Worth recording in
`scribe`'s own memory: the "PASS-note warnings don't propagate" instance here is
unusually clean — unit #257's reviewer named this defect and its remedy in the
same marker that introduced the format, and it sat unactioned for ~7 weeks; a
`marker-audit --notes --surface=` sweep is what surfaced it.

---

## Dispatch contract (fast path, 3 units — no `task-master`)

Retrieval contract for all three units: **no tracker issue exists.** The
canonical artifact is this document at
`/home/sebas/AntiSlop/docs/plans/2026-09-27-agent-memory-dirt-blocks-pass.md`.
Read your unit's Step section there in full before editing. `scribe`'s
issue-closing duty does not fire (no issue number in any dispatch).

### Unit: memdirt-1

- **Objective:** Narrow the v3 clean-tree precondition to exclude
  `.claude/agent-memory/**` (conditionally), and add the memory-commit
  discipline rule to both protocol sources.
- **Retrieval:** Step 1 of this plan doc (path above). Also read the
  "Measured command choice" table in Context before writing the command.
- **Affected files:** hand-edited — `agents/reviewer.md`,
  `templates/persona-protocol.md`, `templates/persona-protocol-slim.md`,
  `.claude-plugin/plugin.json`, `package.json`, `CHANGELOG.md`.
  Script-generated — `.claude/agents/*.md`,
  `.claude/persona-protocol{,-slim}.md`, `.claude/protocol-digest.md`, and the
  harness config's `fileHashes`.
- **Ordered edits:** (1) `agents/reviewer.md:115-116` — Edit A. (2)
  `agents/reviewer.md:57-58` — Edit B. (3)
  `templates/persona-protocol.md` § `A note on \`memory\`` — Edit C, full
  wording. (4) `templates/persona-protocol-slim.md` § same — Edit C, slim
  wording, sentinel sentence byte-identical. (5) Bump
  `.claude-plugin/plugin.json` and `package.json` to the same new version. (6)
  Add the CHANGELOG entry. (7) `node bin/cli.js --update --force-render`. (8)
  Commit via the R2 route, all of it in one commit.
- **Do NOT touch:** anything under `adapters/`, `hooks/`, or `bin/`;
  `tests/validate.sh` (that is memdirt-2); `CONTEXT.md` or `docs/`;
  `.claude/agents/*.md`, `.claude/persona-protocol{,-slim}.md`,
  `.claude/protocol-digest.md` or the harness config **by hand** — they are
  `--update --force-render` output only (constitution P2); another session's
  dirty files.
- **Acceptance criteria:** Step 1's criteria 1-10, verbatim.
- **Pre-resolved context:** The precondition is prose in exactly two files, two
  passages each — no hook enforces it, so there is nothing to wire. The
  protocol memory section exists in 11 files in two wordings (5 full / 6 slim,
  table in Context); `scribe` is slim-tier, which is why both sources need the
  edit. `--update` short-circuits on an unchanged version, so the bump must
  precede it (R1). The `--force-render` rewrite of the harness config is a Set A
  literal that cannot be named in any Bash command text, including the commit
  message — use the R2 staging route. Keep the new paragraph free of protocol
  section-header references (`assertNoDanglingCrossReferences`). The four
  pathspec forms are already measured — do not re-derive; do not use the
  `-- . ':(exclude)…'` form, which reports a false clean from a subdirectory.
  Per the rule you are shipping: commit your own memory note before ending your
  turn.
- **Escalation:** If `--update` reports "already current", the bump did not
  land — escalate, do not work around it. If another session's dirt makes the R2
  staging route unusable, write the WIP sentinel
  (`.claude/wip-handoff.<agent-id>`, non-empty reason) naming exactly what is
  dirty and report; never stash or sweep it.

### Unit: memdirt-2

- **Objective:** Add two branch-agreement guards to `tests/validate.sh` so
  neither half of memdirt-1 can silently regress.
- **Retrieval:** Step 2 of this plan doc (path above).
- **Affected files:** `tests/validate.sh` only.
- **Ordered edits:** (1) Guard 1 — propagation: file count carrying the
  `## A note on \`memory\`` header equals the file count carrying the sentinel
  sentence, offending paths named on failure. (2) Guard 2 — in each of
  `agents/reviewer.md` and `.claude/agents/reviewer.md`, occurrences of
  `git diff --quiet HEAD` equal occurrences of
  `exclude,top).claude/agent-memory`, file and both counts named on failure. (3)
  Run all four mutation proofs and restore after each.
- **Do NOT touch:** `agents/`, `templates/`, `.claude/`, `adapters/`, `hooks/`,
  `bin/`, `docs/`, `CHANGELOG.md`, `.claude-plugin/plugin.json`,
  `package.json`. No version bump (R7).
- **Acceptance criteria:** Step 2's criteria 1-7, verbatim.
- **Pre-resolved context:** Depends on memdirt-1 being landed and committed.
  `tests/validate.sh` is **not** a version-stamped path
  (`hooks/scripts/version-stamp-check.sh:62` matches only `agents/*.md` and
  `templates/*`), so no bump is required — verified, do not add one. Place both
  checks above the suite's final failure-count gate; a check appended below it
  can never fail, which is a known vacuous-criterion trap in this repo.
- **Escalation:** If a mutation proof does **not** turn validate.sh red, the
  guard is vacuous — fix the guard, do not relax the proof.

### Unit: memdirt-3

- **Objective:** Record the narrowing decision as an ADR, annotate ADR-0015, and
  add the harness-glossary entries.
- **Retrieval:** Step 3 of this plan doc (path above), plus its
  `ubiquitous-language` findings in the Clarifications section.
- **Affected files:** a new `docs/adr/<next-free-number>-*.md`,
  `docs/adr/0015-commit-anchored-pass-markers.md` (annotation only),
  `docs/harness-glossary.md`, `CHANGELOG.md`.
- **Ordered edits:** (1) Re-derive the next free ADR number from
  `ls docs/adr/`. (2) Write the ADR with the required content listed in Step 3.
  (3) Add the `**Amended by**` pointer to ADR-0015. (4) Add **clean-tree
  precondition** and **ambient dirt** to `docs/harness-glossary.md`. (5) Fold
  **memory-scope write** into the existing `**agent-memory write**` entry and
  update its now-historical closing parenthetical to cite the new ADR.
- **Do NOT touch:** `CONTEXT.md` (Step 3 states why — this is criterion 6);
  `agents/`, `templates/`, `.claude/`, `adapters/`, `hooks/`, `bin/`,
  `tests/`; any existing ADR other than 0015, and 0015 only for the annotation.
- **Acceptance criteria:** Step 3's criteria 1-8, verbatim.
- **Pre-resolved context:** Depends on memdirt-1 (the ADR describes shipped
  behaviour). ADR numbering increments and is never backfilled — the `0007` hole
  is linked from `CONTEXT.md` and is not free. Highest number at authoring time
  was `0036`; re-derive rather than trusting that. `docs/harness-glossary.md`
  may be dirty from a concurrent session (R3) — if so, report and wait rather
  than sweeping it. The glossary is not alphabetical, and an `_Avoid_` line is
  entry-scoped.
- **Escalation:** If the ADR number you derive collides with one a sibling
  session just took, increment again and say so in your report — never renumber
  an existing ADR.
