#!/usr/bin/env bash
# scripts/portable-convert.py: each rule rewrites its exact shape, a second pass changes nothing,
# two runs are byte-identical, and quoted/commented/portable-ok text is left alone.
set -uo pipefail
cd "$(dirname "$0")/.."
tool=scripts/portable-convert.py
tmp="$(mktemp -d)"; trap 'rm -rf "$tmp"' EXIT
fail=0
ok() { echo "OK   $1"; }
bad() { echo "FAIL $1"; fail=1; }

mkdir "$tmp/w"
cat > "$tmp/in.sh" <<'SH'
f() {
  rest="${cmd//$'\047'/}"; rest="${rest//$'\042'/}"
  for x in "${arr[@]}"; do :; done
  l="${1,,}"
  m=$(stat -c %Y "$f" 2>/dev/null || echo 0)
  n=$(stat -L --format=%Y "$f")
  d=$(date -u -d "@$t" +%Y 2>/dev/null || echo "")
  copy=( "${a[@]}" "${b[@]}" )
}
mapfile -t lines < <(git ls-files)
head -n -1 file.txt > out.txt
v=$(echo "$s" | paste -sd' ')
sed -n '1,/^---$/{s/^model: *//p}' f
# for x in "${comment[@]}"; do
pinned='for x in "${arr[@]}"; do'
for y in "${ok[@]}"; do :; done  # portable-ok
SH
mv "$tmp/in.sh" "$tmp/orig.sh"; cp "$tmp/orig.sh" "$tmp/w/in.sh"

python3 -I "$tool" --root "$tmp/w" --write --quiet-manual --no-syntax >/dev/null
out="$tmp/w/in.sh"
has() { /usr/bin/grep -qF -- "$2" "$out" && ok "$1" || bad "$1 (missing: $2)"; }
has quote-in-pattern    'rest="${cmd//$sq/}"; rest="${rest//$dq/}"'
has quote-decl          "local sq=\$'\\047' dq=\$'\\042'"
has empty-array-loop    'for x in ${arr[@]+"${arr[@]}"}; do'
has case-fold           "l=\"\$(printf '%s' \"\$1\" | tr '[:upper:]' '[:lower:]')\""
has stat-c              'stat -f %m "$f" 2>/dev/null || echo 0'
has stat-format         'stat -L -c %Y "$f" 2>/dev/null || stat -L -f %m "$f"'
has date-d              'date -u -r "$t" +%Y 2>/dev/null || echo'
has array-copy          'copy=( ${a[@]+"${a[@]}"} ${b[@]+"${b[@]}"} )'
has mapfile             'lines=(); while IFS= read -r _mf_line'
has head-neg            "sed '\$d' file.txt > out.txt"
has paste-stdin         "paste -sd' ' -)"
has sed-brace           's/^model: *//p;}'"'"
has untouched-comment   '# for x in "${comment[@]}"; do'
has untouched-quoted    "pinned='for x in \"\${arr[@]}\"; do'"
has untouched-marker    'for y in "${ok[@]}"; do :; done  # portable-ok'

cp "$out" "$tmp/once.sh"
python3 -I "$tool" --root "$tmp/w" --write --quiet-manual --no-syntax >/dev/null
cmp -s "$tmp/once.sh" "$out" && ok "idempotent: a second pass changes nothing" || bad "second pass changed the file"

mkdir "$tmp/a" "$tmp/b"; cp "$tmp/orig.sh" "$tmp/a/in.sh"; cp "$tmp/orig.sh" "$tmp/b/in.sh"
python3 -I "$tool" --root "$tmp/a" --write --quiet-manual --no-syntax >/dev/null
python3 -I "$tool" --root "$tmp/b" --write --quiet-manual --no-syntax >/dev/null
cmp -s "$tmp/a/in.sh" "$tmp/b/in.sh" && ok "deterministic: two runs are byte-identical" || bad "two runs differ"

mkdir "$tmp/c"; cp "$tmp/orig.sh" "$tmp/c/in.sh"
python3 -I "$tool" --root "$tmp/c" --check --quiet-manual --no-syntax >/dev/null && bad "--check should exit 1 when fixes are pending" || ok "--check exits 1 when fixes are pending"
python3 -I "$tool" --root "$tmp/c" --check --quiet-manual --no-syntax >/dev/null; cmp -s "$tmp/orig.sh" "$tmp/c/in.sh" && ok "--check does not modify files" || bad "--check modified a file"

python3 -I "$tool" --check --quiet-manual >/dev/null && ok "the repo itself has no pending fixes" || bad "the repo has pending portable-convert fixes (run: python3 -I scripts/portable-convert.py --write)"
exit "$fail"
