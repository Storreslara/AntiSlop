Unit: ptr-u9a

## Objective
`bin/ladder-tier.sh` prints exactly one line, `ladder-tier: <haiku|sonnet|opus|EXHAUSTED> n=<n> ladder=<a,b,...> reason=<word>`, and exits 0 (`--census`: one `<unit-id> `-prefixed line per `.fail` record); `bin/escalation-card.sh` prints a unit's FAIL history and commit subjects; `tests/ladder-tier.test.sh`, registered in `tests/validate.sh`, pins a frozen 23-case table. CHANGELOG records it; no version bump. The orchestrator prose is the next unit (ptr-u9b).

## Retrieval
GitHub issues: `gh issue view 559 --repo Storreslara/AntiSlop`. Siblings: `gh issue list --repo Storreslara/AntiSlop --label plan/persona-token-reduction`. Spec: `docs/plans/2026-10-15-persona-token-reduction.md`, section "Step U9".

## Affected files
- `bin/ladder-tier.sh` (anchor: new file)
- `bin/escalation-card.sh` (anchor: new file)
- `tests/ladder-tier.test.sh` (anchor: new file)
- `tests/validate.sh` (anchor: line matching `echo "== fail-marker-format-parity: heredoc vs marker-write.sh (Bash, item12-4) =="`)
- `CHANGELOG.md` (anchor: line matching `## [Unreleased]`)

## Ordered edits
1. command: `test ! -e bin/ladder-tier.sh && test ! -e bin/escalation-card.sh && test ! -e tests/ladder-tier.test.sh && test "$(node -p "require('./.claude-plugin/plugin.json').version")" = 0.31.178`
   expect: 0
