#!/usr/bin/env bash
# vsp-2 AC2.2: the serial run (--serial) guards against .claude/reviewed/ leaks itself, with no
# nested validate.sh run: its sections see a sandbox CLAUDE_PROJECT_DIR, a section that writes
# into $CLAUDE_PROJECT_DIR/.claude/reviewed/ FAILs the run, and the caller's own project directory
# is left untouched. Stub-suite throwaway trees only: a few seconds.
. "$(dirname "$0")/lib.sh"

leak='mkdir -p "$CLAUDE_PROJECT_DIR/.claude/reviewed"; printf "PASS leak x\n" > "$CLAUDE_PROJECT_DIR/.claude/reviewed/leak.pass"; echo "OK   leaker"'
show='echo "OK   s1 cpd=$CLAUDE_PROJECT_DIR"'

t="$(vsp_tree leaky "$(vsp_sec 1 "$show")
$(vsp_sec 2 "$leak")")" || exit 99
before="$(find "$t/.claude/reviewed" -mindepth 1 -printf '%P\n' | sort)"

vsp_run "$t" -- --serial --verbose
vsp_check G1 "a leaking section FAILs the serial run" 1 "reviewed-dir leak" "leak.pass"
vsp_check G2 "serial sections see a sandbox CLAUDE_PROJECT_DIR, not the caller's" 1 "!cpd=$t"$'\n'
after="$(find "$t/.claude/reviewed" -mindepth 1 -printf '%P\n' | sort)"
vsp_assert G3 "the caller's .claude/reviewed/ is unchanged" "$([ "$before" = "$after" ] && echo 0 || echo 1)" "now: $(echo $after)"

vsp_run "$t" -- --serial
vsp_check G4 "quiet serial run also FAILs the leak" 1 "reviewed-dir leak"

c="$(vsp_tree clean "$(vsp_sec 1 "$show")
$(vsp_sec 2)")" || exit 99
vsp_run "$c" -- --serial --verbose
vsp_check G5 "a clean serial run passes" 0 "All checks passed." "!reviewed-dir leak: FAIL"

# The sandbox directory is removed after the run.
sb="$(printf '%s\n' "$OUT" | sed -nE 's/^OK   s1 cpd=(.*)$/\1/p' | head -n 1)"
vsp_assert G6 "the sandbox project dir is removed after the run (${sb:-none})" \
  "$([ -n "$sb" ] && [ "$sb" != "$c" ] && [ ! -e "$sb" ] && echo 0 || echo 1)"

vsp_done
