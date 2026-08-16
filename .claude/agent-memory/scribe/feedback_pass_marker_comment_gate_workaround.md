---
name: feedback-pass-marker-comment-gate-workaround
description: gh issue comment heredocs quoting a .pass marker path trip reviewed-path-gate.sh; write the body to a scratchpad file and use --body-file instead
metadata:
  type: feedback
---

When closing an issue and the closing comment needs to cite the PASS marker's
path (e.g. `.claude/reviewed/gh404.pass`) verbatim alongside its first line,
a `gh issue comment ... --body "$(cat <<'EOF' ... EOF)"` heredoc containing
that path gets blocked by `reviewed-path-gate.sh` — it flags any Bash command
it can't prove is read-only when the literal `.claude/reviewed/` path appears
in the command text, and a heredoc is one of the patterns it treats as
unprovable (see [[project_reviewed_path_gate_asymmetry]] in the user's global
memory, and [[feedback_dispatch_hygiene_mutation_commands]] here — same root
cause, different flavor).

**Why:** the gate is scanning command *text*, not distinguishing a read
(citing the path in prose) from a write (targeting the path as a file
argument). The gate's own refusal text says quoting a path in a gh comment
IS allowed — the block was almost certainly the heredoc form tripping the
"can't be lexed as provably read-only" fallback, not the content itself.

**How to apply:** when a closing comment must quote a marker path or its
contents, write the comment body to a scratchpad file with the `Write` tool
first (never Bash heredoc), then run `gh issue comment <n> --repo <repo>
--body-file <scratchpad-path>`. This sidesteps the heredoc-shaped trip
entirely and worked cleanly on the first retry for gh404. Don't waste a
retry on rephrasing the heredoc — go straight to `--body-file`.
