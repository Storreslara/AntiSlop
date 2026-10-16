# Gate false-positive corpus: share of real gate blocks that families F1 and F3 free (item 7b)

Source: `docs/plans/2026-10-15-persona-token-reduction.md`, steps U7b-1 and U7b-2 (ruling H-U7B). This is a skeleton: the user fills the real-store counts in human step H7b2, and until then the families' real share is unmeasured.

## Method

- Script: `scripts/gate-fp-harvest.py` (`python3 -I`). It reads only this repository's project directory under `~/.claude/projects` (the working directory with every `/` replaced by `-`): `<root>/*.jsonl` and `<root>/*/subagents/*.jsonl`.
- Hit: a `Bash` tool_use whose paired tool_result (same `tool_use_id`) has `is_error: true` and text containing `BLOCKED`, timestamped in `[since, until)`. The gate is the first of `reviewed-path-gate`, `human-decision-gate` and `harness-integrity-gate` found in the result text, else `other`.
- Distinct exact command strings are counted. A command over 4,096 characters is `oversize` and not classified; D, the denominator, is the number of distinct commands that are not oversize.
- The classifier is the lib itself: a `bash` subprocess sources a lib and calls `command_is_provably_benign` with the command as an argument. A command is flipped when it is non-benign under `--baseline-lib` and benign under `--lib`.
- Family attribution of flipped commands is a fixed syntactic rule, and a command may count in several families. F1: it starts with `cd <word>` followed by `&&` or `;`, where the word holds no whitespace, `;`, `&`, `|`, `$`, backtick, `*`, `?` or `[`. F2: it contains `2>&1`, `2>/dev/null` or `>/dev/null`. F3: any segment (split on `|`, `;`, `&&` and `||`) starts with one of `du sort uniq cut tr nl jq`.
- Output: one markdown table (rows `hits`, `distinct`, `oversize`, `classified`, `F1`, `F2`, `F3`, `flipped`, `still-blocked`, one `gate:<name>` per gate; shares are count over D to 3 decimals), `leaks=<n>` (`--check-doc`) or `filled <path>` (`--fill-doc`). No mode prints, writes or returns a command, and no harvested command text is committed anywhere.
- Reproduction is per-machine and best-effort: the store is local and transcript cleanup can delete in-window sessions. Both libs come from fixed commits, so a later lib edit cannot change a re-run.

## Human step H7b2

The user runs this from the repository root, in their own terminal, after U7b-2 PASS. `d66c7b36005b58732e02e6d7a03d6419474e4e10` is the parent of U7b-1's first commit and `e0bb238cf52f431dfebea3de11610bf1204f88d1` is U7b-1's final commit.

```
b="$(mktemp)"; n="$(mktemp)"
git show d66c7b36005b58732e02e6d7a03d6419474e4e10:hooks/scripts/lib/benign-command.sh > "$b"
git show e0bb238cf52f431dfebea3de11610bf1204f88d1:hooks/scripts/lib/benign-command.sh > "$n"
python3 -I scripts/gate-fp-harvest.py --since 2026-09-25T00:00:00Z --until 2026-10-16T00:00:00Z --lib "$n" --baseline-lib "$b" --fill-doc docs/audits/2026-10-15-gate-fp-corpus.md
python3 -I scripts/gate-fp-harvest.py --since 2026-09-25T00:00:00Z --until 2026-10-16T00:00:00Z --lib "$n" --baseline-lib "$b" --check-doc docs/audits/2026-10-15-gate-fp-corpus.md
```

The second command must print `leaks=0`; a higher value means do not commit, run `git checkout -- docs/audits/2026-10-15-gate-fp-corpus.md` and report it. Then commit the doc by explicit path. Re-running the first command and then `git diff --exit-code -- docs/audits/2026-10-15-gate-fp-corpus.md` exits 0 on the measuring machine.

## Result

<!-- harvest:begin -->
PENDING: real-store harvest, human step H7b2
<!-- harvest:end -->

If the user declines H7b2, this document stays PENDING, which is a valid end state.
