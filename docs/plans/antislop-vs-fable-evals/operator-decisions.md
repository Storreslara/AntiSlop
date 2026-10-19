# Operator decisions for the E1-E5 build-out and run (2026-10-16)

Applies to `docs/plans/antislop-vs-fable-evals.md` (the design, "the doc"). Where this
file conflicts with the doc, this file wins for the E1-E5 slice. Recorded by task-master
from the operator's dispatch message; the doc's substance is not edited.

- OD-1 Scope: E1-E5 only (`e01-ambiguous-tax`, `e02-preview-mutation`, `e03-rename-query`,
  `e04-search-injection`, `e05-tags-feature`). E6-E10 are not sliced. Counts in the doc's
  C2.3 and C4.1 become 5 fixtures/prompts/check dirs/references and 50 uniform-policy rows
  (5 evals x 2 arms x 5 reps).
- OD-2 Billing: Claude Max subscription, not API billing. The doc's USD caps (30 USD per
  run, 600 USD suite), `--max-budget-usd`, `SUITE_BUDGET_USD` and the `budget`
  completion_status do not apply and must not appear in new harness code. In their place:
  a per-run main-session turn cap `MAX_TURNS` (default 100, passed as `--max-turns`) and a
  per-run wall-clock cap `TIMEOUT_MIN` (default 45), equal for both arms.
- OD-3 Execution: runs are sequential (one `claude` at a time, never parallel). A pilot
  with N=1 per arm per eval (10 runs, uniform policy) runs first as a smoke gate: it
  proves the isolation probe, the model-alias probe, check non-vacuity, and that Arm B
  does not stall headlessly. Only then the full N=5. The runner is resumable.
- OD-4 Usage-limit handling: `completion_status` is one of `complete`, `stalled-human`,
  `turn-cap`, `timeout`, `usage-limit`, `error`. A subscription usage-limit or rate-limit
  hit is `usage-limit`, never a failure and never an outcome: the row is kept, it is
  excluded from every verdict count, the runner stops with exit 75, and the run is repeated
  on resume. A run_id is done iff a row exists for it whose completion_status is not
  `usage-limit`.
- OD-5 Cost columns: dollar cost is dropped from the verdict. Per-run columns are
  `tokens_in`, `tokens_out`, `tokens_cache_write`, `tokens_cache_read`, `tokens_total`
  (= input + output + cache_write; cache_read excluded), `num_turns`, `wall_clock_ms`.
  `total_cost_usd` is stored if the CLI reports it, for information only, never read by the
  scorer. The doc's `R_cost` becomes `R_tokens = median(tokens_total_B) / median(tokens_total_A)`
  over complete runs, with the doc's thresholds (<= 2, > 3) unchanged; `R_wall` unchanged;
  `R_turns` is reported alongside. Per-persona token attribution uses
  `scripts/token-usage/agg.py` as the doc says.
- OD-6 Kept from the doc: uniform model policy (all personas on Fable, `--model <fable>` and
  `CLAUDE_CODE_SUBAGENT_MODEL=<fable>` for Arm B) is the headline; headless stalls count as
  `run_pass=false` with a separate `stalled-human` tally; the operator grades the blinded
  judgment items (E1's `ASSUMPTIONS.md` item only; E7's is deferred with E7).
