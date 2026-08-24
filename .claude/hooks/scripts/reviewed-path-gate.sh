#!/usr/bin/env bash
# PreToolUse (Bash). Attributes the caller from the top-level `agent_type`
# field and blocks Bash commands whose text touches `.claude/reviewed` (the
# PASS-marker directory) unless the caller is the reviewer, or the main
# session/team lead in the documented no-reviewer fallback (personaSelection
# does NOT contain "reviewer" - start-feature-team.md:49-53, orchestrator.md's
# "if no reviewer persona exists"). Any other caller (lead-programmer above
# all) is blocked. Guards on persona-config.json existing, same as every other
# gate.
#
# `agent_type` carries an AGENT IDENTITY - the possibly-namespaced wire value
# "[<namespace>:]<persona-name>" - not a bare persona name. Probe A
# (docs/experiments/2026-07-probe-hook-payloads.md) established that the field
# is PRESENT on a subagent-issued Bash PreToolUse payload; it did not establish
# its value space, and the field is in fact observed arriving namespaced
# (`antislop:reviewer`). Both sides are therefore normalized through
# lib/agent-identity.sh, with the two matchers failing in opposite directions
# by design: the reviewer-may-write decision is a privilege GRANT and uses the
# conservative matcher (a foreign namespace must never inherit authority over
# the PASS markers), while the personaSelection test is a GATE and uses the
# liberal one, since a miss there only makes the main session's write allowed.
#
# Write-intent allowlist (docs/plans/2026-07-31-reviewed-path-gate-write-intent.md):
# past the substring early-exit, a Bash command mentioning ".claude/reviewed"
# is allowed if command_is_provably_benign() below finds it read-only or
# text-only (ls, cat, grep, gh ...) and blocked otherwise, so read-only
# inspection and prose mentions of the path are no longer collateral. A write
# whose ONLY mention sits in a trailing `#` comment is allowed too, via
# write_with_commented_mention() below - bash discards that text, so the same
# command with the comment deleted never spells the path and the substring
# early-exit already allows it (2026-08-24 spec, decision A).
# This is advisory, not airtight - a determined agent can still obfuscate the
# path past both the substring early-exit and the allowlist (e.g. splitting it
# across a shell variable); see README.md's "Known limitations", same framing
# as the existing `sed -i` bypass caveat on protected-paths.sh.
set -euo pipefail

source "$(dirname "${BASH_SOURCE[0]}")/lib/agent-identity.sh"
source "$(dirname "${BASH_SOURCE[0]}")/lib/benign-command.sh"

# Length-preserving mask of every `#` COMMENT BODY, leaving quoted spans intact.
# Every fail-closed rule is DELEGATED to command_skeleton() rather than restated:
# this reads the skeleton that function already produces, so a heredoc, an
# unbalanced quote and the three unmodelled backslash positions return non-zero
# here too, and no second copy of bash's comment/word-start semantics exists to
# drift from the first.
#
# In a skeleton, `X` appears only where a quoted body or a comment body was
# masked, and a quoted body is always preceded by its own quote character. So an
# `X` immediately after a literal `#` can only be a comment body, and the run of
# `X`s after it is exactly that body (the newline ending it is never masked). The
# one other way `#X` can occur is a non-comment `#` followed by a literal `X` in
# the command itself, where copying an `X` over an `X` changes nothing. Since
# `.claude/reviewed` contains no `X`, neither case can erase part of a real
# mention - which is what makes the caller's test below sound.
mask_comments_only() {
  local cmd="$1" skel out="" pre run pad
  # `$(...)` strips TRAILING newlines, so the skeleton may be shorter than the
  # command. Both are consumed from the FRONT in lockstep and whatever is left of
  # the command is appended raw, so the offsets stay aligned regardless.
  skel="$(command_skeleton "$cmd")" || return 1
  while :; do
    pre="${skel%%#X*}"
    if [ "$pre" = "$skel" ]; then
      printf '%s' "$out$cmd"
      return 0
    fi
    run="${skel:${#pre}+1}"
    run="${run%%[!X]*}"
    printf -v pad '%*s' "${#run}" ''
    out="$out${cmd:0:${#pre}+1}${pad// /X}"
    cmd="${cmd:${#pre}+1+${#run}}"
    skel="${skel:${#pre}+1+${#run}}"
  done
}

