#!/usr/bin/env bash
# Gate G1 labeling server: server suite, real-browser probe and the README docs case.
cd "$(dirname "$0")/.." || exit 1
ROOT="$PWD"
RR=eval/refutation-replay
export PYTHONDONTWRITEBYTECODE=1
fails=0
ok() { echo "ok - $*"; }
bad() { echo "FAIL - $*"; fails=$((fails + 1)); }

T="$(mktemp -d)"
PIDS=""
cleanup() {
  for p in $PIDS; do kill -TERM "$p" 2>/dev/null; done
  for p in $PIDS; do wait "$p" 2>/dev/null; done
  rm -rf "$T"
}
trap cleanup EXIT

snap() { find "$RR" -type f -print0 2>/dev/null | sort -z | xargs -0 -r sha256sum; }
snap > "$T/before.snap"

# server suite
python3 tests/refutation-label-server.py > "$T/server.out" 2>&1
grep -E '^(ok|FAIL) - ' "$T/server.out"
grep -qE '^FAIL - ' "$T/server.out" && fails=$((fails + $(grep -cE '^FAIL - ' "$T/server.out")))
[ "$(grep -cE '^(ok|FAIL) - S' "$T/server.out")" -eq 16 ] || bad "S00 server suite reported $(grep -cE '^(ok|FAIL) - S' "$T/server.out") of 16 cases"

# browser fixtures: the tall corpus (24 rows, every card has a diff) and an empty corpus
mkdir -p "$T/tall" "$T/empty"
python3 tests/refutation-label-server.py fixture "$T/tall" tall && python3 tests/refutation-label-server.py fixture "$T/empty" empty || bad "S00 browser fixtures were not built"

start() { # <dir> <outfile>
  python3 "$RR/label.py" serve --no-open --port 0 --corpus "$1/corpus.jsonl" --labels "$1/labels.tsv" --repo "$1/repo" --log "$1/writes.log" > "$2" 2>&1 &
  PIDS="$PIDS $!"
  for _ in $(seq 50); do grep -q '^label: http://' "$2" && break; sleep 0.2; done
  sed -n 's/^label: \(http:[^ ]*\)$/\1/p' "$2" | head -1
}
URL="$(start "$T/tall" "$T/tall.out")"
EURL="$(start "$T/empty" "$T/empty.out")"

# playwright and Chromium are searched, never installed
BR=""
if [ -z "${LABEL_UI_NO_BROWSER_SEARCH:-}" ] && command -v node >/dev/null 2>&1 && [ -n "$URL" ] && [ -n "$EURL" ]; then
  for c in "${PLAYWRIGHT_PATH:-}" "$ROOT/node_modules/playwright-core" "$ROOT/node_modules/playwright" \
           "$HOME"/miniforge3/envs/*/lib/python3*/site-packages/playwright/driver/package \
           "$HOME"/.local/lib/python3*/site-packages/playwright/driver/package /usr/lib/python3/dist-packages/playwright/driver/package; do
    [ -n "$c" ] && [ -f "$c/package.json" ] || continue
    timeout 540 node tests/refutation-label-browser.js "$c" "$URL" "$T/tall/labels.tsv" "$T/tall/writes.log" "$EURL" > "$T/br.out" 2> "$T/br.err"
    [ $? -ne 3 ] && { BR="$c"; break; }
  done
fi
if [ -n "$BR" ]; then
  n=0
  while IFS= read -r line; do
    case "$line" in
      B[0-9][0-9]*=PASS) n=$((n + 1)); ok "${line%=PASS}" ;;
      B[0-9][0-9]*=FAIL*) n=$((n + 1)); bad "${line%%=FAIL*}: ${line#*=FAIL }" ;;
      *) bad "B00 unexpected probe output: $line" ;;
    esac
  done < "$T/br.out"
  [ "$n" -eq 14 ] || { bad "B00 probe reported $n of 14 cases"; head -3 "$T/br.err"; }
elif [ -n "${LABEL_UI_REQUIRE_BROWSER:-}" ]; then
  bad "B00 LABEL_UI_REQUIRE_BROWSER is set but no playwright plus Chromium launched (set PLAYWRIGHT_PATH or CHROMIUM_PATH)"
else
  echo "SKIP !!! no playwright plus Chromium found: ALL real-browser checks were skipped, so this run proves nothing about them !!!"
fi

# D01: the README's label.py serve options exist, and it never mentions the retired page generator
step1="$(awk '/^## Gate G/{g=1} g&&/^1\. /{p=1} g&&/^2\. /{exit} p' "$RR/README.md")"
help="$(python3 "$RR/label.py" serve --help 2>&1)"
OLD="label""-ui"
miss=0
for f in $(printf '%s\n' "$step1" | grep -oE 'label\.py serve[^`]*' | grep -oE -- '--[a-z][a-z-]*' | sort -u); do
  printf '%s' "$help" | grep -qF -- "$f" || miss=$((miss + 1))
done
if printf '%s' "$step1" | grep -qF '`python3 eval/refutation-replay/label.py serve`' && [ "$miss" -eq 0 ] && ! grep -qF "$OLD" "$RR/README.md"; then
  ok "D01 README step 1 options exist in serve --help, no retired generator mention"
else
  bad "D01 README step 1 empty=$([ -z "$step1" ] && echo yes || echo no) missing-options=$miss retired-name-hits=$(grep -cF "$OLD" "$RR/README.md")"
fi

for p in $PIDS; do kill -TERM "$p" 2>/dev/null; done
for p in $PIDS; do wait "$p" 2>/dev/null; done
PIDS=""
snap > "$T/after.snap"
if cmp -s "$T/before.snap" "$T/after.snap"; then
  ok "snapshot: the run changed nothing under $RR (real labels.tsv and corpus.jsonl untouched)"
else
  bad "snapshot: files under $RR changed during the run"
fi

if [ "$fails" -eq 0 ]; then echo PASS; exit 0; fi
echo "$fails failure(s)"
exit 1