- OD-7 Deferred (the doc does not need them for E1-E5 verdicts): the shipped-policy
  replicates for E2 and E5 (the doc's section 4.5 reads `shipped` only for E8 and E9, and
  section 4.4 computes each E1-E5 verdict per (eval, policy) from the uniform rows alone);
  the E4 Arm-B-only critical-mode process sub-run (the doc says it "scores H6, never the
  outcome"); the aggregate verdict (it needs all ten evals). The report states
  `aggregate: not-evaluated, E6-E10 deferred` and lists the per-eval verdicts plus the
  pre-registered core condition "no WIN_A on E2 and E4" as a partial reading.
- OD-8 Who launches runs: the orchestrator or the operator launches every run that spawns a
  headless `claude` (the pilot and the full matrix). lead-programmer units never run
  `claude`; their acceptance criteria use a fake `claude` shim.
- OD-9 Not in the doc, chosen here: the per-run turn cap is enforced with the CLI flag
  `--max-turns`; the pilot proves the flag is accepted. Subagent turns inside Arm B are not
  counted by it, so "equal cap" means equal main-session `--max-turns` and equal wall-clock
  timeout, recorded per row.
- OD-10 (errata, 2026-10-16, E1 premise check) The design's E1 `premise` check (a required keyword grep of
  ASSUMPTIONS.md) is replaced. Two keyword matchers were built and both failed review: the grep passed an
  ASSUMPTIONS.md that records nothing, and the stricter matcher rejected about a third of plausible honest
  files (it did not accept the plant glossary's own term "taxable amount" or common phrasings of "after the
  discount") while still passing files that state no or the wrong assumption. Free-text assumption quality
  cannot be graded fairly by keywords, and a required keyword check tilts the comparison towards whichever
  arm happens to echo the matcher's words. E1 now carries `assumptions-file-present` (kind process, not
  required): ASSUMPTIONS.md exists at the repo root, has at least 2 non-blank lines and 40 non-space
  characters, and is not byte-identical to the baseline CONTEXT.md, the baseline README.md or the task
  prompt; it reads no wording and does not enter run_pass. Whether the assumptions are the right ones is
  judged only by the blinded `assumptions_cites_glossary` grade (unit abt-u15). E1 therefore has 3 required
  checks (tax-after-discount, existing-behaviour, scope-outside-allowed); the baseline fails 1 of 3 and the
  reference 0 of 3. The E1 prediction in the pre-registration changes accordingly: run_pass is a likely tie,
  and the differentiator is the blinded grade.
- OD-11 (2026-10-16, E5 README check) The same keyword-matcher problem applies to E5's README check
  `readme-data-format-v2` (`grep -qi "version.*2" README.md`): it is now a NON-required `docs` check, reported
  but not part of run_pass. `readme-tags-route` (`grep -q "/tags" README.md`, the literal route the prompt
  names) stays required. E5 therefore has 8 required checks; the baseline fails 6 of 8 and the reference 0 of 8.
  The runner reads each eval's required count from `verify-checks.sh` and passes it to `make-row.py`
  (`--expected-required`), so no count is hard-coded.
- OD-12 (2026-10-17, scorer N rule, directional label and Fisher errata; from the abt-u14 review FAIL of 2026-10-17T02:00:10Z)
  (a) A per-eval outcome exists only at the pre-registered N. 5 usable rows in each arm (usable = not
  `usage-limit`, and of the policy being reported) decide by the 2-run gap of the doc's section 4.4 (`k_B - k_A >= 2` is
  WIN_B, `k_A - k_B >= 2` is WIN_A, a 1-run gap is INCONCLUSIVE). 10 or more usable rows in each arm, equal in both,
  decide by the Fisher two-sided exact p < 0.10 (a 1-run gap is then a Fisher TIE: the top-up is what cures
  INCONCLUSIVE, so it must not trap an eval at N=10). Fewer than 5 rows in either arm (the N=1 pilot, a run
  stopped by a usage limit), unequal counts, or 6 to 9 rows per arm (a top-up in progress) are INCONCLUSIVE, with the
  reason in the report ("short N: A=3 B=5", "unequal N: ...", "top-up in progress: ..."). Two or more
  `turn-cap`, `timeout` or `error` rows in an arm stay INCONCLUSIVE at every N. A pilot never produces a verdict:
  pilot rows are ordinary rep-1 rows of the full matrix and carry no marker, so N < 5 is what stops them.
  (b) The doc's section 4.4 verdict semantics are unchanged: a 2-run gap at N=5 is WIN_B as pre-registered. The
  scorer always computes and prints the Fisher two-sided exact p for every eval, even below N=10 (JSON `fisher_p`,
  a markdown column), and the markdown marks a gap-rule WIN_B whose p is not below 0.10 as
  `superior (directional, p=0.xx)`; the JSON verdict stays `superior` and gains `directional: true`. `not-superior` is
  unchanged.
  (c) Errata to the doc's section 2.5: 5/5 vs 1/5 is p = 1/21 = 0.048 two-sided (not 0.024); a 3-run gap at 10 vs 10
  is p between 0.21 and 0.37 (not about 0.07); a 4-run gap is p between 0.087 and 0.179 (not below 0.05); 2/10 vs 7/10
  is p = 0.0698. The scorer's Fisher matches exact fractions on 20 tables, listed in `tests/abtest-score.test.sh`.
  (d) The scorer fails closed: an empty results file, a file with no usable row, a policy that matches no row, a
  duplicate run_id, a non-boolean `run_pass`, a `run_pass` true on a non-complete row, a malformed token or count
  field, or `tokens_total` different from input + output + cache write (OD-5) stops it with a named error and a
  non-zero exit. The report prints the `core_no_win_a` condition (no WIN_A on E2 and E4, OD-7) and the count of
  rows dropped for another `model_policy`.
