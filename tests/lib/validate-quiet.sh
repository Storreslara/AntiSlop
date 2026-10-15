# Sourced by tests/validate.sh (outer wrapper) and tests/validate-quiet.test.sh.
# validate_quiet_filter: reads the validate.sh stream on stdin, writes the quiet
# stream on stdout. Exclusion filter with a keep override (ptr-u1); both regexes
# are frozen by the plan docs/plans/2026-10-15-persona-token-reduction.md.
VALIDATE_QUIET_KEEP='^(FAIL|WARN|SKIP)|⚠|✗|not ok|FAILED|Error|ERROR'
VALIDATE_QUIET_DROP='^(OK |ok |Test |hint:|All .*(passed|pass)|\[master|\[detached| create mode| delete mode| [0-9]+ files? changed|editing .*budget|Switched to|Preparing worktree|HEAD is now|Initialized empty Git)|^[[:space:]]*✓|^[[:space:]]*$|^--( .* --)?$'

validate_quiet_filter() {
  VQ_KEEP="$VALIDATE_QUIET_KEEP" VQ_DROP="$VALIDATE_QUIET_DROP" awk '
    BEGIN { keep = ENVIRON["VQ_KEEP"]; drop = ENVIRON["VQ_DROP"]; hdr = ""; ctx = "" }
    /^== / { hdr = $0; ctx = ""; next }
    {
      if ($0 ~ keep) {
        if (hdr != "") { print hdr; hdr = "" }
        if (ctx != "") print ctx
        print
        ctx = ""
      } else if ($0 ~ drop) {
        ctx = ($0 ~ /^[[:space:]]*$/) ? "" : $0
      } else {
        if (hdr != "") { print hdr; hdr = "" }
        print
        ctx = ""
      }
    }'
}