2. file: `bin/ladder-tier.sh`
   anchor: new file (create it with the Write tool with exactly this content; any next edit of this file appends, its anchor is this payload's last line)
   indent: 3
   insert-after:
   ```
   #!/usr/bin/env bash
   # Implementer-tier ladder arithmetic (ptr-u9). Prints exactly one line and exits 0:
   #   ladder-tier: <haiku|sonnet|opus|EXHAUSTED> n=<n> ladder=<a,b,...> reason=<word>
   # Usage: bin/ladder-tier.sh <unit-id> [--contract <path>] [--project <dir>]
   #        bin/ladder-tier.sh --census [--project <dir>]
   # It never writes anything; the rulings ledger stays the orchestrator's job.
   #
   # The rules (agents/orchestrator.md, "Per-unit model routing", points here):
   # - Default tier: defaultImplementerModel from the project's persona config via one
   #   lone jq read. An absent key (or an absent file) resolves to the frontmatter
   #   `model:` of agents/lead-programmer.md; a present value outside haiku|sonnet|opus
   #   resolves to opus (the more capable tier); an unreadable config is fail-closed.
   # - Ladder: two entries per tier from the start tier upward. From haiku:
   #   haiku,haiku,sonnet,sonnet,opus,opus. From sonnet: sonnet,sonnet,opus,opus.
   #   From opus: opus,opus. Attempt n+1 runs on entry n+1 (0-based index n).
   # - n is the unit's FAIL-block count (bin/fail-count.sh's grep, same state-access lib).
   #   A PASS marker newer than the .fail record means n=0 (expiry, reason=expired).
   #   n >= the ladder length prints EXHAUSTED (ladder exhaustion).
   # - Haiku-default cutover: the timestamp on the "Haiku-default cutover:" line of
   #   agents/orchestrator.md, read from there and never duplicated. A unit with any FAIL
   #   block dated before it starts at the more capable of sonnet and the default tier
   #   (reason=pre-cutover).
   # - Contract-score guard: when the ladder starts at haiku and --contract is given, run
   #   `node bin/contract-guard.js <contract> --unit=<unit-id>`; unless its first line starts
   #   `contract-guard: haiku `, use the sonnet ladder (reason=guard-demotion). With no
   #   --contract, use the sonnet ladder (reason=no-contract).
   # - Any read error prints opus with reason=fail-closed (n=unknown).
   # - reason is the first that applies of: fail-closed, guard-demotion, no-contract,
   #   pre-cutover, expired, guard-pass, default.
   # - --census prints one line per existing .fail record, prefixed "<unit-id> ", with n the
   #   raw block count (no expiry) and no guard; it is how the real record set is audited.
   set -uo pipefail

   script_dir="$(cd "$(dirname "$0")" && pwd)"
   repo_root="$(cd "$script_dir/.." && pwd)"

   unit=""
   contract=""
   project="."
   census=0
   while [ $# -gt 0 ]; do
     case "$1" in
       --census) census=1; shift ;;
       --contract) contract="${2:-}"; shift 2 || break ;;
       --project) project="${2:-.}"; shift 2 || break ;;
       *) unit="$1"; shift ;;
     esac
   done

   dot="${project}/.claude"
   . "$repo_root/hooks/scripts/lib/state-access.sh"
   set +e

   ladder_of() {
     case "$1" in
       haiku) echo "haiku,haiku,sonnet,sonnet,opus,opus" ;;
       sonnet) echo "sonnet,sonnet,opus,opus" ;;
       *) echo "opus,opus" ;;
     esac
   }

   emit() { printf 'ladder-tier: %s n=%s ladder=%s reason=%s\n' "$1" "$2" "$3" "$4"; }
   closed() { emit opus unknown opus fail-closed; }

   # Default tier: one lone jq read of the config, else the lead-programmer frontmatter model.
   resolve_default() {
     local cfg="${project}/.claude/persona-config.json" v
     if [ -f "$cfg" ]; then
       v="$(jq -r '.defaultImplementerModel // empty' "$cfg" 2>/dev/null)" || return 1
   ```
3. file: `bin/ladder-tier.sh`
   anchor: line matching `    v="$(jq -r '.defaultImplementerModel // empty' "$cfg" 2>/dev/null)" || return 1`
   indent: 3
   insert-after:
   ```
     else
       v=""
     fi
     if [ -z "$v" ]; then
       v="$(sed -n '1,/^---$/{s/^model: *//p}' "$repo_root/agents/lead-programmer.md" | head -1)"
       [ -n "$v" ] || return 1
     fi
     case "$v" in
       haiku|sonnet|opus) echo "$v" ;;
       *) echo opus ;;
     esac
   }

   cutover_ts() {
     sed -n 's/.*\*\*Haiku-default cutover: \([0-9TZ:-]*\)\.\*\*.*/\1/p' "$repo_root/agents/orchestrator.md" | head -1
   }

   # compute <unit> <census 0|1> <contract> -> prints the one line
   compute() {
     local id="$1" raw="$2" ctr="$3" marker pass n=0 default cut start ladder reason ts pre=0 expired=0 g
     default="$(resolve_default)" || { closed; return; }
     cut="$(cutover_ts)"
     [ -n "$cut" ] || { closed; return; }
     marker="$(unit_id_marker_path "$id" fail)"
     if [ -f "$marker" ]; then
       n="$(grep -cE "^FAIL ${id} " "$marker")" || n=0
       [ "$n" -gt 0 ] 2>/dev/null || { closed; return; }
       pass="$(unit_id_marker_path "$id" pass)"
       if [ "$raw" = 0 ] && [ -f "$pass" ] && [ "$pass" -nt "$marker" ]; then
         n=0; expired=1
       else
         while read -r ts; do
           [ -n "$ts" ] && [[ "$ts" < "$cut" ]] && pre=1
         done < <(grep -E "^FAIL ${id} " "$marker" | awk '{print $3}')
       fi
     fi
     start="$default"
     reason=default
     if [ "$pre" = 1 ]; then
       [ "$start" = haiku ] && start=sonnet
       reason=pre-cutover
     elif [ "$expired" = 1 ]; then
       reason=expired
     fi
     if [ "$start" = haiku ] && [ "$raw" = 0 ]; then
       if [ -z "$ctr" ]; then
         start=sonnet; reason=no-contract
       else
         g="$(node "$repo_root/bin/contract-guard.js" "$ctr" --unit="$id" 2>/dev/null | head -1)"
         case "$g" in
           "contract-guard: haiku "*) [ "$reason" = default ] && reason=guard-pass ;;
           *) start=sonnet; reason=guard-demotion ;;
         esac
       fi
     fi
     ladder="$(ladder_of "$start")"
     IFS=, read -ra arr <<< "$ladder"
     if [ "$n" -ge "${#arr[@]}" ]; then
       emit EXHAUSTED "$n" "$ladder" "$reason"
     else
       emit "${arr[$n]}" "$n" "$ladder" "$reason"
     fi
   }

   if [ "$census" = 1 ]; then
     for f in "$dot"/reviewed/*.fail; do
       [ -f "$f" ] || continue
       id="$(basename "$f" .fail)"
       printf '%s ' "$id"
       compute "$id" 1 ""
   ```
4. file: `bin/ladder-tier.sh`
   anchor: line matching `    compute "$id" 1 ""`
   indent: 3
   insert-after:
   ```
     done
     exit 0
   fi

   if [ -z "$unit" ] || ! unit_id_valid "$unit"; then
     closed
     exit 0
   fi
   compute "$unit" 0 "$contract"
   exit 0
   ```
5. file: `bin/escalation-card.sh`
   anchor: new file (create it with the Write tool with exactly this content)
   indent: 3
   insert-after:
   ```
   #!/usr/bin/env bash
   # Defect history for "At the 2-FAIL cap" (ptr-u9). Usage: bin/escalation-card.sh <unit-id> [project-dir]
   # Per FAIL block: header, tier line, first defect line; then commit subjects carrying
   # (<unit-id>). It never prints the options (they stay in agents/orchestrator.md), writes
   # nothing and exits 0.
   set -uo pipefail

   script_dir="$(cd "$(dirname "$0")" && pwd)"
   repo_root="$(cd "$script_dir/.." && pwd)"

   unit="${1:-}"
   project_dir="${2:-.}"
   dot="${project_dir}/.claude"

   . "$repo_root/hooks/scripts/lib/state-access.sh"
   set +e

   if [ -z "$unit" ] || ! unit_id_valid "$unit"; then
     echo "escalation-card: no valid unit id"
     exit 0
   fi

   marker="$(unit_id_marker_path "$unit" fail)"
   echo "escalation-card: $unit"
   if [ -f "$marker" ]; then
     awk -v id="$unit" '
       $0 ~ "^FAIL " id " " { print; state = 1; next }
       state == 1 && /^tier: / { print; state = 2; next }
       state >= 1 && NF > 0 { print "  " $0; state = 0 }
     ' "$marker"
   else
     echo "(no FAIL record)"
   fi
   echo "fix-attempt commits:"
   (cd "$project_dir" && git log --format='%h %s' --grep="($unit)" 2>/dev/null) | head -40
   exit 0
   ```
6. file: `tests/ladder-tier.test.sh`
   anchor: new file (create it with the Write tool with exactly this content; any next edit of this file appends, its anchor is this payload's last line)
   indent: 3
   insert-after:
   ```
   #!/usr/bin/env bash
   # Suite for bin/ladder-tier.sh and bin/escalation-card.sh (ptr-u9a). The branch table is
   # frozen (every expected line is literal); fixture projects are built in a temp dir.
   set -uo pipefail
   cd "$(dirname "$0")/.."
   repo="$(pwd)"
   tier="$repo/bin/ladder-tier.sh"
   card="$repo/bin/escalation-card.sh"
   fail=0

   pass() { echo "OK   $*"; }
   bad()  { echo "FAIL $*"; fail=1; }

   tmproot="$(mktemp -d)"
   trap 'rm -rf "$tmproot"' EXIT

   PASSC="$repo/tests/fixtures/contract-score/v2-all-pass.md"   # Unit: demo-2, scores haiku 7/7
   FAILC="$repo/tests/fixtures/contract-score/minus-R3.md"      # Unit: demo-1, scores below 7/7
   PRE=2026-10-01T00:00:00Z    # before the Haiku-default cutover 2026-10-08T17:28:48Z
   POST=2026-10-20T00:00:00Z   # after it
   LADDER_H=haiku,haiku,sonnet,sonnet,opus,opus
   LADDER_S=sonnet,sonnet,opus,opus
   LADDER_O=opus,opus

   # mkproj <default tier | ABSENT | NOKEY | BADJSON> -> prints a fresh project dir
   mkproj() {
     local p
     p="$(mktemp -d -p "$tmproot")"
     mkdir -p "$p/.claude/reviewed"
     case "$1" in
       ABSENT) ;;
       NOKEY) printf '{"reviewGating":{"mode":"enforce"}}\n' > "$p/.claude/persona-config.json" ;;
       BADJSON) printf '{ not json\n' > "$p/.claude/persona-config.json" ;;
       *) printf '{"defaultImplementerModel":"%s"}\n' "$1" > "$p/.claude/persona-config.json" ;;
     esac
     echo "$p"
   }
   # addfail <proj> <unit> <count> <timestamp>
   addfail() {
     local i
     for ((i = 0; i < $3; i++)); do
       printf 'FAIL %s %s\ntier: haiku\n- defect %s\n\n' "$2" "$4" "$i" >> "$1/.claude/reviewed/$2.fail"
     done
   }
   # check <label> <expected line> <proj> <unit> [extra args]
   check() {
     local label="$1" want="$2" p="$3" u="$4" got
     shift 4
     got="$(bash "$tier" "$u" --project "$p" "$@")"
     if [ "$got" = "$want" ]; then pass "$label"; else bad "$label: expected [$want], got [$got]"; fi
   }

   echo "-- default tier x n (guard pass for haiku) -----------------------------------"
   p="$(mkproj haiku)"
   check "haiku n=0 guard pass" "ladder-tier: haiku n=0 ladder=$LADDER_H reason=guard-pass" "$p" demo-2 --contract "$PASSC"
   p="$(mkproj haiku)"; addfail "$p" demo-2 1 "$POST"
   check "haiku n=1 guard pass" "ladder-tier: haiku n=1 ladder=$LADDER_H reason=guard-pass" "$p" demo-2 --contract "$PASSC"
   p="$(mkproj haiku)"; addfail "$p" demo-2 2 "$POST"
   check "haiku n=2 guard pass" "ladder-tier: sonnet n=2 ladder=$LADDER_H reason=guard-pass" "$p" demo-2 --contract "$PASSC"
   p="$(mkproj haiku)"; addfail "$p" demo-2 4 "$POST"
   check "haiku n=4 guard pass" "ladder-tier: opus n=4 ladder=$LADDER_H reason=guard-pass" "$p" demo-2 --contract "$PASSC"
   p="$(mkproj haiku)"; addfail "$p" demo-2 6 "$POST"
   check "haiku n=6 guard pass is exhausted" "ladder-tier: EXHAUSTED n=6 ladder=$LADDER_H reason=guard-pass" "$p" demo-2 --contract "$PASSC"
   p="$(mkproj sonnet)"
   check "sonnet n=0" "ladder-tier: sonnet n=0 ladder=$LADDER_S reason=default" "$p" u1
   p="$(mkproj sonnet)"; addfail "$p" u1 2 "$POST"
   check "sonnet n=2" "ladder-tier: opus n=2 ladder=$LADDER_S reason=default" "$p" u1
   p="$(mkproj sonnet)"; addfail "$p" u1 4 "$POST"
   check "sonnet n=4 is exhausted" "ladder-tier: EXHAUSTED n=4 ladder=$LADDER_S reason=default" "$p" u1
   ```
7. file: `tests/ladder-tier.test.sh`
   anchor: line matching `check "sonnet n=4 is exhausted" "ladder-tier: EXHAUSTED n=4 ladder=$LADDER_S reason=default" "$p" u1`
   indent: 3
   insert-after:
   ```
   p="$(mkproj opus)"
   check "opus n=0" "ladder-tier: opus n=0 ladder=$LADDER_O reason=default" "$p" u1
   p="$(mkproj opus)"; addfail "$p" u1 1 "$POST"
   check "opus n=1" "ladder-tier: opus n=1 ladder=$LADDER_O reason=default" "$p" u1
   p="$(mkproj opus)"; addfail "$p" u1 2 "$POST"
   check "opus n=2 is exhausted" "ladder-tier: EXHAUSTED n=2 ladder=$LADDER_O reason=default" "$p" u1
   p="$(mkproj bogus)"
   check "bogus default n=0 resolves to opus" "ladder-tier: opus n=0 ladder=$LADDER_O reason=default" "$p" u1
   p="$(mkproj bogus)"; addfail "$p" u1 2 "$POST"
   check "bogus default n=2 is exhausted" "ladder-tier: EXHAUSTED n=2 ladder=$LADDER_O reason=default" "$p" u1

   echo "-- absent default resolves to the lead-programmer frontmatter model --------------"
   fm="$(sed -n '1,/^---$/{s/^model: *//p}' "$repo/agents/lead-programmer.md" | head -1)"
   if [ "$fm" = "haiku" ]; then pass "lead-programmer frontmatter model is haiku"; else bad "lead-programmer frontmatter model is [$fm], this table assumes haiku"; fi
   p="$(mkproj ABSENT)"
   check "absent config file, guard pass" "ladder-tier: haiku n=0 ladder=$LADDER_H reason=guard-pass" "$p" demo-2 --contract "$PASSC"
   p="$(mkproj NOKEY)"
   check "config without the key, guard pass" "ladder-tier: haiku n=0 ladder=$LADDER_H reason=guard-pass" "$p" demo-2 --contract "$PASSC"

   echo "-- pre-cutover block, expiry, guard demotion, no contract, unreadable --------------"
   p="$(mkproj haiku)"; addfail "$p" demo-2 1 "$PRE"
   check "pre-cutover block, haiku default" "ladder-tier: sonnet n=1 ladder=$LADDER_S reason=pre-cutover" "$p" demo-2 --contract "$PASSC"
   p="$(mkproj sonnet)"; addfail "$p" u1 2 "$PRE"
   check "pre-cutover block, sonnet default" "ladder-tier: opus n=2 ladder=$LADDER_S reason=pre-cutover" "$p" u1
   p="$(mkproj opus)"; addfail "$p" u1 1 "$PRE"
   check "pre-cutover block, opus default keeps the opus ladder" "ladder-tier: opus n=1 ladder=$LADDER_O reason=pre-cutover" "$p" u1
   p="$(mkproj haiku)"; addfail "$p" demo-2 2 "$POST"
   touch -t 202601010000 "$p/.claude/reviewed/demo-2.fail"
   printf 'PASS demo-2 2026-01-02T00:00:00Z commit: none criteria: x\n' > "$p/.claude/reviewed/demo-2.pass"
   touch -t 202601020000 "$p/.claude/reviewed/demo-2.pass"
   check "expired record (newer PASS marker) counts as n=0" "ladder-tier: haiku n=0 ladder=$LADDER_H reason=expired" "$p" demo-2 --contract "$PASSC"
   p="$(mkproj haiku)"
   check "guard demotion" "ladder-tier: sonnet n=0 ladder=$LADDER_S reason=guard-demotion" "$p" demo-1 --contract "$FAILC"
   p="$(mkproj haiku)"
   check "no contract fails toward the sonnet ladder" "ladder-tier: sonnet n=0 ladder=$LADDER_S reason=no-contract" "$p" demo-2
   p="$(mkproj haiku)"; printf 'not a fail header\n' > "$p/.claude/reviewed/demo-2.fail"
   check "unreadable count (record with no FAIL header) is fail-closed" "ladder-tier: opus n=unknown ladder=opus reason=fail-closed" "$p" demo-2 --contract "$PASSC"
   p="$(mkproj BADJSON)"
   check "unreadable config is fail-closed" "ladder-tier: opus n=unknown ladder=opus reason=fail-closed" "$p" demo-2 --contract "$PASSC"

   echo "-- the script writes nothing ---------------------------------------------------"
   p="$(mkproj haiku)"; addfail "$p" demo-2 1 "$POST"
   before="$(find "$p" -type f | sort | xargs md5sum | md5sum)"
   bash "$tier" demo-2 --project "$p" --contract "$PASSC" > /dev/null
   bash "$tier" --census --project "$p" > /dev/null
   after="$(find "$p" -type f | sort | xargs md5sum | md5sum)"
   if [ "$before" = "$after" ]; then pass "ladder-tier.sh leaves the project tree unchanged"; else bad "ladder-tier.sh changed the project tree"; fi

   echo "-- census over a synthetic record set ------------------------------------------"
   p="$(mkproj haiku)"; addfail "$p" ca 1 "$POST"; addfail "$p" cb 2 "$PRE"
   got="$(bash "$tier" --census --project "$p")"
   want="ca ladder-tier: haiku n=1 ladder=$LADDER_H reason=default
   cb ladder-tier: opus n=2 ladder=$LADDER_S reason=pre-cutover"
   if [ "$got" = "$want" ]; then pass "census prints one prefixed line per record"; else bad "census: expected [$want], got [$got]"; fi

   echo "-- census over the real record set (n equals bin/fail-count.sh) ----------------"
   real="$tmproot/census.out"
   bash "$tier" --census --project . > "$real"
   set -- .claude/reviewed/*.fail
   if [ -f "$1" ]; then want_lines=$#; else want_lines=0; fi
   got_lines="$(wc -l < "$real" | tr -d ' ')"
   if [ "$got_lines" = "$want_lines" ]; then pass "census prints $got_lines lines, one per .fail record"; else bad "census prints $got_lines lines, $want_lines .fail records exist"; fi
   mismatch=0
   while read -r id _ _ nfield _; do
     want_n="n=$(bash "$repo/bin/fail-count.sh" "$id")"
     [ "$nfield" = "$want_n" ] || { echo "     $id: census $nfield, fail-count $want_n"; mismatch=1; }
   done < "$real"
   if [ "$mismatch" = 0 ]; then pass "every census n= equals bin/fail-count.sh"; else bad "a census n= differs from bin/fail-count.sh"; fi
   ```
8. file: `tests/ladder-tier.test.sh`
   anchor: line matching `if [ "$mismatch" = 0 ]; then pass "every census n= equals bin/fail-count.sh"; else bad "a census n= differs from bin/fail-count.sh"; fi`
   indent: 3
   insert-after:
   ```
   if /usr/bin/grep -q 'reason=fail-closed' "$real"; then bad "a census line has reason=fail-closed"; else pass "no census line has reason=fail-closed"; fi

   echo "-- escalation-card.sh ----------------------------------------------------------"
   p="$(mkproj haiku)"
   printf 'FAIL ec1 2026-10-20T00:00:00Z\ntier: haiku\n- first defect one\n- second defect one\n\nFAIL ec1 2026-10-20T01:00:00Z\ntier: sonnet\n- first defect two\n\n' > "$p/.claude/reviewed/ec1.fail"
   got="$(bash "$card" ec1 "$p")"
   if printf '%s\n' "$got" | /usr/bin/grep -qx 'FAIL ec1 2026-10-20T01:00:00Z' \
      && printf '%s\n' "$got" | /usr/bin/grep -qx 'tier: sonnet' \
      && printf '%s\n' "$got" | /usr/bin/grep -qF -- '- first defect two' \
      && ! printf '%s\n' "$got" | /usr/bin/grep -qF -- 'second defect one'; then
     pass "card prints each block's header, tier line and first defect line only"
   else
     bad "card block lines wrong: [$got]"
   fi
   if printf '%s\n' "$got" | /usr/bin/grep -qiE 'debug spec|park the unit|re-dispatch with'; then bad "card prints the options"; else pass "card never prints the options"; fi
   got="$(bash "$card" ptr-u8 "$p")"
   if printf '%s\n' "$got" | /usr/bin/grep -qF '(no FAIL record)'; then pass "card reports a unit with no FAIL record"; else bad "card no-record line missing: [$got]"; fi
   got="$(bash "$card" ptr-u8 .)"
   if printf '%s\n' "$got" | /usr/bin/grep -qE '^[0-9a-f]+ .*\(ptr-u8\)'; then pass "card lists a commit subject carrying (ptr-u8)"; else bad "card lists no (ptr-u8) commit: [$got]"; fi

   if [ "$fail" -eq 0 ]; then
     echo
     echo "All ladder-tier checks passed."
   fi
   exit "$fail"
   ```
9. command: `chmod +x bin/ladder-tier.sh bin/escalation-card.sh tests/ladder-tier.test.sh`
   expect: 0
10. file: `tests/validate.sh`
   anchor: line matching `echo "== fail-marker-format-parity: heredoc vs marker-write.sh (Bash, item12-4) =="`
   indent: 3
   before:
   ```
   echo
   echo "== fail-marker-format-parity: heredoc vs marker-write.sh (Bash, item12-4) =="
   ```
   after:
   ```
   echo
   echo "== ladder-tier: ladder arithmetic and escalation card (Bash, ptr-u9a) =="
   if bash tests/ladder-tier.test.sh; then
     echo "OK   tests/ladder-tier.test.sh"
   else
     echo "FAIL tests/ladder-tier.test.sh"
     fail=1
   fi

   echo
   echo "== fail-marker-format-parity: heredoc vs marker-write.sh (Bash, item12-4) =="
   ```
11. file: `CHANGELOG.md`
   anchor: line matching `## [Unreleased]`
   indent: 3
   insert-after:
   ```

   **Ladder-tier and escalation-card scripts (ptr-u9a).** `bin/ladder-tier.sh <unit-id> [--contract <path>] [--project <dir>]` prints the next attempt's implementer tier as one line (`ladder-tier: <tier> n=<n> ladder=<a,b,...> reason=<word>`), from the default tier, the FAIL-block count, the Haiku-default cutover read from `agents/orchestrator.md`, the Contract-score guard and the expiry rule, and fails closed to `opus`; `--census` prints one line per `.fail` record. `bin/escalation-card.sh <unit-id>` prints the FAIL history and fix-attempt commit subjects for the 2-FAIL cap step. `tests/ladder-tier.test.sh` (registered in `tests/validate.sh`) pins a frozen branch table over synthetic marker directories. Neither script writes. No version bump.
   ```
12. command: `git add bin/ladder-tier.sh bin/escalation-card.sh tests/ladder-tier.test.sh tests/validate.sh CHANGELOG.md && git commit -m "feat(ptr-u9a): ladder-tier and escalation-card scripts with a frozen branch table (#559)" -m "Co-Authored-By: Claude Sonnet 5.5 <noreply@anthropic.com>"`
   expect: 0

## Do NOT touch
- `agents/` and `.claude/` (the orchestrator prose and the mirrors are ptr-u9b)
- `hooks/` (`hooks/scripts/lib/state-access.sh` is only sourced), `bin/fail-count.sh`, `bin/contract-guard.js` and `bin/cli.js`
- `tests/fixtures/` (the test reuses the contract-score fixtures `v2-all-pass.md` and `minus-R3.md`)
- `.claude-plugin/plugin.json`, `package.json`, `CONTEXT.md`, `docs/harness-glossary.md` and `docs/adr/`

## Acceptance criteria
1. run: `bash tests/ladder-tier.test.sh > /dev/null`
   exit: 0
   stdout: empty
   mutation: skip edit 2; the suite fails, exit 1.
2. run: `bash tests/ladder-tier.test.sh | tail -1`
   exit: 0
   stdout: `All ladder-tier checks passed.`
   mutation: skip edit 8; the last line differs.
3. run: `W=$(mktemp -d)/wt; git worktree add --detach "$W" HEAD >/dev/null 2>&1 && (cd "$W" && sed -i 's/-ge "${#arr\[@\]}"/-gt "${#arr[@]}"/' bin/ladder-tier.sh && bash tests/ladder-tier.test.sh >/dev/null 2>&1; echo "rc=$?"); git worktree remove --force "$W"`
   exit: 0
   stdout: `rc=1`
   mutation: the run is the mutation: `-ge` becomes `-gt` in a throwaway worktree of HEAD and the suite exits 1.
   proof: scratch run printed rc=1 mutated, rc=0 unmutated.
4. run: `test "$(/usr/bin/grep -c '^check "' tests/ladder-tier.test.sh)" -ge 14 && echo table-ok`
   exit: 0
   stdout: `table-ok`
   mutation: skip edit 6; nothing prints, exit 1.
5. run: `bash tests/ladder-tier.test.sh | /usr/bin/grep -cE '^OK   (every census n= equals bin/fail-count.sh|no census line has reason=fail-closed)$'`
   exit: 0
   stdout: `2`
   mutation: change the census call `compute "$id" 1 ""` to `compute "$id" 0 ""`; expiry zeroes n= of expired records and the count is 1.
   proof: scratch run of the mutated script over the real records printed n=0 where bin/fail-count.sh counts 1 or more.
6. run: `/usr/bin/grep -c 'bash tests/ladder-tier.test.sh' tests/validate.sh`
   exit: 0
   stdout: `1`
   mutation: skip edit 10; stdout `0`, exit 1.
7. run: `bash bin/ladder-tier.sh no-such-unit-xyz | /usr/bin/grep -cE '^ladder-tier: (haiku|sonnet|opus|EXHAUSTED) n=[0-9a-z]+ ladder=[a-z,]+ reason=[a-z-]+$'`
   exit: 0
   stdout: `1`
   mutation: skip edit 2; stdout `0`, exit 1.
8. run: `/usr/bin/grep -c '2026-10-08' bin/ladder-tier.sh`
   exit: 1
   stdout: `0`
   mutation: put the cutover timestamp in a comment of bin/ladder-tier.sh; stdout `1`.
   proof: scratch run printed 0 on the finished script, 1 with the timestamp added.
9. run: `bash bin/escalation-card.sh ptr-u8 . | /usr/bin/grep -qE '^[0-9a-f]+ .*\(ptr-u8\)' && echo card-lists-commits`
   exit: 0
   stdout: `card-lists-commits`
   mutation: skip edit 5; nothing prints, exit 1.
10. run: `bash bin/escalation-card.sh ptr-u8 . | /usr/bin/grep -ciE 'debug spec|park the unit|human directive'`
   exit: 1
   stdout: `0`
   mutation: add `echo "(a) Debug spec"` to bin/escalation-card.sh; stdout `1`.
   proof: scratch run printed 0 on the finished card, 1 with the echo added.
11. run: `test -x bin/ladder-tier.sh && test -x bin/escalation-card.sh && test -x tests/ladder-tier.test.sh && test "$(git check-ignore bin/ladder-tier.sh bin/escalation-card.sh tests/ladder-tier.test.sh | wc -l)" = 0 && echo files-ok`
   exit: 0
   stdout: `files-ok`
   mutation: skip edit 9; nothing prints, exit 1.
12. run: `L=$(git log --format='%H %s' | grep -E '^[0-9a-f]+ [a-z]+\(ptr-u9a\): ' | cut -d' ' -f1); test -n "$L" || { echo no-unit-commit; exit 3; }; for c in $L; do git diff --name-only "$c~1..$c" | LC_ALL=C sort | paste -sd' '; done`
   exit: 0
   stdout: `CHANGELOG.md bin/escalation-card.sh bin/ladder-tier.sh tests/ladder-tier.test.sh tests/validate.sh`
   mutation: also stage `agents/orchestrator.md`; the list gains that path.
   proof: scratch replay printed exactly that list.
13. run: `L=$(git log --format='%H %s' | grep -E '^[0-9a-f]+ [a-z]+\(ptr-u9a\): ' | cut -d' ' -f1); test -n "$L" || { echo no-unit-commit; exit 3; }; for c in $L; do git log -1 --format=%B "$c" | grep -c "^Co-Authored-By: Claude .* <noreply@anthropic.com>$"; done`
   exit: 0
   stdout: `1`
   mutation: omit the second -m of command 12; stdout `0`, exit 1.
   proof: scratch replay printed 1.
14. run: `L=$(git log --format='%H %s' | grep -E '^[0-9a-f]+ [a-z]+\(ptr-u9a\): ' | cut -d' ' -f1); test -n "$L" || { echo no-unit-commit; exit 3; }; E=$(echo "$L" | head -1); git log --format=%s "$E..HEAD" -- bin/ladder-tier.sh bin/escalation-card.sh tests/ladder-tier.test.sh | grep -vcE '^[a-z]+\(ptr-u9a\): '`
   exit: 1
   stdout: `0`
   mutation: add a later commit `fix: x` touching bin/ladder-tier.sh; stdout `1`.
   proof: scratch replay printed 0.
15. run: `L=$(git log --format='%H %s' | grep -E '^[0-9a-f]+ [a-z]+\(ptr-u9a\): ' | cut -d' ' -f1); test -n "$L" || { echo no-unit-commit; exit 3; }; for c in $L; do git diff --name-only "$c~1..$c" | grep -cE '^[.]claude/'; done`
   exit: 1
   stdout: `0`
   mutation: stage a .claude path in the commit; stdout `1`.
   proof: scratch replay printed 0.
16. run: `git status --porcelain --untracked-files=no | wc -l`
   exit: 0
   stdout: `0`
   mutation: leave a changed file unstaged; stdout is non-zero.
   proof: scratch replay printed 0.
17. run: `bash tests/validate-lanes.sh --lanes 4`
   exit: 0
   stdout: `All checks passed.`
   mutation: make the `-ge` comparison `-gt`; the ladder-tier section prints FAIL, exit 1.
   proof: scratch replay of the chain printed All checks passed.

## Pre-resolved context
tdd: yes tests/ladder-tier.test.sh
blast-radius: bin/fail-count.sh:1 hooks/scripts/lib/state-access.sh:1 bin/contract-guard.js:1 agents/orchestrator.md:520 agents/lead-programmer.md:4 tests/validate.sh:709 (grep-derived, no graph run; every file is read, none is edited except tests/validate.sh and CHANGELOG.md)
file-tools: create the three new files with the Write tool and use the Edit tool for the rest. Their text names the marker directory and the persona config, which hooks refuse in Bash text: if a Write or Edit is rejected or a hook refuses a command, STOP and report the refusal text; never route around it.
gate-run: criterion 17 runs the lanes gate in the foreground (about 2-3 minutes; 600000 ms timeout; never background it; it refuses a linked worktree). If it fails only in tests/rollout-preflight.test.sh (AC14/W9) or tests/microworld/dashboard-decision-run.test.js (Test 5), both timing-flaky and unrelated, rerun that test alone and the lanes once more, and report both runs.
payload-indent: strip exactly 3 leading spaces from each non-empty payload line (empty lines stay empty).
commit-message: feat(ptr-u9a): ladder-tier and escalation-card scripts with a frozen branch table (#559)
Co-Authored-By: Claude Sonnet 5.5 <noreply@anthropic.com>
review-packet:
~~~
unit: ptr-u9a (#559)
changed files: <FILL: changed files>
commit: <FILL: commit SHA>
criterion 1: <FILL: exit and stdout>
criterion 2: <FILL: exit and stdout>
criterion 3: <FILL: exit and stdout>
criterion 4: <FILL: exit and stdout>
criterion 5: <FILL: exit and stdout>
criterion 6: <FILL: exit and stdout>
criterion 7: <FILL: exit and stdout>
criterion 8: <FILL: exit and stdout>
criterion 9: <FILL: exit and stdout>
criterion 10: <FILL: exit and stdout>
criterion 11: <FILL: exit and stdout>
criterion 12: <FILL: exit and stdout>
criterion 13: <FILL: exit and stdout>
criterion 14: <FILL: exit and stdout>
criterion 15: <FILL: exit and stdout>
criterion 16: <FILL: exit and stdout>
criterion 17: <FILL: exit and stdout>
~~~
diagnosis: none

## Escalation
If any instruction cannot be followed exactly as written, STOP and report a spec gap; do not improvise.
