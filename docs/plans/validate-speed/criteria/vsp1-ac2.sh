#!/usr/bin/env bash
# vsp-1 AC1.2: the default (lane) run works from a linked git worktree. Every lane sees the
# worktree's own HEAD and the same `git status --porcelain` (staged, unstaged and untracked
# changes), and neither the worktree's index nor the main repository's index is changed.
# Stub-suite throwaway trees only: about 10 s.
. "$(dirname "$0")/lib.sh"

body="$(vsp_sec 1 'echo "OK   s1 head=$(git rev-parse HEAD) dirty=$(git status --porcelain | wc -l | tr -d " ") gitdir=$(git rev-parse --git-dir)"')
$(vsp_sec 2 'echo "OK   s2 head=$(git rev-parse HEAD) dirty=$(git status --porcelain | wc -l | tr -d " ")"')"
m="$(vsp_tree main "$body")" || exit 99
wt="$VSP_ROOT/wt"
(cd "$m" && git -c user.name=t -c user.email=t@t -c commit.gpgsign=false commit -q --allow-empty -m second \
  && git worktree add -q --detach "$wt" HEAD~0 && git -c user.name=t -c user.email=t@t -c commit.gpgsign=false commit -q --allow-empty -m third) \
  > /dev/null 2>&1 || { echo "setup: worktree creation failed" >&2; exit 99; }
mkdir -p "$wt/tmp" "$wt/.claude/reviewed"
# Give the worktree a staged change, an unstaged change and an untracked file.
printf 'staged\n' > "$wt/staged.txt"; (cd "$wt" && git add staged.txt)
printf '\n# unstaged\n' >> "$wt/tests/lib/validate-quiet.sh"
printf 'untracked\n' > "$wt/untracked.txt"
want_head="$(git -C "$wt" rev-parse HEAD)"
main_head="$(git -C "$m" rev-parse HEAD)"
want_dirty="$(cd "$wt" && git status --porcelain | wc -l | tr -d ' ')"
idx_wt_before="$(git -C "$wt" ls-files -s | md5sum)"
idx_main_before="$(git -C "$m" ls-files -s | md5sum)"
vsp_assert W0 "fixture: worktree HEAD differs from main HEAD and the worktree is dirty" \
  "$([ "$want_head" != "$main_head" ] && [ "$want_dirty" -ge 3 ] && echo 0 || echo 1)"

vsp_run "$wt" -- --verbose
vsp_check W1 "default run from a linked worktree passes through the lane runner" 0 "== lanes: " "All checks passed."
vsp_check W2 "every lane sees the worktree's HEAD" 0 "s1 head=$want_head" "s2 head=$want_head" "!head=$main_head"
vsp_check W3 "every lane sees the worktree's working-tree state" 0 "s1 head=$want_head dirty=$want_dirty" "s2 head=$want_head dirty=$want_dirty"
vsp_assert W4 "the worktree's index is unchanged" "$([ "$(git -C "$wt" ls-files -s | md5sum)" = "$idx_wt_before" ] && echo 0 || echo 1)"
vsp_assert W5 "the main repository's index is unchanged" "$([ "$(git -C "$m" ls-files -s | md5sum)" = "$idx_main_before" ] && echo 0 || echo 1)"
case "$OUT" in *"gitdir=.git"*) vsp_assert W6 "each lane has a private .git directory" 0 ;;
  *) vsp_assert W6 "each lane has a private .git directory" 1 "$(printf '%s\n' "$OUT" | grep -o 'gitdir=[^ ]*' | head -n 1)" ;; esac

vsp_done
