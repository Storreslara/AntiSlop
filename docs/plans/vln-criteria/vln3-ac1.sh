#!/usr/bin/env bash
# vln3-ac1.sh: tests/reviewed-dir-leak-guard.test.sh keeps the nested run's
# output outside the sandbox, removes it on exit, and its header cites the
# vlg plan's "Note 2" (not "item 2"). Cases, each a stub tree run as the
# harness would (CLAUDE_PROJECT_DIR=T, TMPDIR=T/tmp):
#   wipe:  the stub removes its whole project dir, then prints the closing
#          summary. The guard FAILs for the removed directory only; it must
#          NOT report "did not finish" (the completion evidence survives).
#   list:  the stub records the sandbox's entries; the only one is .claude.
#   clean: after each run T/tmp is empty (the output file was removed too).
#   header: exactly one `# Note 2): ` header line and no `# item 2): ` line.
# Prints nothing and exits 0 on success.
. "$(cd "$(dirname "$0")" && pwd)/lib.sh"

t=$(gtree wipe 'rm -rf "$CLAUDE_PROJECT_DIR"
echo "All checks passed."')
runguard "$t"
expect wipe 1 'directory itself was removed' '!did not finish' '!(no output)'
tmpclean wipe "$t"

t=$(gtree list "ls -A \"\$CLAUDE_PROJECT_DIR\" > \"$VLN_ROOT/list.txt\"
echo \"All checks passed.\"")
runguard "$t"
expect list 0 'OK   no suite wrote'
[ "$(cat "$VLN_ROOT/list.txt")" = .claude ] || { echo "list: the sandbox holds: $(tr '\n' ' ' < "$VLN_ROOT/list.txt")"; exit 1; }
tmpclean list "$t"

g=tests/reviewed-dir-leak-guard.test.sh
[ "$(grep -c '^# Note 2): a writer that ignores CLAUDE_PROJECT_DIR and writes the marker$' "$g")" = 1 ] \
  || { echo "header: the Note 2 line is not present exactly once"; exit 1; }
[ "$(grep -c '^# item 2): ' "$g")" = 0 ] || { echo "header: an item 2 line is still present"; exit 1; }
exit 0
