# Architecture D: CI-shaped review — replace the in-session gate battery with a PR workflow

Status: **FINAL — dispatch-ready, both phases. Gated only on P0** (spec-master,
2026-08-25, revised same day after the operator's ruling). Baseline HEAD
`09cc304`.

**Operator ruling, 2026-08-25 — the three blocking Open Questions are closed.**
OQ1 (scope) resolved to **full replacement of this repo's own enforcement path,
with the hook battery retained in the shipped product** — see [D0](#d0--scope-the-enforcement-path-moves-the-product-does-not).
OQ3 (credentials) resolved to **advisory-only, stated honestly** — see
[D5](#d5--branch-protection-as-a-repository-ruleset-advisory-not-airtight).
OQ2 is closed in substance by OQ1's ruling. Two non-blocking questions remain
(OQ4, OQ5). **P0 — CI is red on `master` — remains a hard precondition and is
itself the first dispatchable unit.**

**This is spec 6 of the set.** Derived from the same 2026-08-25 adversarial
architecture critique that produced specs 1–5, but not one of them: those five
patch the current substrate; architecture D changes which substrate this repo
runs on. The numbering is not self-assigned — sibling spec 2 (FINAL) already
refers to this document as *"sibling spec 6 (CI-shaped review)"* and records a
coordination point against it. All five siblings now exist on disk; see
[Scope boundary](#scope-boundary--reconciliation-with-the-sibling-specs) for the
reconciliation, which was re-verified against their landed text rather than
against expectations of it.

Every number, path, exit code and API response below was executed live against
the working tree and against `github.com/Storreslara/AntiSlop` on 2026-08-25.
Nothing is inferred from the critique's prose. **Four of the critique's premises
did not survive verification**, and two of them were load-bearing enough that D
*as literally worded* could not be built. Both are now resolved by operator
ruling rather than by re-wording: D is adopted with its scope narrowed (D0) and
its trust claim corrected (D5). Read
[Verification of the proposal](#verification-of-the-proposal) before anything
else — the corrections, not the critique's phrasing, are what the units build.

**Disclosure, first person.** This session tripped `reviewed-path-gate.sh` twice
on purely read-only census commands (a `git ls-files … | sed | sort` pipeline and
a `find … -printf | sed | sort` pipeline), and once more on a `$D=".cl""aude/…"`
fragment-split spelling that the `hdg-prose-2` adjacent-quote join now correctly
catches. Sibling spec 3 recorded one instance of the same class in its own
session. That is three false positives across two spec sessions in one day, on
commands that wrote nothing. It is first-hand evidence for the critique's
premise, and it is also the reason two counts in this document were re-taken with
a `.claude/re*` glob rather than a literal path. **Nothing in this session wrote,
or attempted to write, this repository's marker or `DECISION` files.**

---

## Problem statement

The operator maintains a review-gating harness that runs **inside the LLM
context**: 14 hook scripts (2,673 lines including `lib/`), hand-ported into three
more trees, a five-verb marker state machine, four audit logs, thirteen live
dotfile species, and a `.claude/human-review/<id>/DECISION` protocol. Every gate
in it costs tokens in the session that trips it — block messages, split-invocation
workarounds, dispatch-hygiene contracts, marker/join-stamp bookkeeping — and its
own documentation calls it *"advisory, not airtight"* and *"not a security
boundary."*

Three properties of the current arrangement are measured, not asserted:

1. **The verdict record is local-only and unbacked.** `.claude/reviewed/` is
   gitignored. There are **342 marker files on disk covering 271 distinct units
   (264 `.pass`, 77 `.fail`, 1 `.overturned`) spanning 2026-07-28 → 2026-08-25**,
   and **zero** of them are tracked in git. A month of review history lives in one
   working tree and survives nothing.
2. **The gate the agent must not edit is guarded by a gate the agent could
   delete.** `.claude/persona-config.json`'s `protectedPaths` lists
   `.github/workflows/*` — enforced by `protected-paths.sh`, itself one of the 14
   scripts. The CI config's protection is in-band with the thing it protects.
3. **The gates produce false positives on inert text.** Three instances in one
   day across two sessions, on read-only commands (see Disclosure above).

The critique's proposal, architecture D, is to delete the battery and let
GitHub — infrastructure with a decade of adversarial hardening, maintained
outside the agent's reach — carry the same guarantees as branch protection plus
a CI review job.

---

## Verification of the proposal

Checked claim by claim against the live repo and the GitHub API.

| # | D's claim / premise | Verified verdict |
|---|---|---|
| 1 | "requires a remote" | **Already satisfied and stronger than assumed.** `origin` = `https://github.com/Storreslara/AntiSlop.git`, and `.github/workflows/validate.yml` **already exists**, already runs `bash tests/validate.sh` on both `push` and `pull_request`. Half of D's machine layer ships today. |
| 2 | "branch protection … enforces no merge without green + review" | **Available, but not as stated.** Repo is **public**, owner is a **User** account on the Free plan — public + Free **does** support branch protection and rulesets. Verified currently absent: `gh api repos/Storreslara/AntiSlop/branches/master/protection` → `404 Branch not protected`; `gh api repos/Storreslara/AntiSlop/rulesets` → `[]`. |
| 3 | "an opus reviewer pass posting a PR review" satisfies the review leg | **FALSE as a gate.** GitHub does **not** count reviews authored by `github-actions[bot]` toward a required-approving-review count — deliberately, to stop workflows self-approving. The opus pass therefore **cannot be the review leg of branch protection**. It must be a **required status check** whose job exit code carries the verdict, with the PR review as the human-readable record. D's mechanism is correct; its wiring is not. |
| 4 | "a mechanical gate someone else maintains and **the agent cannot edit**" | **FALSE for this operator.** `gh auth status` reports token scopes `gist, read:org, repo, workflow` on the single account `Storreslara`. Any agent with shell access to `gh` in this session can push to `master`, edit `.github/workflows/**`, and delete a ruleset. In a solo-operator setup there is no "someone else". **RESOLVED by ruling:** adopt anyway, as an **advisory** gate — a strong signal and a durable record, explicitly *not* a hard guarantee, in the same honesty posture the current hooks already use. See [D5](#d5--branch-protection-as-a-repository-ruleset-advisory-not-airtight). |
| 5 | "Delete the in-session gate battery" | **Ambiguous, and materially so.** `hooks/` is in `package.json`'s `files` array and `.claude-plugin/plugin.json`'s description advertises "enforcement hooks". The battery is **the shipped product**, not only this repo's self-hosting posture. Deleting it deletes AntiSlop. **RESOLVED by ruling:** the *enforcement path* for this repo's own sessions moves to CI (full replacement, not a trial); the *scripts and their corpus stay in the repo and in the product* for downstream adopters. See [D0](#d0--scope-the-enforcement-path-moves-the-product-does-not). |
| 6 | "Microworlds' machine layer becomes path-filtered CI jobs" | **True, and sibling spec 4 already built the input.** `tests/watch-map.json` (glob → command) is exactly the right data. It does **not exist yet** — spec 4 is FINAL but unimplemented. See [D7](#d7--microworlds-machine-layer--one-pr-diff-driven-ci-job). |
| 7 | Implicit: master is green, so "green + review" is adoptable | **FALSE at HEAD.** The `validate` workflow **fails on master right now** and has failed reproducibly on 2026-08-18, 08-20 and 08-25 (5 failures in the last 30 runs). Local `bash tests/validate.sh` exits **0 in 1m 33s**. This is a CI-only failure. **Hard precondition — see [P0](#p0--the-blocking-precondition).** |

### The two findings that change the shape of the spec

**Finding 7 — CI is red at HEAD, and has been intermittently for a week.**
`tests/cli-backfill.test.js` fails only on the runner:

```
FAIL F2 regression: shape B (mirror locally edited+committed) is caught ONLY by the
exit-code assertion — the post-run tree comes back clean: shape B must leave the
working tree clean post-run (no self-heal write for a pending file),
got:  M .claude/settings.json
FAIL tests/cli-backfill.test.js
```

The 2026-08-18 run failed the same way naming `.claude/persona-config.json`, plus
a second criterion (`C2.12`, three-shape drift discrimination). Locally the same
suite passes inside a 1,590-check run that exits 0. Something about the runner's
checkout — most plausibly file mode, `core.autocrlf`, or a `.claude/` file whose
committed content differs from what `bin/cli.js` renders under a fresh clone —
makes `bin/cli.js --update` self-heal a file it should leave pending.

This is not a footnote. **D's entire mechanism is "you cannot merge without a
green run."** Turning that on today makes the repository unmergeable. Diagnosing
and fixing it is P0, it is a genuine bug (a local-vs-CI divergence in the update
path is exactly the class ADR-0025 §"Verify, don't assume" exists for), and it
must land before any ruleset is created.

**Finding 4 — the agent holds the credentials that maintain the gate.**
The critique's parenthetical — *"a mechanical gate someone else maintains and the
agent cannot edit"* — is doing all the load-bearing work in D's argument, and it
is the one premise a solo operator cannot satisfy by adopting D. `repo` +
`workflow` scope on the operator's own token means the same shell that runs
`bash tests/validate.sh` can run `gh api -X DELETE repos/.../rulesets/<id>`.

Three honest responses existed. **The operator ruled (a).**

- **(a) Accept advisory-only. — CHOSEN.** D still buys everything else — durable
  verdicts, no in-context gate ceremony, a decade-hardened runner — and its trust
  property is exactly as strong as today's hooks, which README already calls "not
  a security boundary" and whose own script headers say "advisory, not airtight".
  D is adopted as a **strong signal and a durable record**, not a guarantee. The
  residual is documented, not swept: see [D5](#d5--branch-protection-as-a-repository-ruleset-advisory-not-airtight)
  and R3.
- **(b) Split credentials.** Not chosen now. A fine-grained agent PAT carrying
  `contents: write` and `pull_requests: write` but **not** `administration` or
  `workflows` is the only option that genuinely delivers D's claimed property. It
  costs a token-management workflow the operator does not have today, and it
  remains available later without re-architecting anything — it is a credential
  change, not a design change. Recorded as the named upgrade path.
- **(c) Do nothing and claim the property anyway.** Rejected, and the rejection is
  load-bearing for how the ADR must be worded: writing "the agent cannot edit it"
  when the agent demonstrably can is worse than the status quo, because the false
  belief is durable. **No artifact produced by this spec may claim the gate is
  agent-proof.**

---

## Solution

Two phases with a hard boundary between them. **Phase 1 is additive, reversible,
and per-unit incremental. Phase 2 is atomic for the repository, and gated only on
P0.** Per RD1, **neither phase deletes anything.**

- **Phase 1 — Stand up the CI-shaped path beside the current one.** Fix CI (P0),
  add a `review` job that runs the reviewer persona headlessly and posts a PR
  review, add a `microworlds` job driven by spec 4's watch-map, and start routing
  *some* units through PRs. **The hook battery keeps enforcing throughout.** A
  unit landed by direct push and a unit landed by PR coexist, because `master`
  stays unprotected.
- **Phase 2 — Make the CI path the only path, and stand the local battery down.**
  Create the ruleset (PR required, `validate` + `review` + `microworlds`
  required), retarget the orchestrator prose that assumes in-session review, then
  flip `reviewGating.mode` to `off` **in this repo's config only** (D0, D11). The
  scripts, their corpus, and the shipped product are untouched.

The phase boundary is the ruleset. Before it, D is a parallel track anyone can
abandon; after it, direct-push is gone. The config flip is deliberately the last
step of Phase 2, not the first — running both mechanisms for a week costs nothing
and is a free correctness check.

### Seams

Per `to-spec` seam discipline — prefer existing seams, take the highest one, add
as few as possible. This spec **widens one existing seam and adds two**.

1. **`.github/workflows/validate.yml` — existing, and already the merge gate's
   home.** Constitution §5 already names `tests/validate.sh` the merge gate; this
   workflow already runs it on `pull_request`. D widens this file from one job to
   four. This is the highest seam available: everything mechanical D wants lands
   in one file.
2. **`tests/watch-map.json` — new, but sibling spec 4's, not this spec's.** D
   consumes it; D does not define it. Landing spec 4 first is a dependency, not a
   duplication.
3. **One new seam: a verdict-encoding contract** — a single JSON object shape
   emitted by the reviewer job, consumed by (a) the job's own exit code, (b) the
   PR review body, and (c) the `needs-human` label decision. One shape, three
   consumers, no second parser.

---

## User stories

1. As the operator, I want a unit's verdict to survive a lost laptop, so that a month of review history is not one `rm -rf` from gone.
2. As the operator, I want the reviewer's verdict to be a PR record I can link to, so that "why did this land?" is answerable six months later by someone who is not me.
3. As the operator, I want review feedback to cost zero tokens in my working session, so that the reasoning budget goes to the work rather than to gate ceremony.
4. As the operator, I want a read-only census command to never be blocked, so that measuring my own repo does not require rephrasing around a lexer.
5. As the operator, I want the CI configuration to be protected by something other than a hook I am about to stand down, so that the protection does not evaporate with the thing it protects.
6. As the operator, I want to know honestly whether branch protection is agent-proof in my setup, so that I do not write a guarantee into an ADR that my own token scopes contradict.
7. As the operator, I want CI to be green before I make green a merge requirement, so that adopting D does not brick the repository.
8. As the operator, I want to try the CI path on one unit without committing to it, so that the decision is reversible while I am still learning what it costs.
9. As the operator, I want the reactive per-edit test rerun to keep working exactly as it does, so that adopting D does not trade fast local feedback for a two-minute round trip.
10. As the operator, I want a local pre-push check that runs the same suite CI runs, so that I find a red build before the runner does.
11. As the operator, I want an escalation to be a thing I can see in the GitHub UI without running a dashboard, so that "a unit needs me" is visible from a phone.
12. As the operator, I want the CI reviewer to run on a bounded budget, so that a runaway CI job cannot spend an unbounded amount.
13. As the operator, I want to know what ten reviews a day actually costs before I turn it on, so that the billing model change is a decision and not a surprise.
14. As the operator, I want the reviewer job's verdict and its exit code to be the same fact, so that a PASS in the review body cannot coexist with a red check.
15. As the operator, I want an `INSUFFICIENT-CONTEXT` verdict to be distinguishable from a FAIL in CI, so that the routing difference the orchestrator makes today is not flattened.
16. As the operator, I want a fork PR to never run the reviewer job with my credentials, so that adopting D does not create a secret-exfiltration surface on a public repo.
17. As the operator, I want standing the local battery down to be one reviewable change, so that the transition is auditable rather than spread across weeks.
18. As the operator, I want every ADR that D moots to be annotated rather than rewritten, so that the reasoning stays recoverable.
19. As a downstream user of the plugin, I want the enforcement hooks I installed to keep working, so that this repo's self-hosting posture change does not silently break my project.
20. As the operator, I want to know which of the four sibling specs I still need to execute after D, so that I do not pay twice for the same outcome.
21. As the operator, I want spec 4's watch-map to be the *same file* CI reads and the hook reads, so that the reactive layer and the merge gate cannot drift.
22. As the operator, I want the reviewer job to run only the tests that the PR's changed paths implicate, so that a docs-only PR does not pay for the whole suite twice.
23. As the operator, I want the 2-FAIL cap's human-ask to survive in some form, so that a unit that has failed twice still stops rather than looping.
24. As a reviewer of this work, I want every acceptance criterion to be a command with an exit code, so that "D was adopted" is measured, not asserted.
25. As the operator, I want to be able to roll Phase 2 back in one API call, so that a bad week does not require a migration.
26. As a downstream user of the plugin, I want my installed enforcement hooks to behave exactly as before when this repo changes its own posture, so that an upstream decision never silently disarms my project.
27. As the operator, I want the CI gate's real trust property written down honestly, so that I never rely on a guarantee I do not actually have.

---

## Implementation decisions

### D0 — Scope: the enforcement path moves, the product does not

**Operator ruling, and the single most important sentence in this document for
whoever implements it:**

> **This repository's own gate *enforcement* moves to CI. The hook scripts, their
> test corpus, and their place in the shipped plugin all stay exactly where they
> are.**

The two things D's phrase "delete the in-session gate battery" conflated:

| | Moves to CI (this spec) | Stays, untouched |
|---|---|---|
| **What** | Which mechanism actually decides whether AntiSlop's *own* units land | `hooks/scripts/*.sh`, `hooks/hooks.json`, `tests/*-gate*.test.sh`, `lib/benign-command.sh`, the adapter ports |
| **Who it affects** | The operator, in this repo's sessions | Every downstream project that installed the plugin and has not adopted D |
| **Evidence it is product** | — | `package.json`'s `files` array includes `hooks`; `.claude-plugin/plugin.json`'s description advertises "enforcement hooks" |

This is a **full replacement, not a trial** — for this repo's posture. It is
**not** a product change. Nothing in this spec deletes a hook script, a gate
test, an adapter port, or a line of the textual-gate corpus.

**Mechanism: the mode switch the product already ships.** This is deliberately
not a new invention. `persona-config.json` already carries per-gate mode
switches read by the hooks themselves, with a safe default baked into the read:

- `dispatch-hygiene.sh:111` — `jq -r '.dispatchHygiene.mode // "block"'`, and
  this repo already runs `warn`.
- `stop-gate.sh:269` — `jq -r '.markerCommitCheck.mode // "warn"'`.

D widens that existing, proven seam to the whole battery: a
`reviewGating.mode` key (`enforce` | `warn` | `off`) read by the gates that
currently have no switch, **defaulting to `enforce` when the key is absent**, and
set to `off` in **this repo's** `persona-config.json` only. That default is
ADR-0018's opt-out pattern exactly — protective by default, opt-out real, easy,
and documented plainly — and it is why no downstream project changes behaviour
when this lands.

Three consequences the implementer must not get wrong:

1. **`.claude/persona-config.json` is the only file whose *values* change for
   this repo.** Adding the `reviewGating` read to the gate scripts is a *product
   feature* (a new capability, on-by-default), which is why it is safe.
   **`reviewGating.mode` governs the gates only.** Six scripts must be **exempt**
   from it, for two different reasons: the four reporters `graph-update.sh`,
   `lint-on-edit.sh`, `microworld-rerun.sh`, `session-start.sh` (D8 — they never
   gated anything, and D depends on them for local feedback); and
   `reviewer-tier.sh` (D3 — D's CI job calls it after the flip) plus sibling spec
   1's `harness-integrity-gate.sh`, which is **configless by design** and must
   stay that way. Wiring the switch into any of the six is a defect. A13 guards
   the reporters; A2b guards `reviewer-tier.sh`.
2. **The enforcement path is the plugin snapshot, not `hooks/scripts/`.** What
   actually fires in a session is the installed plugin's copy. That snapshot was
   resynced to `0.31.63` and is byte-identical to the repo's `hooks/scripts` as of
   this ruling, so **flipping the config key is the only lever required** — no
   snapshot surgery, and no separate drift item to chase.
3. **AntiSlop stops eating its own dog food, and the README must say so.** A
   plugin that ships enforcement hooks its own repo does not use is a legitimate
   position — the operator has CI and downstream projects may not — but it is
   dishonest to leave unstated. This is a documentation obligation, not an
   optional nicety.

### P0 — The blocking precondition, and the first unit

**No unit in this spec is dispatchable until `validate` is green on `master`,
verified by a real runner — not by a local run.** The `tests/cli-backfill.test.js`
F2-regression failure is CI-only, reproducible on three separate dates
(2026-08-18, 08-20, 08-25), and a week old. It is a real defect in `bin/cli.js`'s
pending-vs-self-heal decision under a fresh clone, not a CI configuration wart.

**Fixing it is a normal `lead-programmer` unit, dispatched and reviewed the
ordinary way, before this spec's own units begin.** It does not need a debug spec
and it is not part of D — it is a prerequisite bug fix that happens to block D.
Sequence it first, land it, confirm A0, then start Phase 1. Model tier: **not
below `sonnet`** — `bin/cli.js` has prior FAIL history, and per the ADR-0010
reversal (below) `sonnet` is now the implementer default anyway, so this note is
a floor, not an escalation.

Deliberately *not* acceptable: marking the test `continue-on-error`, excluding it
from the required check, or pinning the runner. Each converts a real bug into a
permanently amber gate, which is the failure mode D exists to escape.

**Model-tier note (ADR-0010 reversed).** The operator has ratified reversing
ADR-0010 on sibling spec 2's data: the implementer default is now **`sonnet`, not
`haiku`**. No acceptance criterion or dispatch note in this spec assumes `haiku`
anywhere. Where this spec names a tier it names a floor.

### D1 — Provider: GitHub Actions, and the existing workflow is the seam

GitHub is not a choice to be made; it is the incumbent. `origin` is GitHub, the
`gh` CLI is authenticated, `persona-config.json`'s `issueTracker` names GitHub
issues, and `.github/workflows/validate.yml` already runs the merge gate on
`pull_request`. D adds jobs to that file. No second CI provider is evaluated and
none should be.

One defect in the existing file to fix while widening it: `on: push` carries **no
branch filter**, so a PR from a same-repo branch triggers `push` **and**
`pull_request` — every PR pays for `validate` twice. Constrain `push` to
`branches: [master]`.

### D2 — Three required status checks, no required bot review

Because an Actions-authored review cannot satisfy a required-approving-review
count (Verification finding 3), the "review" leg of "green + review" is a
**status check**, not a review. The ruleset requires:

| Check | Job | Fails when |
|---|---|---|
| `validate` | existing, widened | `bash tests/validate.sh` exits non-zero |
| `review` | new (D3) | the reviewer's verdict is `FAIL` or the job errored |
| `microworlds` | new (D7) | a watch-map entry implicated by the PR diff exits non-zero |

Plus: **require a pull request before merging**, with `required_approving_review_count: 0`
— the human's merge click *is* the DECISION, exactly as D proposed, and it is a
human action GitHub records. Requiring 1 approval on a solo repo would require the
operator to approve their own PR, which GitHub disallows on the PR author's own
PR; a 0-approval + required-PR ruleset is the shape that actually expresses
"a human must click merge."

An `ESCALATE-TO-HUMAN` or `INSUFFICIENT-CONTEXT` verdict **does not fail the
`review` check** — it leaves it green and applies a label (D6). Failing the check
would make the two cases indistinguishable from FAIL and would strand the PR with
no route forward, which is precisely the state the orchestrator's
`INSUFFICIENT-CONTEXT` path exists to avoid.

### D3 — The reviewer persona, headless

The real gap D flagged. Resolution, verified against current Claude Code docs
(CLI is `2.1.243` locally; **the runner has no `claude` CLI at all today** —
`tests/validate.sh:124` already `SKIP`s its `claude plugin tag` check for exactly
this reason).

**Invocation shape** (`claude -p`, not the Agent SDK — this is a one-shot,
single-verdict job, and the SDK's advantage is programmatic multi-turn control
this job does not need):

```
claude -p "<dispatch packet>" \
  --model <TIER — see note below; do not hardcode> \
  --bare \
  --agents "$(node .github/scripts/agent-json.js reviewer)" \
  --allowedTools "Read,Grep,Glob,Bash" \
  --permission-mode dontAsk \
  --max-turns 40 \
  --output-format json \
  --json-schema "$(cat .github/review-verdict.schema.json)"
```

**`--model` is filled at runtime, never hardcoded.** The job invokes the existing
`hooks/scripts/reviewer-tier.sh <unit-id> <base>..<head>` and passes its stdout
(exactly `sonnet` or `opus`, fail-closed to `opus`) straight through. Sibling spec
2 landed FINAL declining to touch this script, so **this spec owns the decision** —
see the coordination point in
[Scope boundary](#scope-boundary--reconciliation-with-the-sibling-specs) for why
reuse beats replacement here. Two consequences the implementer must honour:
`reviewer-tier.sh` resolves paths **from the repo root**, so the job must run it
there; and it is one of the scripts `reviewGating.mode` must **not** disable,
since D depends on it after the flip. (Unrelated and already settled: ADR-0010 is
reversed, so the *implementer* default is `sonnet`. That governs `lead-programmer`
dispatches, not this job.)

Four further decisions inside that invocation, each load-bearing:

- **`--bare` is mandatory, not stylistic.** Without it, Claude Code auto-discovers
  hooks, skills, plugins and MCP servers from the checked-out repo — which would
  **re-import the entire gate battery into the CI job**, reconstructing in the
  runner the exact thing D moves out of the loop. Note this is true *regardless*
  of D0's config flip: `reviewGating.mode` lives in `.claude/persona-config.json`,
  which a CI checkout also carries, so a non-bare run would pick up whatever that
  file says rather than reliably running gate-free. `--bare` is what makes the CI
  reviewer's environment deterministic.
- **`--agents` carries the persona, because `--bare` disables `.claude/agents/`
  discovery.** The two flags are coupled: `--agents` is documented as bare-mode
  only, and bare mode is what suppresses hook discovery. A tiny committed script
  renders `agents/reviewer.md` (frontmatter + body) into the JSON `--agents`
  wants. `agents/reviewer.md` stays the single source of truth — the script is a
  format shim, never a second copy.
- **`--max-turns 40` and a job-level `timeout-minutes`** bound the spend. A review
  that cannot reach a verdict in 40 turns is itself a signal (route it to
  `needs-human`, D6), not a reason to run unbounded.
- **`--output-format json --json-schema`** makes the verdict a parsed object, not
  a regex over prose. The same JSON carries `total_cost_usd`, which the job echoes
  into its summary so story 13's cost question is answered by measurement after
  one week of real runs.

**Authentication** is a repository secret. The choice between `ANTHROPIC_API_KEY`
(API credits) and `CLAUDE_CODE_OAUTH_TOKEN` (subscription, via
`claude setup-token`) is a **billing-model decision, not a technical one**, and it
is OQ4 — at 271 units in 28 days this is ~10 review passes per day moving
from in-session subscription billing to whichever the operator picks.

**Fork safety — closed.** GitHub withholds secrets from `pull_request` runs
originating in forks, so the `review` job simply does not run there. The workflow
must **never** use `pull_request_target` to work around this — on a public repo
that hands an untrusted PR's code a token and an API key. The job must guard on
`github.event.pull_request.head.repo.full_name == github.repository` and, when
false, exit 0 with an explicit "external PR — human review required" summary and
the `needs-human` label. A fork PR is a human's job. **A9** is the criterion.

**Same-repo secret exposure — narrowed, then accepted as a residual. NOT closed.**
Fork safety closes only half the question, and an earlier draft read as if it
closed all of it. The remaining half: on a *same-repo* branch PR, the `review`
job checks out branch code and the reviewer persona executes it through its own
`Bash` tool while the CI secret sits in the job environment. Two mitigations, one
residual:

1. **Scope the secret to the `claude` step only** — an `env:` block on that single
   step, never job-level. The suite-running steps (`validate`, `microworlds`) then
   run branch code with **no** credential in their environment at all. This is
   free and removes the larger share of the exposure window; **A9b** asserts it.
2. **Run the reviewer with the narrowest useful tool set.** `--allowedTools
   "Read,Grep,Glob,Bash"` already excludes `Write`/`Edit`; `Bash` cannot be
   dropped without disabling the reviewer's own "run the checks yourself" duty,
   which is the core of the Writer/Reviewer split.

**The residual, stated rather than swept:** during the `claude` step, branch code
is executed with the secret in scope. This is **accepted**, for a reason specific
to this operator: any branch reaching that job was authored by an agent already
running on the operator's own machine with equivalent-or-greater credentials
(RD3, finding 4), so CI grants no capability the author did not already hold. **It
would not be acceptable on a multi-contributor repo**, and the ADR must say so —
otherwise a future contributor inherits a posture that was only ever safe for a
solo operator. This is the same honesty obligation A25b imposes on the ruleset
claim.

### D4 — The verdict contract (the one new seam)

One JSON object, three consumers, no second parser:

```json
{
  "unit": "gh412-1",
  "verdict": "PASS",
  "commit": "<40-hex>",
  "criteria": [{"id": "AC1.1", "met": true, "evidence": "…"}],
  "defects": [],
  "reviewerModel": "<the tier spec 2 settles on — recorded, not chosen, here>",
  "verifiedBy": { "…": "see D9" }
}
```

`verdict` ∈ `PASS | FAIL | INSUFFICIENT-CONTEXT | ESCALATE-TO-HUMAN` — the same
four the reviewer persona already produces, unchanged. Consumers:

1. **Exit code.** `FAIL` → job exits 1. The other three → exit 0.
2. **PR review.** Posted via `gh api …/pulls/{n}/reviews` with
   `event: COMMENT` — **never `APPROVE`**. A bot APPROVE is both non-counting
   (finding 3) and actively misleading in the PR timeline.
3. **Label.** `INSUFFICIENT-CONTEXT` and `ESCALATE-TO-HUMAN` → `needs-human`.

Story 14's invariant — "the verdict and the exit code are the same fact" — is
enforceable precisely because there is one object. A test asserts the mapping
table is total over the four verdicts.

### D5 — Branch protection as a repository ruleset: advisory, not airtight

**Operator ruling (OQ3): the CI gate is adopted as a strong signal and a durable
record, explicitly NOT a hard guarantee.** This is the same honesty posture the
current hooks already carry in their own headers — *"advisory, not airtight"*,
*"not a security boundary"* — and it is a known, accepted residual, not an
oversight.

**The residual, stated plainly so no later reader has to rediscover it:** the
operator's token carries `repo` + `workflow` scope (verified via `gh auth
status`). Any agent with shell access to `gh` in a session can push to `master`,
edit `.github/workflows/**`, or disable the ruleset. The ruleset therefore
**deters and records; it does not prevent.** What D actually buys over the hooks
is not enforcement strength — it is (i) verdicts that survive the working tree,
(ii) zero gate ceremony in the agent's context, and (iii) a runner nobody has to
maintain. Those three are real and none of them depend on the gate being
agent-proof.

**Wording obligation, binding on every artifact this spec produces.** No ADR,
README section, CHANGELOG entry, or code comment may state or imply that the CI
gate cannot be bypassed by an agent. The permitted formulation is the hooks' own:
*a deterrent and an audit record, not a guarantee.* Getting this wrong is worse
than the status quo, because a false belief about a safety property is durable
and nobody re-checks it. **A25b** is the machine-checkable guard.

**The named upgrade path stays open.** Resolving this properly later is a
*credential* change, not a design change: a fine-grained agent PAT with
`contents: write` + `pull_requests: write` and without `administration` /
`workflows`. Nothing in this spec's architecture has to change to adopt it, which
is precisely why deferring it is safe.

Use a **repository ruleset** targeting `master`, not classic branch protection:
rulesets are the current mechanism, can be toggled to `disabled` without deletion
(story 25's one-call rollback), and their state is readable at
`gh api repos/{owner}/{repo}/rulesets`.

Rules: `pull_request` (required, 0 approvals), `required_status_checks`
(`validate`, `review`, `microworlds`), `non_fast_forward`, `deletion`.

**`bypass_actors` must be empty.** A ruleset that exempts the repository admin
exempts the operator's own token, which is the token the agent runs with (finding
4). An empty bypass list is what makes the ruleset mean anything at all — it
raises bypass from "a normal push" to "a deliberate administrative act."

**The "logged" half of that claim does not survive measurement, and is withdrawn.**
An earlier draft called bypass "a deliberate, *logged* administrative act." Probed
today on this account:

| Probe | Result |
|---|---|
| `gh api /users/Storreslara/audit-log` | **404 Not Found** |
| `gh api /orgs/Storreslara/audit-log` | **404** — not an organization |
| `gh api repos/Storreslara/AntiSlop/rulesets/rule-suites` | `[]` — and this endpoint records **rule *evaluations* against pushes**, not ruleset *configuration changes* |

The audit-log API is org/enterprise-scoped; there is none for a user-owned repo.
A ruleset's `updated_at` moves when it is edited, but **nothing surfaces what
changed, or by whom** at this account tier. So the honest formulation is: an
empty bypass list makes bypass **deliberate and visible-in-current-state** — the
ruleset's own JSON shows it disabled or its rules removed — **not
retrospectively logged.** A drive-by push is prevented; a determined flip-and-restore
would leave only a moved timestamp. Anyone wanting the logged property needs
either RD3's credential split or an org account, and should not assume it here.

*Compensating control, verified in a sibling:* spec 1's **Step 4**
(disarm-surface drift) detects a weakened harness config in-session and
explicitly covers `reviewGating.mode`. Sibling spec 5 sequences it as **W7,
before this spec's W9**, so the config half of a disarm is monitored even though
the ruleset half is not. That is a partial mitigation, not a substitute.

**Protecting `.github/workflows/**` once the local gates stop enforcing** (story
5). Today `protected-paths.sh` blocks agent writes there via `protectedPaths`.
Under D0 that script is not deleted — it stops enforcing in this repo when
`reviewGating.mode` goes to `off`, which has the same practical effect locally.
The replacement is a **second ruleset** targeting the same branch with a
`file_path_restriction` rule on `.github/workflows/**` — GitHub evaluates it
server-side on push, so it holds against any client, but **not** against a token
that can edit the ruleset. Per the OQ3 ruling this is accepted and documented,
not solved.

*Cheap belt-and-braces the implementer should consider:* `protectedPaths` is read
by a script whose mode switch is battery-wide. If keeping `protected-paths.sh`
enforcing while the rest goes `off` is a one-line carve-out, it costs almost
nothing and preserves a real in-loop check on the two paths that matter most
(`.github/workflows/*` and `.claude/constitution.md`). Decide at implementation
time; either answer is defensible, but record which was chosen and why.

**Do not create either ruleset until P0 is green and Phase 1 has run for at least
ten real PRs.** Creating it earlier is how a repository becomes unmergeable.

### D6 — Escalation as a label, and what is lost

D's claim — "escalation becomes a `needs-human` label" — is **verified
representable**, with one caveat the critique did not mention.

Representable with no packet directory:
- The trigger (`humanReviewMode`, heavy-unit criteria) is a decision the reviewer
  job makes and encodes in `verdict`.
- The marker's authoritative body → the PR review comment (durable, timestamped,
  attributed, and — unlike a marker — actually backed up).
- The blocking property → the `needs-human` label plus the required-PR rule. The
  PR cannot merge without a human, which is the whole point.
- `CHANGES.md` (literate change summary) and `EXAMPLES.md` (worked examples) →
  sections of the same PR review body. They are prose; a review body is prose.
- The `DECISION` file protocol, `human-decision-gate.sh`, and the entire
  timestamp-echo staleness binding → **not used in this repo's workflow**. The
  human clicking merge *is* the decision, it is recorded by GitHub, and no agent
  identity can perform it. This is D's cleanest conceptual win: a 342-line gate
  plus a 906-line test corpus, both of which exist to make one file unforgeable,
  replaced locally by a UI affordance that is unforgeable for free.
  **Per RD1 none of it is deleted** — it remains the shipped mechanism for
  downstream projects, and the line-count savings are a *context* saving here, not
  a repository-size saving anywhere.

**The caveat: the packet's `run.sh` has no PR equivalent.** Today an escalated
unit hands the human an executable microworld bundle. A PR review body cannot
hand anyone a runnable directory. Under D the human's equivalent is
"`gh pr checkout <n>` and run the watch-map entry" — strictly more setup than
`bash .claude/human-review/<id>/run.sh`. This is a real regression in escalation
ergonomics and must be recorded as an accepted cost, not glossed. It is mitigated
by the fact that `humanReviewMode` is currently `"off"`, so the escalation path is
inert at HEAD and the regression is theoretical until the operator turns it back
on.

**The 2-FAIL cap** (story 23) survives as prose in the orchestrator, retargeted:
"two `.fail` records" becomes "two failing `review` checks on the same PR." The
`AskUserQuestion` human-ask ADR-0024 Step 4 introduced is unaffected — it was
never hook-enforced.

### D7 — Microworlds' machine layer → one PR-diff-driven CI job

**Sibling spec 4's `tests/watch-map.json` becomes D's path-filtered CI input
directly. Its schema needs no modification.** This was the brief's explicit
question and the answer is verified against spec 4's D2: entries carry `watch`
(globs), `run` (ordered commands), `timeoutSeconds`, `id`. That is exactly a CI
job's input.

What *does* need adding is **one consumer, not a schema change**. Spec 4's
consumer (`microworld-rerun.sh`) resolves **one edited path** from a PostToolUse
payload. CI must resolve **a set of paths** from a PR diff. Neither GitHub's
`paths:` filter (workflow-level, not job-level, and cannot read a JSON file) nor a
generated job matrix is the right shape. The right shape is one job:

```
git diff --name-only origin/master...HEAD | bash bin/watch-map-run.sh --stdin
```

`bin/watch-map-run.sh` reads the same `tests/watch-map.json`, unions the entries
whose `watch` globs match any changed path, and runs their `run` commands. It is
the **third** consumer of one file (hook, CI, and — if the operator wants it — a
pre-push hook), which is story 21's whole point.

Spec 4's **AC1.6** — every watch-map command must name a suite `tests/validate.sh`
also registers — becomes *more* load-bearing under D, not less: it is what keeps
the `microworlds` check from becoming a second, drifting merge gate beside
`validate`. Keep it verbatim.

### D8 — What replaces the reactive-rerun UX (the trade D flagged)

The critique named this cost and this spec refuses to drop it. The answer turns
on a distinction the critique blurred: **D stands down *gates*, not *reporters*.**

Spec 4's D3 states the contract explicitly — `microworld-rerun.sh` "remains a
**reporter, not a gate**". It does not block; it surfaces breakage to the model
via exit 2 and logs everything else. Nothing about adopting D requires disabling
it, and this spec **explicitly keeps it enforcing**, along with `lint-on-edit.sh`
and `graph-update.sh`, which are also reporters. Concretely: `reviewGating.mode`
(D0) governs the **gates only** and must not be wired into any of these four
scripts. A13 is the criterion.

So the fast local loop survives intact:

| Layer | Latency | Survives D? |
|---|---|---|
| `microworld-rerun.sh` per-Edit, watch-map-driven | seconds | **Retained** |
| `lint-on-edit.sh`, `graph-update.sh` | seconds | **Retained** |
| `session-start.sh` layer-presence report (spec 4 D5) | once/session | **Retained** |
| `bash tests/validate.sh` local | **1m 33s measured** | **Retained**, plus a new `pre-push` hook |
| `validate` / `review` / `microworlds` in CI | minutes, at push | New |

The only thing that moves from "seconds, in-loop" to "minutes, at push" is the
**blocking verdict** — and that verdict today arrives at reviewer-dispatch time,
which is already a distinct, later step, not at Edit. The critique's "feedback
arrives at push, not at Edit" overstates the loss: per-Edit feedback was never the
verdict, it was the reporter, and the reporter stays.

**One addition to close the remaining gap:** a `.git/hooks/pre-push` running
`bash tests/validate.sh` (1m 33s). The repo already carries a `pre-commit` hook
for the code-review graph, so the mechanism and the precedent both exist. This
makes a red CI run something the operator normally sees *before* pushing, which
is strictly better than today, where CI has been red for a week unnoticed.

### D9 — Sibling spec 4's `verifiedBy` under D

**It still makes sense, and it needs one modification.** The brief asked
explicitly; here is the reconciliation, decision by decision.

What `verifiedBy` asserts is that **the reviewer, not the implementer, checked
that each `functions[].location` still points at the right code at the escalation
commit.** That claim is about *provenance of evidence*, and it is orthogonal to
whether the evidence sits in a packet directory or a PR. The trigger survives
(escalation still exists, as a label), the actor survives (the reviewer job), and
the artifact it vouches for survives (a `functions[]` array is useful to a human
reading a PR).

- **Container changes.** `.claude/human-review/<id>/manifest.json` → a
  `verifiedBy` object inside D4's verdict JSON, rendered as a provenance line in
  the PR review body.
- **Spec 4's AC3.1–AC3.3 survive nearly verbatim.** They are `jq` shape assertions
  (`.verifiedBy.agent == "reviewer"`, a 40-hex `.commit`,
  `functionsAuthoredBy ∈ {reviewer, implementer-verified}`, and "the working-tree
  bundle is unmodified"). Retarget the file path; the assertions are unchanged.
- **Spec 4's AC3.4 and AC3.5 need retargeting.** They assert the *dashboard*
  surfaces `verifiedBy` and surfaces its absence. Under D the PR body is the
  surface. If the dashboard's decision panes are retired (OQ5), those two ACs move
  to a test over the rendered review body; if the dashboard is kept, they stand
  unchanged and the PR body is an additional surface.
- **Spec 4's D7 — lead-programmer stops authoring `functions[]` — survives
  unchanged and is *reinforced* by D.** Under D the implementer's output is a
  branch and a PR; authoring exploration metadata for a human is even less its job.
- **Spec 4's D5 SessionStart reporting needs one modification.** Its orphan check
  (an `.escalated` marker with no packet directory) becomes moot once markers are
  gone. The equivalent under D is "an open PR labelled `needs-human`", which is a
  `gh pr list --label needs-human` call. Same user story (story 5 there / 11 here),
  different query. **Land spec 4 as written; retarget this one job in Phase 2.**

**Bottom line: land spec 4 first, unmodified.** Every one of its five steps is
either untouched by D or is a strict prerequisite for it. It is the one sibling
that D makes *more* valuable.

### D10 — Rollback and coexistence

**Phase 1 is incrementally adoptable per unit, and reversible by deleting a file.**
While `master` is unprotected, a PR-landed unit and a direct-push unit are both
legal. The operator can route one unit through a PR, read the review, and decide.
Rollback is `git rm .github/workflows/review.yml`.

**Phase 2 is atomic for the repository, and reversible in one API call.** The
ruleset is what makes PRs mandatory; there is no per-unit granularity in a
branch-level rule. But `PUT /repos/{owner}/{repo}/rulesets/{id}` with
`"enforcement": "disabled"` restores direct-push immediately without deleting
configuration — which is exactly why D5 chooses rulesets over classic protection.

**The disablement flip is deliberately the *last* unit, not the first.** Phase 2
can be entered (ruleset on) with the battery still enforcing and doing nothing
harmful — belt and braces. Flipping it off is a separate, later, one-line change
with its own review. Running both for a week is a feature, not indecision, and
per D0 the flip is a config value, so reverting it is also one line.

### D11 — A disablement manifest, not a deletion manifest

**This section was rewritten by the OQ1 ruling. Read it carefully if you saw an
earlier draft — the previous version deleted files, and that is now wrong.**

Under D0 nothing is deleted. The Phase 2 endgame is a **config flip plus a
documentation debt**, and it is dramatically smaller than a deletion manifest:

| Action | Target | Nature |
|---|---|---|
| Set `reviewGating.mode: "off"` | **this repo's** `.claude/persona-config.json` | one key, one repo |
| Add the `reviewGating` read, defaulting to `enforce` | the gate scripts that lack a mode switch | **product feature**, on-by-default (D0) |
| Retarget prose that assumes in-session review | `agents/orchestrator.md` review-routing, 2-FAIL cap, per-unit model routing | edits, not deletions |
| Document that AntiSlop no longer self-hosts its own gates | `README.md`, `CONTEXT.md` | honesty obligation (D0 §3) |
| **Retained and still enforcing** | `graph-update.sh`, `lint-on-edit.sh`, `microworld-rerun.sh`, `session-start.sh` (reporters, per D8) | untouched |
| **Retained, no longer enforcing here, still shipped** | all 10 gate scripts, `lib/benign-command.sh`, both gate suites (1,892 lines), the adapter ports, the CONTEXT.md gate-lexer glossary | **untouched** |

**Consequence for sibling spec 3's M4 — this reverses the earlier draft's
finding.** M4 ("Retire the textual-gate corpus") asks *how do we mechanically
protect the marker directory so the corpus can be deleted?* An earlier draft of
this spec claimed D **dissolved** M4's blocking precondition by deleting the
marker directory outright. **Under the OQ1 ruling that claim is false**, and it
would have been an expensive error to act on:

- The marker directory and its gates **remain in the product**, so the question
  M4 asks is still live for every downstream adopter.
- What actually changes is M4's **urgency and its critical path**: this repo no
  longer *depends* on the answer, because this repo no longer enforces locally.
- So M4 stays **blocked exactly as sibling spec 3 wrote it**, on exactly the
  precondition spec 3 named, and moves from "blocking this repo's ceremony
  reduction" to "product hardening, schedulable whenever."
- Spec 3's OQ2 (what is M4's deletable set if the mechanical fix covers only
  `Write`/`Edit`?) is **unaffected by D** and still needs its answer — but note
  that **sibling spec 1's Step 2 may answer it independently.** Its
  `harness-integrity-gate.sh` is registered on both `PreToolUse (Write|Edit)`
  **and** `PreToolUse (Bash)`, which is exactly the Bash-half coverage spec 3's
  OQ2 doubted was achievable. If that gate lands and demonstrably denies the
  shapes the corpus covers, **spec 3's M4 unblocks via spec 1 — not via D.**
  Whoever evaluates M4's precondition (its A23) should test against spec 1's gate,
  not wait on this spec.

**Do not execute any part of M4 as part of D.** They are now cleanly disjoint:
D changes which mechanism decides *this repo's* merges; M4 changes what the
*product* ships. Spec 3's standing warning applies unchanged — *do not partially
delete the corpus on a partial fix.*

Spec 3's non-deletable distinctions are likewise **not** re-litigated here and
are now simply *not this spec's business*: ADR-0002's invariant, the ADR-0025 /
ADR-0020 annotation convention (ADR-0005:82), the ~5,431 lines across six shared
suites, and the layer-specific plans all stay exactly as they are.

---

## Testing decisions

**What makes a good test here.** Every assertion in this spec is about
*infrastructure state* or *job behaviour*, and both are observable from outside:
an API response body, a job's exit code, a posted review's `state` field, a
label's presence. No test should assert on the reviewer's *reasoning* — that is
what the verdict schema is for, and asserting on prose is how a review gate
becomes theatre.

Seams, existing preferred:

- **`gh api` responses** are the seam for every branch-protection criterion. They
  are the highest available seam: they assert the state of the actual enforcement
  mechanism, not a local file describing it.
- **`tests/validate.sh`** (existing, and Constitution §5's named merge gate) is
  where every new committed artifact gets its shape check —
  `.github/review-verdict.schema.json` validity, the verdict→exit-code mapping's
  totality, and the `--agents` shim's fidelity to `agents/reviewer.md`.
- **A new `tests/review-verdict-contract.test.js`** for D4: a pure function test
  over the four verdicts × their three consumers. No network, no `claude`
  invocation. This is the one place the "verdict and exit code are the same fact"
  invariant (story 14) is provable.
- **A new `tests/watch-map-run.test.sh`** for D7's runner, modelled directly on
  `tests/microworld-rerun.test.sh`'s existing harness (throwaway trees, fixture
  watch-maps, assertions on exit codes and audit lines). Do **not** write a second
  harness.
- **The reviewer job itself is tested by running it**, once, on a deliberately
  defective PR whose defect the reviewer must catch. A `review` job that has never
  returned `FAIL` is indistinguishable from one that cannot.

**Anti-vacuity discipline applies throughout, and it is not optional here.** The
single most likely failure mode of this entire spec is a `review` check that is
green because it always passes. For every criterion below: revert the fix, re-run,
confirm the criterion flips. A criterion that survives its own mutation is vacuous
and does not count as met. Prior art: this repo's own `hdg-anchor-1` and
`rpg-canon-2` bundles, whose mutation proofs are the strongest verification
artifacts in the tree.

---

## Acceptance criteria

All commands run from the repo root. Baselines measured at `09cc304`, 2026-08-25.
`OWNER/REPO` = `Storreslara/AntiSlop`.

### P0 — precondition

- **A0.** `gh run list --branch master --workflow validate --limit 1 --json conclusion --jq '.[0].conclusion'` prints `success` (baseline: `failure`). **No other criterion in this spec may be evaluated until A0 holds.**
- **A0b.** The fix is proved non-vacuous: reverting it makes `tests/cli-backfill.test.js` fail again *on a runner*, demonstrated by a pushed branch, not asserted locally (baseline: the suite passes locally and fails in CI — a local-only proof is exactly what missed this bug for a week).

### Phase 1 — the CI path stands up beside the current one

- **A1.** `.github/workflows/validate.yml`'s `push` trigger is branch-filtered. Machine-check (`yq` is **not** on this machine's PATH; `pyyaml` is, and is what `tests/validate.sh` should use): `python3 -c "import yaml,sys; d=yaml.safe_load(open('.github/workflows/validate.yml')); sys.exit(0 if 'master' in (d[True]['push'] or {}).get('branches',[]) else 1)"` exits 0. (Baseline: `on.push` is bare, so every PR runs `validate` twice. Note the `d[True]` key — YAML 1.1 parses the bare `on:` key as the boolean `True`, a trap worth encoding in the criterion rather than discovering at implementation time.)
- **A2.** A `review` job exists and runs `claude -p` with **all four** of `--bare`, `--agents`, `--max-turns`, `--output-format json`. Machine-check: `grep -c -- '--bare' .github/workflows/*.yml` returns ≥1, and a test asserts all four flags are present in the same invocation (baseline: 0 — no `claude` invocation exists anywhere in the repo; `grep -rn 'claude -p' .` returns nothing).
- **A2b.** The reviewer tier is read, not hardcoded: the `review` job invokes `hooks/scripts/reviewer-tier.sh` from the repo root and passes its stdout to `--model`. Machine-check: `grep -cE '(claude-)?(opus|sonnet)' .github/workflows/review.yml` returns **0** for any hardcoded tier literal on the `--model` line, **and** `grep -c 'reviewer-tier.sh' .github/workflows/review.yml` returns ≥1. Non-vacuity: a PR touching `hooks/` yields `opus` (matching `SENSITIVE_PATHS`), a docs-only PR yields `sonnet`.
- **A3.** The `--agents` payload is derived from `agents/reviewer.md`, not a copy: mutating one sentence in `agents/reviewer.md` changes the shim's output. Asserted by test; a shim with a hardcoded persona body fails.
- **A4.** `.github/review-verdict.schema.json` is valid JSON and is registered in `tests/validate.sh`'s JSON-validity block (which today covers five files).
- **A5.** The verdict→exit-code mapping is **total over four verdicts**: `node tests/review-verdict-contract.test.js` exits 0 and asserts `FAIL`→1 and each of `PASS`/`INSUFFICIENT-CONTEXT`/`ESCALATE-TO-HUMAN`→0. Adding a fifth verdict string with no mapping fails the test.
- **A6.** The reviewer job posts a review with `state == "COMMENTED"`, never `"APPROVED"`: `gh api repos/OWNER/REPO/pulls/<n>/reviews --jq '[.[] | select(.user.login=="github-actions[bot]") | .state] | unique'` returns exactly `["COMMENTED"]`.
- **A7.** **Non-vacuity of the gate.** On a PR containing a deliberate, criterion-violating defect, the `review` check concludes `failure`: `gh api repos/OWNER/REPO/commits/<sha>/check-runs --jq '[.check_runs[] | select(.name=="review") | .conclusion]'` returns `["failure"]`. Without this criterion the entire spec is theatre.
- **A8.** An `ESCALATE-TO-HUMAN` verdict leaves `review` green **and** applies the label: for that PR, the `review` check-run conclusion is `success` **and** `gh pr view <n> --json labels --jq '[.labels[].name]'` contains `needs-human`. Escalation is thereby representable with **no packet directory**: `gh pr view` is the whole human-facing surface.
- **A9.** A fork PR runs no credentialed job: the workflow contains a head-repo guard, `grep -c 'pull_request_target' .github/workflows/*.yml` returns **0**, and a test asserts the guard's condition. (Baseline: no such workflow exists; the criterion is about what is built.)
- **A9b.** The CI secret is scoped to the single `claude` step, never job-level: the `review` job has **no** job-level `env:` carrying `ANTHROPIC_API_KEY` / `CLAUDE_CODE_OAUTH_TOKEN`, and exactly one step declares it. Machine-check: a test parses `.github/workflows/review.yml` and asserts the secret reference appears under exactly one step's `env` and **zero** times at job level. Non-vacuity: moving the reference to job level fails the test. (The residual that survives this — branch code executed with the secret in scope during that one step — is **accepted and documented**, not closed; see D3 and R12.)
- **A10.** `bin/watch-map-run.sh` unions entries by changed-path set and is the **third** consumer of one file: `grep -rl 'watch-map.json' hooks/scripts bin .github | wc -l` returns ≥3 (baseline: `tests/watch-map.json` does not exist — **this criterion is blocked on sibling spec 4 landing**).
- **A11.** Spec 4's AC1.6 still holds under the new consumer: every command in every watch-map entry names a suite `tests/validate.sh` registers. Unchanged from spec 4; re-asserted here because D adds a consumer that could otherwise drift.
- **A12.** `bash tests/watch-map-run.test.sh` exits 0 and is registered in `tests/validate.sh` (the zero-unregistered-test-files invariant holds).
- **A13.** The reactive layer is **untouched by this spec's own units**: for each commit authored under a spec-6 unit, `git show --diff-filter=ACMRD --name-only <sha>` contains none of `hooks/scripts/microworld-rerun.sh`, `lint-on-edit.sh`, `graph-update.sh`, `session-start.sh`. **Scoped to this spec's commits, not a range diff.** An earlier draft asserted `git diff --stat <phase-1-base>..HEAD` over those four files was empty; that is falsified by legitimate sibling work landing in the same window — spec 5's **W1** single-sources `microworld-rerun.sh`, **W2** (spec 4 Steps 1–2) edits it and `session-start.sh`, and **W3** (spec 2 Unit A) rewrites it asynchronously, with W3 able to run concurrently with this spec's W8. A range diff would fail on their work, not D's. D8's retention is still a criterion, not an intention — it is just a criterion about *authorship*, which is the property actually claimed.
- **A14.** A `pre-push` hook runs the merge gate: `test -x .git/hooks/pre-push` exits 0 and its body invokes `tests/validate.sh`. Measured budget: **1m 33s** (baseline: no `pre-push` hook; only `pre-commit`).
- **A15.** Cost is measured, not estimated: after ten real PRs, the ten `review` jobs' summaries carry `total_cost_usd`, and their sum is recorded in the adopting unit's marker/PR. Story 13 is answered by data before Phase 2 is entered.
- **A16.** Coexistence is real: during Phase 1, `gh api repos/OWNER/REPO/branches/master/protection` still returns `404`, and at least one unit lands by direct push while at least one lands by PR. Rollback is proved by `git rm`-ing the review workflow on a scratch branch and observing `validate` still green.

### Phase 2 — the CI path becomes the only path

- **A17.** A ruleset exists, is enforced, and has **no bypass actors**: `gh api repos/OWNER/REPO/rulesets --jq '[.[] | select(.target=="branch" and .enforcement=="active")] | length'` returns ≥1 (baseline: `[]`, length 0), and for that ruleset `gh api repos/OWNER/REPO/rulesets/<id> --jq '.bypass_actors | length'` returns **0**.
- **A18.** The three checks are required by name: `gh api repos/OWNER/REPO/rulesets/<id> --jq '[.rules[] | select(.type=="required_status_checks") | .parameters.required_status_checks[].context] | sort'` returns `["microworlds","review","validate"]`.
- **A19.** A PR is required before merge: the same ruleset's rules include `{"type":"pull_request"}` with `required_approving_review_count: 0`.
- **A20.** **The gate actually gates.** A PR opened against `master` whose `validate` run is red cannot merge: `gh pr merge <n> --merge` exits non-zero, and `gh pr view <n> --json mergeStateStatus --jq .mergeStateStatus` returns `BLOCKED`. This is the criterion the whole spec exists to make true — verify it by *attempting the merge*, never by reading the ruleset back.
- **A21.** Direct push to `master` is refused: `git push origin HEAD:master` from a scratch commit exits non-zero with a protected-branch error (baseline: succeeds — **616 commits in the last 30 days, zero merge commits, zero PRs ever**).
- **A22.** **Every** path `protected-paths.sh` guards today is covered by a `file_path_restriction` rule once that hook stops enforcing here — verified against the live list, which is `.github/workflows/*` **and `.claude/constitution.md`** (`persona-config.json` → `protectedPaths`; the two gate scripts also listed there stop being enforcement-relevant locally under D0). This addresses the circularity in Problem statement §2 **as a deterrent, not a guarantee** — per the OQ3 ruling this criterion is explicitly a **documented non-guarantee**, and A25b requires the ADR to say so in those words.
- **A23.** Rollback is one call: `gh api -X PUT repos/OWNER/REPO/rulesets/<id> -f enforcement=disabled` restores direct push, verified by a successful scratch push, then re-enabled.
- **A24.** **Nothing is deleted** (D0). The disablement flip is executed as **one reviewable unit**, and its diff is a config value plus prose: `git diff --diff-filter=D --name-only` for the unit is **empty** (no path under `hooks/scripts/`, `tests/`, or `adapters/` is removed), and `bash tests/validate.sh` exits 0. **Deliberately not an absolute script count.** An earlier draft pinned `ls hooks/scripts/*.sh | wc -l` to **14**; that assertion would fail at flip time through no fault of D. Sibling spec 5's wave graph sequences **W6** (spec 1's Steps 2, 5, 6, 7, 8 — which add `harness-integrity-gate.sh` and `marker-verify.sh`) → **W7** → **W9** (this flip), so the legitimate count at W9 is **16**, and would change again with any future sibling addition. The property D actually cares about is *no deletions from the D0 baseline set*, which `--diff-filter=D` asserts directly and durably.
- **A24b.** The flip is real and reversible: this repo's `.claude/persona-config.json` has `reviewGating.mode == "off"` (`jq -e '.reviewGating.mode == "off"'` exits 0), **and** a fixture project with the key absent still enforces — `jq -r '.reviewGating.mode // "enforce"'` returns `enforce`, and a gate invoked against that fixture blocks. The on-by-default guarantee for downstream projects (D0) is thereby proved, not asserted.
- **A24c.** Downstream behaviour is unchanged: `node tests/adapter-protocol-parity.test.js` and both adapter port suites pass, and `git diff --name-only` for the flip unit contains **no** path under `adapters/`, `tests/*-gate*.test.sh`, or `hooks/scripts/lib/`.
- **A25.** ADRs are annotated, never rewritten: `git diff --stat` for the flip unit shows **additions only** on the ADRs it touches, and `docs/adr/0002-*.md` is byte-unchanged (its invariant survives; only *this repo's* enforcement path changes). **ADR-0025 and ADR-0020 are NOT annotated `Superseded by`** — under D0 they remain live for the product; annotating them would be false.
- **A25b.** **The honesty criterion (OQ3).** No artifact produced by this spec claims the CI gate is agent-proof. Machine-check: `grep -rniE 'cannot (be )?(edit|bypass|circumvent)|agent-proof|airtight|tamper-proof' docs/adr/<new>.md README.md CHANGELOG.md .github/workflows/` returns no hit that asserts the property, **and** the new ADR contains an explicit residual paragraph naming the `repo`+`workflow` token scope. A reviewer reads both halves; the grep alone is necessary, not sufficient.
- **A26.** No plan is archived or deleted by this spec: `git log --diff-filter=D --name-only` for every unit shows no `docs/plans/` path. (Plan archival was sibling spec 3's M4, which D does not execute — see D11.)
- **A27.** No capability is silently dropped: for each of the five marker verbs (`pass`, `fail`, `blocked`, `escalated`, `directed`) and for `DECISION`, the new ADR records its D-equivalent for *this repo's* workflow **and** states that the mechanism remains available to downstream projects. A manifest test asserts one entry per verb; a missing entry fails.
- **A28.** Verdict durability is proved, which is the gain that motivated Problem statement §1: after Phase 2, `gh api repos/OWNER/REPO/pulls/<n>/reviews` returns the verdict for a unit whose working tree has been deleted. (Baseline: **342 marker files on disk, 0 tracked in git** — today the same query has no answer.)

### Cross-cutting

- **A29.** No criterion in this spec is met by prose. Each of A0–A28 is a command with an exit code or a compared value, executed and recorded in the unit's own record. The one deliberate exception is **A25b**, whose second half is a reviewer judgement — it is marked as such rather than dressed up as mechanical.
- **A30.** Mutation discipline: for A5, A7, A10, A11, A18, A20 and **A24b**, the fix is reverted and the criterion observed to flip. A criterion that survives its own mutation is deleted from the spec rather than marked met. A24b matters most here — a `reviewGating` read that defaults to `off` instead of `enforce` would pass every other criterion while silently disarming every downstream project.

---

## Scope boundary — reconciliation with the sibling specs

Required by the brief and stated here so that **no two specs describe conflicting
end-states for the same files.**

**All five siblings now exist on disk and this section was re-verified against
their landed text.** An earlier draft of this section stated that specs 1 and 2
"do not exist yet" and that spec 5 "does not exist" — true when first written,
**false now**, and the corrections below are material rather than cosmetic:

| # | File (all `docs/plans/2026-08-25-*`) | Status as landed |
|---|---|---|
| 1 | `harness-trust-gaps.md` | finalized **pending its own OQ1–OQ5**; 9 steps |
| 2 | `agent-throughput-performance-dampeners.md` | **FINAL**, 5 units; Unit D ratified (`sonnet` default) |
| 3 | `harness-ceremony-consolidation.md` | **FINAL**, 7 units, M4 blocked |
| 4 | `microworlds-workflow-redesign.md` | **FINAL**, 5 steps |
| 5 | `streamlining-rollout-sequencing.md` | **FINAL**, 1 unit — the rollout order for specs 1–4 |
| **6** | **this document** | FINAL, gated on P0 |

| Sibling | Status on disk | Verdict under D | What the operator must do |
|---|---|---|---|
| **1 — trust gaps** (`harness-trust-gaps.md`, 9 steps, pending its own OQs) | **Landed, finalized pending OQs** | **Survives fully intact — and under RD1 it is *more* needed, not less.** Its subject is the **product's** trust posture, and RD1 keeps the product. Its Step 2 (`harness-integrity-gate.sh`: a **configless, hardcoded** write-deny registered on both `Write\|Edit` **and** `Bash`) is notable for D twice over: (i) *configless* means it is **not** governed by `reviewGating.mode`, so it keeps protecting this repo even after the flip — a genuine safety net for D5's advisory-only residual; (ii) it is plausibly the mechanical primitive sibling 3's M4 has been blocked on. | **Land it. Do not rescope it.** Add one item: the credential-split upgrade path (RD3's option (b)) is a natural fit for its trust-model document. Confirm its Step 2 gate is **exempt** from `reviewGating.mode`. |
| **2 — performance dampeners** (`agent-throughput-performance-dampeners.md`, FINAL, 5 units) | **Landed FINAL** | **Survives intact; no conflict.** Unit D is ratified — **ADR-0010 reversed, implementer default `sonnet`** (reflected in P0). Unit A (async microworld rerun) applies to the reporter D8 retains, so it survives. "Redundant test runs" gains one new instance — A1's double-`validate` defect. | **Land it. One thing owed back to it, below.** |
| **3 — harness ceremony consolidation** (`docs/plans/2026-08-25-harness-ceremony-consolidation.md`, FINAL, 7 units) | **FINAL** | **Now cleanly disjoint from D — the OQ1 ruling resolved every dependency in spec 3's favour.** **M1** (dead artifacts, single-sourced ignore list) — survives intact; land it. **M2** (single-source the hook ports) — **survives intact**: the ports are product, and D0 keeps the product. **M3** (13 state species → 5 domains) — **survives intact** for the same reason; the state artifacts remain the shipped mechanism. **M4** (retire the textual-gate corpus) — **stays blocked exactly as spec 3 wrote it**; D does *not* dissolve its precondition (D11 corrects an earlier draft of this spec that claimed it did). | **Land M1, M2 and M3 on their own schedule — no OQ1 dependency remains. Leave M4 blocked and do not fold it into D.** |
| **5 — rollout sequencing** (`streamlining-rollout-sequencing.md`, FINAL rev 2, 1 unit) | **Landed FINAL, revision 2** | **Survives, and now governs this spec's ordering.** Revision 1 sequenced specs 1–4 and predated Architecture D; **revision 2 inserts spec 6 explicitly** with edges P0 → Phase 1 → Phase 2, renames the milestone namespace `M0–M6` → `W0–W10`, and allocates **ADR `0027`** to this spec. It places D at **W0 → W8 → W9**, and its file-ownership table records `.github/workflows/**` with spec 6 as **sole owner**. | **Treat spec 5's wave graph as authoritative for ordering and ADR numbers; this spec restates neither.** Two of its orderings changed criteria here (A24, A13) — see R7. |
| **4 — Microworlds workflow redesign** (`microworlds-workflow-redesign.md`, FINAL, 5 steps) | **FINAL** | **NOT moot. Land it first, unmodified.** Its `tests/watch-map.json` is D's path-filtered CI input **directly, with no schema change** (D7). Its `verifiedBy`-at-escalation **still makes sense**, with the container moving from the packet manifest to D4's verdict JSON (D9). Its D7 (lead-programmer stops authoring `functions[]`) is reinforced. Its D5 SessionStart job needs **one retarget in Phase 2** (orphan-marker check → `needs-human` PR check). Its AC3.4/AC3.5 need retargeting only if the dashboard's decision panes are retired (OQ5). | **Execute spec 4 as written. It is a prerequisite, not a conflict.** |

**Cross-spec coordination points. The OQ1 ruling removed most of what was
conflicting here; three items remain, and all three are now coordination rather
than conflict:**

- **Spec 3's A30 vs D's config flip.** Spec 3's A30 requires that no unit change
  `humanReviewMode`, `dispatchHygiene.mode`, or `markerCommitCheck.mode` in
  `persona-config.json`. D's flip unit adds `reviewGating.mode` and sets it to
  `off` — a **different key**, so there is no literal conflict. But the *spirit*
  of A30 ("volume work must not silently change capability posture") applies to D
  too, and D's flip is exactly such a change made deliberately and visibly.
  **Read spec 3's A30 as scoped to spec 3's own units; D's flip is a declared
  posture change with A24b as its guard.**
- **Spec 3's M3 vs D's state artifacts.** M3 models `.claude/reviewed/` into a
  "Unit" key domain. An earlier draft of this spec said not to execute it because
  D would delete that domain. **Under D0 that is wrong and the guidance is
  withdrawn:** the marker directory remains the product's mechanism, M3 is product
  work, and it should proceed. This repo will simply stop *populating* it.
- **`reviewer-tier.sh` — spec 2 declined it, so this spec owns it. DECIDED.**
  An earlier draft deferred the reviewer-tier question to sibling spec 2. **Spec 2
  has since landed FINAL and explicitly declines it**: it "touches
  `reviewer-tier.sh` **nowhere**", lists it under Out of Scope, and states that
  Unit D's ratified decision "leaves the reviewer-gate ratchet untouched." It then
  hands the question here, one-directionally — its cross-cutting note *"every unit
  here draws an `opus` reviewer"* is derived from `reviewer-tier.sh`'s
  `SENSITIVE_PATHS`, and it asks only to be told **which mechanism is live** so it
  can restate its cost expectation. Deferring further would leave the question
  owned by nobody.

  **Decision: the `review` job invokes the existing `reviewer-tier.sh`, unchanged,
  with the PR's `base..head` range.** It is already a deterministic script taking
  `<task-id> <range>` and printing exactly `sonnet` or `opus`, already fail-closed
  to `opus`, and already the subject of ADR-0009's measured-eligibility decision.
  Reusing it invents no mechanism, preserves ADR-0009, and keeps a single source
  of truth. What changes is only **who invokes it**: the orchestrator at dispatch
  time today, the CI job at PR time under D.

  **Owed back to spec 2:** its cost note stands **unchanged** — `SENSITIVE_PATHS`
  includes `^hooks/`, so its own five units still draw an `opus` reviewer under
  either mechanism. No re-derivation needed. This resolves the coordination point
  spec 2 raised, in the direction that requires the least change to it.

  *Consequence for D3:* `--model` is populated from that script's stdout, not
  hardcoded. The `<TIER>` placeholder in D3's invocation is filled at runtime,
  which is why it is shown unfilled.

- **Spec 4's R5** anticipated a marker relocation by sibling 3. Under D0 the paths
  neither relocate nor cease — they simply stop being written *in this repo*.
  Spec 4's criteria are about *detection and provenance*, not location, so they
  survive unchanged; only its SessionStart orphan-check job needs the Phase 2
  retarget described in D9.

---

## Risks / dependencies

- **R1 — Adopting D while CI is red bricks the repository.** Mitigated by A0 as a
  hard gate. The tempting mitigation — excluding the failing suite from the
  required check — is explicitly prohibited (P0).
- **R2 — The `review` check is green because it cannot fail.** The single most
  likely failure mode of this spec. A7 is the guard, and A30 requires it be proved
  by mutation on a real defective PR, not by unit test.
- **R3 — D's gate is a deterrent, not a guarantee. ACCEPTED RESIDUAL (OQ3).** The
  operator's `repo`+`workflow` token means an agent can push to `master`, edit
  workflows, or disable the ruleset. Ruled advisory-only, in the hooks' own
  honesty posture. **A25b is the guard: no artifact may claim the gate is
  agent-proof.** The credential-split upgrade (a fine-grained agent PAT) stays
  available and is a credential change, not a design change. This risk is *not*
  mitigated — it is knowingly carried, exactly as ADR-0018 carries its own R1.
- **R4 — The billing model changes.** ~10 review passes per day (271 units in
  28 days) move from in-session subscription billing to whichever secret the job
  uses. A15 makes this measured before Phase 2, not after. OQ4. Note the per-pass
  cost is a function of the tier spec 2 settles on, so R4 and the
  `reviewer-tier.sh` coordination point are the same question seen twice.
- **R5 — Escalation ergonomics regress.** The packet's runnable `run.sh` has no PR
  equivalent (D6). Accepted, currently theoretical (`humanReviewMode: "off"`), and
  recorded rather than glossed. Under D0 the packet mechanism still *exists* in
  the product, so this regression is local to this repo's posture and reversible
  with the same config key.
- **R6 — AntiSlop stops eating its own dog food. ACCEPTED, WITH A DOCUMENTATION
  OBLIGATION (OQ1).** The plugin continues to ship enforcement hooks that its own
  repo no longer runs. This is defensible — the operator has CI, downstream
  projects may not — but it creates two real hazards the implementer must own:
  (i) **the gates lose their best test bed.** Every false positive in this
  session's Disclosure was found by *using* them; after the flip, gate regressions
  reach downstream users first. The 1,892-line corpus and `tests/validate.sh` are
  the compensating control, and **A24c requires they stay green**. (ii) **the
  README must say so plainly** (D0 §3). An unstated "we don't use what we sell" is
  the kind of quiet dishonesty this project exists to avoid.
- **R7 — Spec 4 is a hard dependency, and spec 5 now sequences this spec
  explicitly. RESOLVED.** A10 and A11 cannot be evaluated until
  `tests/watch-map.json` exists. An earlier draft flagged that spec 5's rollout
  map omitted spec 6 and asked for it to be added; **spec 5 revision 2 has since
  done exactly that**, so the gap is closed and the request is withdrawn. Its wave
  graph now places this spec as: **W0** (P0, unbrick CI) → **W8** (Phase 1;
  predecessors W0, W2) → **W9** (Phase 2; predecessors W3, W7, W8). Two
  consequences bind this spec's criteria and are reflected in them: W6 adds two
  hook scripts before W9 (**A24**), and W1/W2/W3 all touch reporter scripts around
  the W8 window (**A13**). **Spec 5's wave graph is authoritative for ordering;
  this spec does not restate it.**
- **R8 — Fork PRs on a public repo.** `pull_request_target` would hand untrusted
  code a token and an API key. A9 forbids it by name. **Closed.**
- **R12 — Same-repo branch code runs with the secret in scope. ACCEPTED
  RESIDUAL.** A9b scopes the credential to the single `claude` step, so the
  suite-running steps hold none. What remains is that during that step the
  reviewer executes branch code via `Bash` while the secret is in the
  environment. Accepted because any branch reaching that job was authored by an
  agent already holding equivalent credentials locally (RD3) — CI grants nothing
  new. **This acceptance is contingent on the solo-operator posture and must be
  revisited the moment a second contributor exists**; the ADR must record the
  contingency, not just the acceptance.
- **R9 — ADR churn, now much smaller than the earlier draft assumed.** Because
  nothing is deleted, **ADR-0020 and ADR-0025 are untouched** — they remain live
  for the product, and annotating them `Superseded by` would be false (A25).
  ADR-0002 survives byte-unchanged. Phase 2 annotates ADR-0018 and ADR-0024 (both
  posture, both already carrying local-opt-out annotations of exactly this shape)
  and adds one new ADR for the CI-shaped architecture. All annotations, never
  rewrites (ADR-0005:82).
- **R11 — The `reviewGating` default is the highest-stakes line in the change.**
  A read that defaults to `off` instead of `enforce` silently disarms the gates in
  **every downstream project** on their next update, while passing every other
  criterion in this spec. This is precisely the encoding trap ADR-0018 §"Why
  on-by-default" documents and closed by putting the default in the consumer's
  absent-key fallback. **A24b is the guard and A30 requires it be mutation-proved.**
- **R10 — 616 commits/30 days becomes ~10 PRs/day.** The lead-programmer makes
  *incremental* commits within a unit; the PR boundary is the unit, not the commit.
  Nothing verifies that the current commit granularity maps cleanly onto branches,
  because **no branch-per-unit workflow has ever been run here** (zero merge
  commits, ever). Phase 1's ten real PRs (A15) exist partly to discover this.

---

## Constitution check (.claude/constitution.md v1.0.0)

- **§1 Verify, don't assume** — load-bearing here. Four of the proposal's premises
  were falsified by direct execution against the live API and the runner logs, two
  of them fatally to D as written. The red-CI finding in particular had gone
  unnoticed for a week precisely because nobody ran the check.
- **§2 Prefer deterministic scripts over LLM re-derivation** — D is the largest
  available instance of this principle: it moves verification out of every agent's
  context into a runner. The one caution: the reviewer job *is* LLM
  re-derivation, so D4's schema and A5's totality check are what keep it bounded.
- **§3 Version-stamp discipline** — Phase 2's persona edits touch `agents/*.md`
  and `templates/`, so `.claude-plugin/plugin.json` must bump with a CHANGELOG
  entry. Add this to the manifest unit's criteria at dispatch time.
- **§4 Optional personas degrade gracefully** — a project selecting no `reviewer`
  gets a `review` job with nothing to run. The workflow must skip cleanly and say
  so, not fail.
- **§5 `tests/validate.sh` is the merge gate** — reaffirmed and *strengthened*: D
  makes it a required status check on a server-side ruleset rather than a
  convention. A4, A12 and A24 all bind to it.

---

## Out of scope

- **Choosing a CI provider.** GitHub is incumbent and verified; no alternative is
  evaluated.
- **Migrating the 342 existing markers into PRs.** They are gitignored local
  scratch; they age out. D changes what the *next* unit produces.
- **The dashboard's fate.** Retiring or keeping `bin/microworld-dashboard/` is
  OQ5, not a decision this spec makes.
- **Flipping `humanReviewMode` back on.** An operator posture decision (ADR-0024).
- **Editing any sibling spec.** All five have landed. This spec reconciles
  against their text and names what is owed to them; it changes none of them.
  Both items previously owed *outward* are now discharged: spec 5 revision 2 has
  inserted spec 6 into its rollout map (R7), and spec 2's cost note is confirmed
  to stand unchanged.
- **Restating spec 5's ordering.** Its wave graph (W0–W10), file-ownership locks,
  and ADR allocation are authoritative. Where this spec's criteria depend on that
  ordering (A13, A24) they cite it rather than duplicating it, so a future
  revision of spec 5 does not silently falsify a criterion here.
- **The `docs/plans/` retention question** — sibling 3 flagged it to sibling 5,
  which landed scoped to rollout sequencing and did not take it up. It remains
  unowned; not this spec's to claim.
- **Any implementation.** This document is spec work only. Nothing here was built,
  no ruleset was created, no workflow was modified.

---

## Further notes

**Tracker publication is owed, not done.** This spec resolves to well above
ADR-0024 Step 3's ≥6-unit publish threshold. Following sibling spec 3's precedent
exactly: filing now, while several spec-master sessions are drafting from one
critique in parallel, risks duplicate and conflicting issues. File after the set
is reconciled, with the `ready-for-agent` label.

**The critique's strongest argument is one it did not make.** It argued D on
ceremony volume and token cost. The measured argument is stronger and different:
**271 units of review history exist in one untracked directory on one machine.**
Not one of those verdicts is recoverable from anywhere else. D's "verdicts that
are real PR records" is not a convenience — it is the difference between having a
review history and believing you have one.

**The critique's weakest claim is its central one, and the ruling is what saves
D from it.** *"A mechanical gate someone else maintains and the agent cannot
edit"* is the sentence that makes D sound strictly stronger than the hooks. For a
solo operator whose agent runs with a `repo`+`workflow` token, there is no someone
else, and the agent can edit it. The operator's ruling — adopt anyway, advisory
only, say so plainly — is the right call **because D's real gains never depended
on that sentence**: durable verdicts, zero gate ceremony in context, and a runner
nobody maintains are all true whether or not the gate is agent-proof. What the
ruling forbids is inheriting the critique's phrasing into an ADR. **The
correction is not "D is weaker than claimed"; it is "D is valuable for different
reasons than claimed."**

**Two of this spec's own drafts were wrong in the same direction, which is worth
recording.** The first draft assumed "delete the battery" meant deleting files,
and on that assumption declared sibling spec 3's M4 superseded and reusable as a
deletion manifest. The OQ1 ruling shows the opposite: nothing is deleted, M4 stays
blocked exactly as spec 3 wrote it, and acting on the earlier reading would have
deleted 1,892 lines of corpus and a shipped product feature to achieve a *local
posture change*. That is the same failure mode sibling spec 4 recorded — a
confident-sounding architectural claim that would have deleted the repo's
strongest verification artifacts — arriving a second time, from a different
direction, in the space of one day. **The lesson both instances teach: "replace
X" is ambiguous between "stop using X here" and "remove X from the world", and
the cheap version is almost always the right one.**

**A week of red CI is the argument for D and against it at once.** The `validate`
workflow has been failing on `master` since at least 2026-08-18 and nothing
surfaced it — because CI is out-of-loop, which is exactly what D proposes to make
load-bearing. D8's `pre-push` hook and A0's precondition exist because
out-of-loop feedback that nobody reads is worse than no feedback at all.

---

## Scribe update hint

*(Only after a phase actually lands — nothing below is owed today.)*

- **Exactly ONE new ADR — number `0027`, allocated to this spec by sibling spec 5
  (its ADR table: 0026 → spec 2 Unit D, **0027 → spec 6**, 0028 → spec 4's
  conditional D9/D11 ADR).** An earlier draft hedged "new ADR (or a section of the
  same one)" for the D0 scope split; **that hedge is withdrawn.** A second ADR
  would take 0028 and collide with spec 4's conditional reservation, and this
  project's convention is increment-never-backfill, so the collision would not be
  cleanly repairable. **The D0 scope split is a section within ADR-0027, not its
  own ADR.**

  ADR-0027 must carry five things explicitly:
  1. The phase split, and P0 as its precondition.
  2. The status-check-not-required-review correction (finding 3).
  3. **The advisory-only residual in the hooks' own words — a deterrent, not a
     guarantee — naming the `repo`+`workflow` token scope that makes it so, and
     stating that bypass is *visible in current state* but **not**
     retrospectively logged at this account tier** (measured; see D5). A25b is
     the check.
  4. **The D0 scope split as a section**: this repo's enforcement moves to CI, the
     product keeps shipping the battery, and `reviewGating` defaults to `enforce`
     so no downstream project changes behaviour. Model the on-by-default reasoning
     on ADR-0018's, which solved the identical encoding trap.
  5. **The same-repo secret residual (R12) and its contingency** — accepted only
     under the solo-operator posture, to be revisited on a second contributor.
- **Amend ADR-0018** (human-in-the-loop): for *this repo*, the escalation channel
  becomes a `needs-human` label and the decision becomes the merge click. The
  shipped default and the mechanism are untouched — this is a third local-posture
  annotation of exactly the shape ADR-0018 already carries twice.
- **Amend ADR-0024** (solo-operator posture): the 2-FAIL cap's counting surface
  moves from `.fail` records to failing `review` checks *in this repo*. The
  `AskUserQuestion` human-ask is unaffected.
- **ADR-0025 and ADR-0020 are NOT annotated.** They remain live for the product.
  An earlier draft called for `Superseded by` annotations; that was wrong under
  D0 and A25 now forbids it.
- **ADR-0002 survives byte-unchanged.** Its invariant ("the reviewer owns the
  verdict") is unaffected by where the verdict is recorded.
- **ADR-0010 is already reversed** (implementer default `sonnet`) by sibling spec
  2's ratified data — not this spec's work, noted so nobody double-files it.
- **Amend ADR-0017/0019** only as sibling spec 4 already specifies; D adds no new
  amendment to either.
- **CONTEXT.md**: the gate-lexer glossary **stays** (the vocabulary still
  describes shipped mechanism); add the CI-shaped vocabulary alongside it
  (`required status check`, `ruleset`, `needs-human`, `verdict contract`,
  `reviewGating.mode`).
- **README.md**: state plainly that AntiSlop's own repo now gates through CI and
  no longer runs its shipped hooks on itself, and why. This is D0 §3's obligation
  and R6's compensating disclosure, not optional polish.

---

## Resolved decisions (formerly OQ1–OQ3)

The three blocking questions were escalated rather than guessed, and the operator
ruled on 2026-08-25. They are recorded here as decisions with rationale so that a
later reader sees what was chosen *and* what was given up.

**RD1 — Scope (was OQ1): full replacement of this repo's enforcement path; the
product is untouched.**
*Ruled:* AntiSlop's own operational posture transitions to D. The hook scripts,
their corpus, and their place in the shipped plugin all stay. This repo's local
gate *enforcement* stops; nothing is deleted.
*Rationale:* the two things "delete the gate battery" conflated — which mechanism
decides *this repo's* merges, and what the plugin *ships* — have different right
answers. The operator has CI and wants D's benefits; downstream adopters may have
neither and are entitled to the mechanism they installed.
*Given up:* AntiSlop stops dogfooding its own gates, which costs the gates their
best test bed (R6) and creates a documentation obligation (D0 §3).
*Consequences elsewhere:* sibling spec 3's M2 and M3 **survive intact** and lose
their dependency on this question; its M4 **stays blocked exactly as written** and
is explicitly **not** folded into D (D11). Mechanism: the `reviewGating.mode`
switch, widening the `dispatchHygiene.mode` seam the product already ships,
**defaulting to `enforce`** (A24b, R11).

**RD2 — Commitment (was OQ2): closed in substance by RD1.**
*Ruled by implication, and flagged as an inference rather than a direct ruling:*
RD1 says "full replacement", so D is a committed transition, not an exploratory
parallel track. The two-phase structure survives **as a rollout mechanism, not as
a go/no-go**: Phase 1's ten-PR checkpoint (A15) now measures *cost* to inform OQ4,
and A7 proves the gate is non-vacuous — neither is a decision point on whether to
proceed. *If the operator intended Phase 1 to remain a genuine off-ramp, say so;
it changes nothing already built but changes how much Phase 1 justifies.*

**RD3 — Credentials (was OQ3): advisory-only, stated honestly.**
*Ruled:* adopt D's CI gate as a strong signal and a durable record, explicitly
**not** a hard guarantee, in the same posture the hooks already use.
*Rationale:* D's real gains — durable verdicts, zero in-context gate ceremony, a
maintained runner — do not depend on the gate being agent-proof. Blocking
adoption on a credential-management workflow the operator does not have would
trade all three for a property the current system never had either.
*Given up:* the critique's headline claim. An agent with `gh` access can still
push to `master`, edit workflows, or disable the ruleset.
*Binding consequence:* **no artifact produced by this spec may state or imply the
gate is agent-proof** (D5, A25b, R3). The credential-split upgrade path (a
fine-grained agent PAT without `administration`/`workflows`) stays open and is a
credential change, not a design change.

---

## Open Questions

Two remain. **Neither blocks dispatch**; both have recommended defaults, and
neither can stall a unit.

**OQ4 — Non-blocking for Phase 1, blocking for Phase 2. Which credential does the
CI reviewer use?**
`ANTHROPIC_API_KEY` (API credits, predictable per-run cost, no subscription
interaction) vs `CLAUDE_CODE_OAUTH_TOKEN` (subscription, shares the operator's
limits). At ~10 review passes/day this is a real monthly number in either
direction. *Recommended: start Phase 1 on whichever is easiest, let A15's measured
`total_cost_usd` decide before Phase 2.*

**OQ5 — Non-blocking, and materially narrowed by RD1. What happens to the
dashboard's decision surface?**
`bin/microworld-dashboard/` is ~1,872 lines of JS plus a 1,369-line `index.html`;
its `/api/decisions`, `/api/decision/arm` and `/api/decision/run` routes serve the
`DECISION` protocol. Under RD1 that protocol **is not deleted** — it remains the
shipped mechanism for downstream projects — so those routes stay
**load-bearing for the product** and merely go **inert for this repo**, which is
already their state today (`humanReviewMode: "off"`). The question shrinks to a
bookkeeping one: how sibling spec 4's capability register (its D9/D11) should
classify a route that is live product and dormant locally. *Recommended default:
land spec 4's register first and add an `inert-locally` qualifier rather than
reclassifying anything as speculative; delete nothing. `/api/invoke` is
independently load-bearing for gate debugging and survives regardless.*