- OD-13 (2026-10-17, stall override on an undecided outcome; clarification of OD-12(a); from the abt-u14 re-review)
  The stall override of the verdict rules (any `stalled-human` row in Arm B makes the eval `not-superior`) applies
  whatever the outcome, including an undecided one. A pilot (short N) or a 1-run gap with a stalled Arm B row
  therefore reports verdict `not-superior` while the outcome stays `INCONCLUSIVE` with its reason ("short N: A=1
  B=1"); without a stalled row the verdict is `inconclusive`. The outcome is never rewritten by the override.
- OD-14 (2026-10-17, provenance; binding operator decision from the abt-u14 re-review)
  Pilot rows are rep 1 of the full matrix and a resume skips run ids already done, so a harness, plugin or prompt
  fix after the pilot would mix pre-fix rep 1 with post-fix reps 2 to 5.
  (a) Scorer: for each (eval, arm, policy) group of usable rows, if the rows do not share one value of each of
  `harness_commit`, `plugin_commit`, `prompt_sha` and `fixture_commit`, the eval outcome is `INCONCLUSIVE` with the
  reason `mixed provenance: <fields>` (JSON `outcome_reason`, shown in the markdown). `null` is one value, so an
  Arm A group, which carries no plugin commit, is consistent when all its rows agree. `usage-limit` rows are exempt
  (already excluded). The check is per arm.
  (b) Runner: a run id counts as done only if an existing non-usage-limit row for it has the same `harness_commit`,
  `plugin_commit` (Arm B; an Arm A row must carry none) and `prompt_sha` as the current checkout and config.
  Otherwise the run is repeated and the stale row is kept in `results.superseded.jsonl` (override
  `ABT_SUPERSEDED`), which the scorer never reads, so run ids stay unique in `results.jsonl`. A `usage-limit` row is
  never superseded. A fix after the pilot therefore costs a repeat of the stale rows, not a mixed verdict.
- OD-15 (2026-10-17, E2 plan-text error found in the abt-u08 review, explorer-confirmed)
  The design's statement that the E2 "per-line round2 plant creates trap 2" is wrong and is withdrawn.
  `applyDiscountPercent` already rounds each discounted unit price to whole cents, so with or without the plant a
  preview that scales the total gives 0.54 and 53.06 where the per-item version gives 0.57 and 53.07. The
  discriminating E2 check is `rounding-sensitive-cart`; mutant `w8` passes all four checks and is a known
  surviving mutant of E2's checks until a unit adds a cart with non-whole-cent unit prices, where per-item and
  total rounding differ regardless of the whole-cent rounding. That cart is not sliced; adding it is an operator
  decision, and the pre-registration lists w8 as a limit of E2 until then.
- OD-16 (2026-10-17, harness isolation; binding, from the abt-u08 review)
  The arms must not be able to read the hidden checks, the reference solutions, the fixtures or the results during a
  run. (a) Arm B loads a pruned copy of the plugin made from the checkout's HEAD with `git archive` of an allow
  list (`.claude-plugin`, `agents`, `bin`, `commands`, `hooks`, `skills`, `templates`), never the checkout; the copy scaffolds exactly what the full checkout scaffolds. (b) Both arms run with
  `--disallowedTools` rules that deny Read, Edit and Bash commands naming the harness root and the results and runs
  directories (Read rules also govern Glob and Grep), with a per-run HOME outside the harness holding only a neutral
  git identity, and the arm scripts refuse a worktree, config dir or HOME inside the harness root (the runner puts
  the config dir under the work root). (c) A canary probe plants a random token in the checks and fixtures
  directories of the checkout and asks each arm to find and print it; the probe fails if the token appears in
  either stream, and the pilot gate requires it to pass. (d) Residual risk, stated in the README and the
  pre-registration: a deny rule cannot stop a shell command that never names the path, and a determined agent with
  a shell could still search the filesystem; the measures are defence in depth and the canary is a probe, not a proof.
- OD-17 (2026-10-18, shared allowed tools; binding operator decision from the first real isolation probe; amends the
  design's flag lines 36 and 322)
  The shared `--allowedTools` set is widened identically in both arms with read-only commands, so a correct run is
  not scored `stalled-human` for a benign piped read. Evidence (probe 2026-10-18, `run-matrix.sh --probe-isolation
  --probe-model uniform`): the Arm B explorer subagent ran `grep ... | grep -v ':0$' | head -50; echo ---; ls ...`;
  the stream held a `permission_denied` record with reason `subcommandResults`, so Arm B answered correctly and was
  classified `stalled-human` (spec 4.1, OD-3, OD-13).
  (a) The set: `Bash(npm test)`, `Bash(npm run *)` and `Bash(git *)` as before, plus `Bash(<command> *)` for grep, ls,
  find, cat, head, tail, wc, sort, cut, echo, pwd, diff, stat, basename and dirname (15 commands, 18 rules in all).
  `uniq` is not in the set because the form uniq IN OUT writes OUT; `sort -u` replaces it. Claude Code matches a
  compound command (`|`, `;`, `&&`, `||`) one subcommand at a time and each needs its own allow rule, so every
  command of such a pipeline has a rule.
  (b) What the set can and cannot write. Not added: rm, mv, cp, chmod, chown, ln, sed, awk, tee, touch, mkdir, uniq,
  curl, wget, ssh, any network command, any interpreter or shell. By their documented options the 15 added commands
  write no file, except `find` (-fprint, -fprintf, -fprint0, -fls and -delete write or delete; -exec, -execdir, -ok
  and -okdir run another command) and `sort` (-o and --output write the named file; --compress-program runs a
  program), and the deny rules in (c) name those forms. They name them by their usual spelling only: `sort` with
  combined short flags ending in o (for example `sort -uo OUT IN`) or with a quoted flag (`sort "-o" OUT IN`) is
  matched by no rule, so `sort` can still write a file named on its command line; this is residual risk of the kind
  OD-16(d) states, and a deny rule is not a security boundary around a program. A redirect or a tee target is checked
  by Claude Code against its Edit rules, so a redirect into the worktree stays governed by `--permission-mode
  acceptEdits` as before. Two allows already in place write far more than this decision does and are unchanged:
  `Bash(git *)` and `Bash(npm run *)` can write outside the worktree (for example `git -C DIR ...`,
  `git clone URL DIR`, or an npm script).
  (c) Deny rules are checked before allow rules, so `--disallowedTools` carries 16 find and sort rules. Claude Code
  matches a rule against the command text with `*` standing for any text, spaces included, so `Bash(find *-ok*)` would
  also deny `find . -name '*-ok*'` and `Bash(sort *-o*)` would deny `sort log-old.txt`. The rules are anchored to a
  space or to the start of the arguments instead: `Bash(find * -exec*)`, `Bash(find * -ok*)`,
  `Bash(find * -delete*)`, `Bash(find * -fprint*)`, `Bash(find * -fls*)`, the same five without the path word
  (`Bash(find -exec*)` and so on, because the docs do not say that a `*` inside a pattern can match nothing),
  `Bash(sort -o*)`, `Bash(sort * -o*)`, `Bash(sort --output*)`, `Bash(sort * --output*)`,
  `Bash(sort --compress-program*)` and `Bash(sort * --compress-program*)`. The tests model a rule as a shell glob
  and check that `sort log-old.txt` and `find . -name x-ok.txt` match none of them and that the write forms match at
  least one. Verified: the wildcard and compound-command rules quoted from the permissions page (read 2026-10-18).
  Not verified: that Claude Code's matcher agrees with a shell glob on every input; no test runs the real matcher.
  The OD-16 rules for the harness root (Read, Edit and `Bash(*<root>*)`) still win over every allow. A command that
  the rules cannot name, such as a shell that never names the path, is the residual risk stated in OD-16(d).
  (d) Stall detection in lib/stream.py is unchanged: any permission denial or ask is still `stalled-human`, and a
  command outside the set is still a stall. `--probe-model uniform` stays report-only (abt-u13c).
  (e) Whether the widening removes the denial seen in the probe is confirmed only by re-running the probe; that is
  the operator's step, and no test spends usage for it. The pre-registration is amended before the first run.
- OD-18 (2026-10-18, canary probe semantics; clarifies OD-16(c) and (d); from the first real canary probe, abt-u13f)
  Evidence (probe 2026-10-18, `run-matrix.sh --probe-canary`, after OD-17): both arms replied `not-found`, the prompt's
  `find /` lay outside the per-run work directory and was refused, lib/stream.py classed each run `stalled-human`
  (permission_denials 1), and the probe read that as `not-run` and exited 1.
  (a) The canary question is whether an arm can reach and print the planted token, not whether the run needed a human,
  so the probe judges the stream and the reply only. A token anywhere in an arm's stream is `FOUND`, whatever the
  run's status. A `complete` or `stalled-human` run that did not print it is an answer (`not-found`), as in the
  mention case (abt-u13c). `turn-cap`, `timeout` and `error` stay `not-run`, and a usage limit still exits 75. The
  denied command is printed in `probe-detail: <arm> denied <tool>: <command>` and the count in `probe: canary-denials
  A=<n> B=<n>`. Stall classification (lib/stream.py, OD-3, OD-13, OD-17(d)) is unchanged: it governs scored rows,
  not this probe.
  (b) What a denied search proves. A refused `find /` shows that the most direct route to the planted files is closed
  for an arm that tried it. It does not show that the token is unreachable by other means (a path guessed from the
  environment, an allowed command that names a directory above the work directory, a shell that never names the
  harness root), so `not-found` is a probe of the common route and never a proof. This extends OD-16(d); it does not
  replace it.
  (c) Positive control. Each arm's work directory holds `control-token.txt` with a second random token
  (`ABT-CONTROL-<hex>`) and the prompt asks for `find . -name 'control-token.txt'` and its content. An answered arm
  whose stream lacks the control token is `no-control` and fails the probe (exit 1), because a probe that cannot see a
  token printed from the work directory cannot see a leak. The control proves only that a token the arm prints
  reaches the stream the probe searches; it says nothing about the checks or fixtures directories.
- OD-19 (2026-10-18, all of Bash for both arms; binding operator decision, option 1, from the 2026-10-18 pilot;
  supersedes OD-17(a)-(c) where they conflict)
  Evidence (pilot 2026-10-18, eval/abtest/results.jsonl, runs under eval/abtest/.runs/): 4 of 10 rows were
  `stalled-human` (E3 B, E4 B, E5 A and B) and the other 6 completed (E1 A and B, E2 A and B, E3 A, E4 A); each
  stalled row has `permission_denied` system records on
  ordinary dev commands. Decision reasons seen: `subcommandResults` (`node -e`, a heredoc `python3 - <<'EOF'`,
  `node --test ...; head`), "Quoted text in this command can't be checked before it runs", "A variable in this command
  can't be checked before it runs", "Contains brace with quote character (expansion obfuscation)" and "Parser skipped
  input between top-level statements". Widening a list of read-only commands cannot fix this class, and left as it
  was the stalls would measure the permission rules, not the arms.
  (a) The rule. `--allowedTools` is the single value `Bash` (every Bash command) in both arms, in place of the 18 rules
  of OD-17(a). Unchanged and still binding: `--permission-mode acceptEdits`, `--disallowedTools`, the per-run HOME, the
  work directory and config directory outside the checkout, the pruned plugin copy (OD-16(a)-(b)). The arms stay equal:
  one function builds the flags for both.
  (b) Removed. The 16 find and sort deny rules of OD-17(c) are gone. They kept a read-only list read-only; with every
  command allowed, `find -exec` and `sort -o` add nothing a plain shell lacks, and each is one more denial that would
  stall a correct run. `uniq` is no longer a question for the same reason.
  (c) Kept. `--disallowedTools` carries the four OD-16 rules for the harness root and for each path of
  ABTEST_DENY_PATHS (`Read(/<p>)`, `Read(/<p>/**)`, `Edit(/<p>/**)`, `Bash(*<p>*)`). The deny flags are now put ahead of
  the allow flags on the command line; the order is for the reader, not what makes them win.
  (d) Verified (Claude Code docs read 2026-10-18 by a claude-code-guide lookup, quoted, not run): `Bash(*)` is
  equivalent to the bare `Bash` and matches all Bash commands; rules are evaluated "deny, then ask, then allow" and "an
  allow rule can't carve an exception out of a deny rule"; deny rules apply when any subcommand matches, including one
  inside a command substitution, a subshell or a loop body; deny rules block in every permission mode; in
  `stream-json` a denial appears as a `permission_denied` system message. Not verified: that flag position is
  irrelevant (the docs order rules by type, not by flag position); that an allow of all Bash silences the parser safety
  checks quoted in the evidence (the docs do not mention heredocs, `$VAR`, "expansion obfuscation" or "Parser skipped
  input", so those checks may still force a denial in a headless run); that `Bash(*<root>*)` matches every spelling of
  the root. No test runs the real matcher.
  (e) Residual risk, enlarged (extends OD-16(d)). A deny rule matches the command text Claude writes, so a shell can
  now search the filesystem and read what it finds: `find / -name '*.tok' -exec cat {} +` names no harness path and is
  allowed. Through the shell an arm can also write outside the worktree and read the operator's real home (the per-run
  HOME only changes what `~` means). The OD-16 measures stay as defence in depth, and the canary probe with its control
  token (OD-18) is the check: it may now report `FOUND`, and that is the result it exists to give. A `FOUND` blocks
  everything (no pilot, no full pass) and needs a new operator decision on isolation; nothing here chooses it.
  (f) Stall detection in lib/stream.py is unchanged (OD-3, OD-13, OD-17(d)): a real ask or denial, for example a
  command a deny rule matches or a safety check the allow does not silence, is still `stalled-human`.
  (g) Whether the stalls stop is confirmed only by re-running. After this lands, the operator re-runs, in order,
  `run-matrix.sh --probe-isolation`, `run-matrix.sh --probe-canary` and `run-matrix.sh --pilot`. The 10 pilot rows of
  2026-10-18 were made by the previous harness; the change moves `harness_commit`, so they are superseded under OD-14
  and the pilot repeats them. If the pilot still stalls on the safety checks of (d), that is a new operator decision
  (for example a different permission mode); this decision does not make it.
- OD-20 (2026-10-19, two Bash gates relaxed in the Arm B plugin copy; binding operator decision from the second pilot)
  Evidence (eval/abtest/results.superseded.jsonl and eval/abtest/results.jsonl, run
  eval/abtest/.runs/e03-rename-query_B_uniform_1/): 4 of 10 rows stalled in pilot 1 and 1 of 10 in pilot 2. The pilot 2
  row is E3 B (`human_interventions_required` 3, `permission_denials` 3). Two of its three denials are hook denials
  (exit 2) of read-only Bash commands, and lib/stream.py counts any denial as `stalled-human` (OD-3, OD-13).
  (1) hooks/scripts/harness-integrity-gate.sh blocked `git status --short | head -20 && ... && ls .claude/agents
  2>/dev/null; cat .claude/persona-config.json 2>/dev/null | head -30` (the Bash text names the audit and config
  surface of Set A). (2) hooks/scripts/reviewed-path-gate.sh blocked `head -1 .claude/reviewed/<id>.pass; ls
  .claude/.pending-review.* 2>&1; git status --short` (the Bash text names the marker directory). Both commands only
  read, so both denials are false positives, and left as they are the stalls would measure the two gates, not the arms.
  (a) The rule. In the plugin copy that arm-b.sh loads (abtest_plugin_copy in eval/abtest/arms/common.sh, through
  abtest_relax_bash_gates), hooks/hooks.json stops registering harness-integrity-gate.sh and reviewed-path-gate.sh for
  the Bash matcher; the function fails the copy unless exactly those two entries go. The scaffold builds the worktree's
  settings.json from that hooks.json, so the two gates are absent there for Bash too.
  (b) Unchanged. hooks/scripts/ in the product tree and in the copy (byte-identical), the shipped plugin, the Write
  and Edit registrations of both gates, the PostToolUse registration of harness-integrity-gate.sh, every other hook
  (human-decision-gate.sh stays on the Bash matcher), Arm A (it loads no plugin) and lib/stream.py.
  (c) Cost. In Arm B a Bash command that writes the audit and config surface or the review marker directory is no
  longer stopped by these two gates (a Write or Edit still is). The relaxation is for the eval run only and the report
  must say that Arm B ran with the two gates relaxed (pre-registration amendment 2026-10-19).
  (d) Not covered. The same row holds a third denial, a `permission_denied` record (`subcommandResults`) for
  `sed -n '1,/^---$/p' .claude/agents/lead-programmer.md`. It comes from the permission rules, not from a hook, and
  this decision does not touch it. If the pilot still stalls on it, that is a new operator decision.
  (e) Whether the stalls stop is confirmed only by re-running. After this lands, the operator re-runs, in order,
  `run-matrix.sh --probe-isolation`, `run-matrix.sh --probe-canary` and `run-matrix.sh --pilot`. The 10 rows of the
  second pilot were made by the previous harness; the change moves `harness_commit`, so the 10 rows of the second
  pilot are superseded under OD-14 by this harness change and the pilot repeats them.
- OD-21 (2026-10-19, the answer key is made unreadable to the arm while it runs; binding operator decision, option 1, from the canary probe after OD-20)
  Evidence (eval/abtest/.runs/probe-canary/A/stream.jsonl and B/stream.jsonl, run on 2026-10-19 after OD-19 and OD-20):
  the probe returned FOUND for both arms. Each arm ran `find / -name '*holdout*' -o -name 'reference.patch' -o -name
  'canary-*'`, which listed paths under the WSL alias /mnt/wslg/distro/home/sebas/AntiSlop/..., then printed the token (arm B with
  `xargs -d '\n' grep -H 'ABT-CANARY'` and a while-read `cat` loop, arm A also with `cat` on the /mnt/wslg path) from eval/abtest/checks/e01-ambiguous-tax/canary-holdout.txt and
  eval/abtest/fixtures/e01-ambiguous-tax/canary-reference.patch. The deny rules of OD-16 match only the literal absolute
  root, so an alias spelling, a glob, a relative path or an xargs route bypasses them; this is the residual risk OD-19 named.
  (a) The rule. While an arm process runs, run-matrix.sh sets every file and directory under the harness secrets to mode
  000: eval/abtest/checks and the fixtures directory (eval/abtest/fixtures, or ABT_FIXTURES_DIR). The reference solutions,
  the hidden tests and the canary files all live under these two, and ABT_LOCK_PATHS (colon-separated) replaces the
  list. The lock is on the inode, so a symlink, a glob, a relative path, an xargs route and the /mnt/wslg alias get
  permission denied alike. It is taken inside run_guarded, which every arm start goes through (a run, the isolation probe
  and the canary probe), after the work tree, the plugin copy inputs and the fixture build are done.
  (b) Restore. The original modes are recorded in a manifest under ABT_WORK and put back after the arm exits and before
  anything is scored, on every exit path: normal, wall-clock timeout, arm failure, usage-limit exit 75 and 76, and SIGINT,
  SIGTERM and SIGHUP (the EXIT trap). SIGKILL of the runner cannot be trapped: the manifest then stays, and the next runner
  restores it before it starts anything.
  Known residuals: the arm can write the manifest $ABT_WORK/.secrets-lock.manifest (ABT_WORK holds the arm's own work
  tree and the manifest is not in ABTEST_DENY_PATHS), so "restored on every exit path" holds absent tampering; deleting
  it makes the restore a no-op. Stale-manifest repair runs only when the next runner uses the same ABT_WORK, and a
  SIGKILLed runner leaves its arm session alive (reap_arm never ran), so the next start can restore modes while that
  orphan still runs. A process that calls setsid survives reap_arm and sees the restored modes.
  (c) Fail closed. If the lock cannot be taken, or a mode cannot be restored, the runner aborts with exit 1 and a message
  naming the path; no arm is started on a failed lock. Root is refused, because mode 000 does not stop root.
  (d) Deny rules, best effort. Both arms also get deny rules for chmod, chattr, setfacl, install, mv, cp and ln on the names
  abtest/checks, abtest/fixtures, holdout, reference.patch and canary-. The same user can still change a mode in ways
  the rules do not match, for example a path built in a variable, a cd into the alias followed by chmod, a glob, python3
  os.chmod or find -exec chmod, so the lock is not proof; the canary probe stays the check. It now also prints
  `probe: canary-lock covered=yes restored=yes`, fails if a canary file lies outside the lock, and fails if it is
  unreadable after the restore. While the lock holds, a read of a canary file by an arm gets permission denied.
  (e) Fingerprint. A row carries `harness_commit`, `plugin_commit` and `prompt_sha`, and the runner counts a run id done
  only when all three match the current checkout (OD-14(b)). This change moves `harness_commit`, so none of the rows made
  before this change counts toward the full run: the runner moves them to results.superseded.jsonl and repeats them. The
  rows of the pilots before this change were made with the answer key readable; that no arm read it is evidence only by
  keyword scan of the streams, not by prevention, and it does not carry over.
  (f) Not changed. hooks/, lib/stream.py, the scorer, Arm B's plugin copy and OD-19's allow list. The operator re-runs, in
  order, `run-matrix.sh --probe-isolation`, `run-matrix.sh --probe-canary` and `run-matrix.sh --pilot`; a canary `FOUND`
  after this change blocks everything.
- OD-22 (2026-10-19, whole-run token and turn count; binding operator decision from pilot 4, 2026-10-19)
  Evidence (eval/abtest/.runs/*_B_uniform_1/stream.jsonl, pilot 4): an Arm B stream holds 3 to 8 `result`
  records, one per main-session segment, and lib/stream.py read the last one only. Each record's `usage`
  counts the main thread of its own segment only (their sum equals the main model's `modelUsage` entry), so
  B's `tokens_total` was 3205 to 4678, while the last record's `modelUsage` is cumulative over the whole run
  and every model, subagents included (B: 285138, 227318, 197667, 154522 and 831801 for E1 to E5; its
  `costUSD` sum equals `total_cost_usd`). Each record's `num_turns` is per segment too (E1 B: 12, 8, 5, 6, 3
  and 2, so 36 main-session turns were reported as 2). `duration_api_ms` is the same on every record of a
  stream, so it is already a whole-run value. Every Arm A stream holds one record, where all readings agree.
  (a) The rule. `tokens_in`, `tokens_out`, `tokens_cache_write` and `tokens_cache_read` are the sums over all
  models of the last result record's `modelUsage` (`inputTokens`, `outputTokens`,
  `cacheCreationInputTokens`, `cacheReadInputTokens`); when `modelUsage` is absent or empty, they are the sums
  of `usage` over every result record. `tokens_total` stays input + output + cache write (OD-5). `num_turns`
  is the sum over every result record, which is the main-session turn count of OD-2 and OD-9.
  `duration_api_ms`, `total_cost_usd` and `model_usage` stay read from the last record, which is already
  cumulative.
  (b) Unchanged. The definitions of `tokens_total` (OD-5) and of the turn count (OD-2, OD-9), the R_tokens,
  R_wall and R_turns thresholds, the checks, the allowed paths, the prompts and every verdict rule. Arm A
  values are unchanged (one record).
  (c) Not covered. The model policy of Arm B rows is OD-23.
  (d) Fingerprint. This change moves `harness_commit`, so under OD-14 every pilot-4 row is superseded and
  repeated.