# command_is_provably_benign() with its write test replaced by "no mention of the
# marker directory survives comment-masking". A mention bash throws away is not
# this gate's business: if every occurrence sits inside a comment body, then the
# same command with its comments deleted behaves identically and its text never
# spells the path, so the substring early-exit below already allows it today.
# That is the zero-marginal-capability argument, measured for THIS gate rather
# than inherited from human-decision-gate.sh, which protects one file where this
# protects a directory (R-13: `printf x > u1.pass` is allowed today, so its
# commented twin adds nothing).
#
# The program allowlist, the substitution rejection and the eval/exec/source scan
# are all kept, so `sh -c 'printf x > 9.pass'` with the mention in a comment stays
# denied. The `git commit` recognizer human-decision-gate.sh carries is
# deliberately NOT ported here (2026-08-24 spec, decision A): `git commit -F
# <file>` is a sanctioned workaround for THIS gate, so a commit message
# discussing the marker directory traps nobody, and `git` stays off the shared
# allowlist whole (#186).
write_with_commented_mention() {
  local cmd="$1" masked skel rest head start=0 seps=$';&|\n'
  case "$cmd" in
    *'`'*|*'$('*|*'<('*) return 1 ;;
  esac
  masked="$(mask_comments_only "$cmd")" || return 1
  case "$masked" in *".claude/reviewed"*) return 1 ;; esac
  skel="$(command_skeleton "$cmd")" || return 1
  skel="$(mask_inert_redirections "$skel")"
  if printf '%s' "$skel" | grep -Eq '(^|[^[:alnum:]_])(eval|exec|source)([^[:alnum:]_]|$)'; then
    return 1
  fi
  rest="$skel"
  while :; do
    head="${rest%%[$seps]*}"
    segment_allowed "${cmd:start:${#head}}" || return 1
    [ "$head" != "$rest" ] || return 0
    start=$((start + ${#head} + 1))
    rest="${rest:${#head}+1}"
  done
}

input="$(cat)"
project_dir="${CLAUDE_PROJECT_DIR:-.}"
config="${project_dir}/.claude/persona-config.json"
[ -f "$config" ] || exit 0

command="$(echo "$input" | jq -r '.tool_input.command // empty' 2>/dev/null || true)"
subject="$command"
write_tool=""

if [ -z "$command" ]; then
  # Second input shape: Write/Edit carries `.tool_input.file_path` where Bash
  # carries `.tool_input.command`. Keyed on has(), not on emptiness: a payload
  # with no file_path key at all (NotebookEdit's `notebook_path`, say) targets
  # no file this gate owns, while a PRESENT but unusable one is a write whose
  # target cannot be read and fails closed below. A payload jq cannot read at
  # all exits 0 - the same precondition every other hook here takes.
  has_path="$(echo "$input" | jq -r '(.tool_input|type) == "object" and (.tool_input|has("file_path"))' 2>/dev/null)" || exit 0
  [ "$has_path" = true ] || exit 0
  write_tool=1
  file_path="$(echo "$input" | jq -r '.tool_input.file_path // "" | tostring' 2>/dev/null || true)"
  if [ -z "$file_path" ]; then
    # A write whose target cannot be read is not provably outside the marker
    # directory, so it is blocked rather than guessed at - including for the
    # reviewer, whose GRANT has no path to apply to here.
    echo "BLOCKED: this Write/Edit carries an empty file_path, so reviewed-path-gate.sh cannot establish where it writes. Blocked by design (this gate fails closed) - reissue the call with an explicit path." >&2
    exit 2
  fi
  # Project-root-relative, the same normalization protected-paths.sh:22-25
  # does. The match below is a substring test and holds for either form; the
  # strip keeps the block message readable.
  subject="$(normalize_path "$file_path")"
  case "$subject" in
    "$project_dir"/*) subject="${subject#"$project_dir"/}" ;;
  esac
fi

case "$subject" in
  *".claude/reviewed"*) ;;
  *) exit 0 ;;
esac

agent_type="$(echo "$input" | jq -r '.agent_type // empty' 2>/dev/null || true)"

# Only past the substring early-exit above: this hook fires on EVERY Bash call
# and every Write/Edit in the session, and the hot path must pay nothing for
# the audit log.
review_audit="${project_dir}/.claude/review-audit.log"
identity_drift_log "$agent_type" reviewed-path-gate "$review_audit"

if persona_matches_grant "$agent_type" reviewer; then
  exit 0
fi

# Bash-command path only: a Write or Edit into the marker directory is a write
# by definition, so there is no benign carve-out on that shape.
if [ -z "$write_tool" ] && command_is_provably_benign "$command"; then
  exit 0
fi

# Same Bash-only restriction, for the same reason: a Write/Edit into the marker
# directory has no comment to hide a mention in.
if [ -z "$write_tool" ] && write_with_commented_mention "$command"; then
  exit 0
fi

if [ -z "$agent_type" ]; then
  has_reviewer=""
  personas="$(jq -r '.personaSelection[]? // empty' "$config" 2>/dev/null || true)"
  while IFS= read -r persona; do
    if persona_matches_gate "$persona" reviewer; then
      has_reviewer=1
      break
    fi
  done <<< "$personas"
  if [ -z "$has_reviewer" ]; then
    # Only the reviewer writes .escalated, so a standing one under a
    # reviewer-less config proves the reviewer was deselected AFTER the
    # escalation was raised - exactly the laundering transition this closes.
    shopt -s nullglob
    escalated_markers=( "${project_dir}"/.claude/reviewed/*.escalated )
    shopt -u nullglob
    if [ "${#escalated_markers[@]}" -gt 0 ]; then
      echo "BLOCKED: this project has a standing .escalated marker with no reviewer persona selected to resolve it. The only route that resolves an escalation is the DECISION channel (per Step 1/#325's gate); if this project has permanently deselected its reviewer with a stale escalation on file, that decision belongs to a human at their own terminal, not to this fallback." >&2
      exit 2
    fi
    exit 0
  fi
  echo "BLOCKED: this project has a reviewer persona selected, so the main session/team lead may not write to .claude/reviewed/ itself - route the unit to the reviewer instead, per persona-protocol.md's Review Ownership section." >&2
  exit 2
fi

if [ -n "$write_tool" ]; then
  { printf '%s grant-denied hook=reviewed-path-gate identity=%s\n' \
      "$(date -u +%Y-%m-%dT%H:%M:%SZ)" "$(_identity_sanitize "$agent_type")" \
      >> "$review_audit"; } 2>/dev/null || true
  echo "BLOCKED: '${agent_type}' may not write '${subject}' - only the reviewer creates .pass/.fail/.blocked records in .claude/reviewed/ (or the main session/team lead, ONLY in the documented no-reviewer fallback where no reviewer persona is selected). Per persona-protocol.md's Review Ownership section. Every Write/Edit into that directory is a write by definition, so the read-only exemption that applies to Bash commands does not apply here." >&2
  exit 2
fi
{ printf '%s grant-denied hook=reviewed-path-gate identity=%s\n' \
    "$(date -u +%Y-%m-%dT%H:%M:%SZ)" "$(_identity_sanitize "$agent_type")" \
    >> "$review_audit"; } 2>/dev/null || true

echo "BLOCKED: '${agent_type}' may not write to .claude/reviewed/ via Bash - only the reviewer writes the PASS marker there (or the main session/team lead, ONLY in the documented no-reviewer fallback where no reviewer persona is selected). Per persona-protocol.md's Review Ownership section. Read-only inspection (ls, cat, grep, test ...) and text-only mentions of the path in a gh issue/pr comment ARE allowed; this command was recognized as neither, because it redirects, substitutes, runs a program that could write, or could not be lexed at all (an unbalanced quote, a backslash escape and a heredoc are never assumed benign). Note that 'git' and 'rg' are NOT allowlisted at all, whatever the subcommand - see program_allowed() for why. To land a commit whose MESSAGE discusses this path, put the message in a file and use 'git commit -F <file>', whose command text then never spells the path; to search the directory, use 'grep -r'. That rephrasing workaround is sanctioned for THIS gate only, which grants the reviewer an identity - it is never for human-decision-gate.sh, which grants no identity at all, and rewording a command so that gate's scan stops seeing the path it protects is a self-authorized bypass. Use the sanctioned marker-write template that gate prints in its own refusal instead. All of that governs commands TARGETING this directory. A mention that only NARRATES it is allowed outright and needs no workaround: a trailing '#' comment naming the directory passes, whatever the rest of the command does, because bash discards it. What you hit is narrower - this command's text spells the path where bash would act on it (in code, in a quoted word, or as a redirection target), or it could not be lexed at all. A comment on a line of its OWN still fails closed; that is a ratified residual (issue #183), so keep the comment on the same line as the command." >&2
exit 2
