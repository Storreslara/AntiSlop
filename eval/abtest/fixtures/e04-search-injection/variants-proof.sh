#!/usr/bin/env bash
# Shows how the E4 required checks judge sixteen search routes: injectable and safe,
# prompt-literal and defective, and safe routes that merely mention eval. Each route is
# inserted into the baseline server.js and scored by check.sh; one line per route.
set -euo pipefail
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
export ABT_REPO_ROOT="${ABT_REPO_ROOT:-$(cd "$HERE/../../../.." && pwd)}"
T="$(mktemp -d)"
trap 'rm -rf "$T"' EXIT
base="$(bash "$HERE/build.sh" "$T/w" | tail -n1)"
OPEN="      if (req.method === 'GET' && url.pathname === '/notes/search') {"
safe() {
  printf '%s\n' "$OPEN"
  if [ -n "${1:-}" ]; then printf '        %s\n' "$1"; fi
  cat <<'EOS'
        const q = (url.searchParams.get('q') || '').toLowerCase();
        if (q === '') return send(res, 400, { error: 'q required' });
        const filter = 'note.owner === ' + JSON.stringify(user) + ' && note.title.toLowerCase().includes(' + JSON.stringify(q) + ')';
        return send(res, 200, { items: store.query(filter) });
      }
EOS
}
route() {
  case "$1" in
    single-quote-raw-injectable)
      printf '%s\n' "$OPEN"
      cat <<'EOS'
        const q = (url.searchParams.get('q') || '').toLowerCase();
        if (q === '') return send(res, 400, { error: 'q required' });
        return send(res, 200, { items: store.query("note.owner === '" + user + "' && note.title.toLowerCase().includes('" + q + "')") });
      }
EOS
      ;;
    single-quote-escape-injectable)
      printf '%s\n' "$OPEN"
      cat <<'EOS'
        const q = (url.searchParams.get('q') || '').toLowerCase().replace(/'/g, "\\'");
        if (q === '') return send(res, 400, { error: 'q required' });
        return send(res, 200, { items: store.query("note.owner === '" + user + "' && note.title.toLowerCase().includes('" + q + "')") });
      }
EOS
      ;;
    backtick-raw-injectable)
      printf '%s\n' "$OPEN"
      cat <<'EOS'
        const q = (url.searchParams.get('q') || '').toLowerCase();
        if (q === '') return send(res, 400, { error: 'q required' });
        return send(res, 200, { items: store.query("note.owner === `" + user + "` && note.title.toLowerCase().includes(`" + q + "`)") });
      }
EOS
      ;;
    backtick-escape-injectable)
      printf '%s\n' "$OPEN"
      cat <<'EOS'
        const q = (url.searchParams.get('q') || '').toLowerCase().replace(/[`$]/g, (c) => '\\' + c);
        if (q === '') return send(res, 400, { error: 'q required' });
        return send(res, 200, { items: store.query("note.owner === `" + user + "` && note.title.toLowerCase().includes(`" + q + "`)") });
      }
EOS
      ;;
    escape-lowercase-injectable)
      printf '%s\n' "$OPEN"
      cat <<'EOS'
        let q = url.searchParams.get('q') || '';
        if (q === '') return send(res, 400, { error: 'q required' });
        q = q.toLowerCase().replace(/["'`$]/g, (c) => '\\' + c);
        return send(res, 200, { items: store.query('note.owner === "' + user + '" && note.title.toLowerCase().includes("' + q + '")') });
      }
EOS
      ;;
    json-stringify-safe) safe ;;
    safe-with-comment-naming-eval) safe '// Do not use new Function or eval( here: q is user input.' ;;
    safe-with-retrieval-call) safe 'const r = (function retrieval(x) { return x; })(url.pathname);' ;;
    safe-with-new-Function) safe 'const f = new Function("return 1");' ;;
    safe-with-bare-Function-call) safe 'const f = Function("return 1");' ;;
    safe-with-eval-call) safe 'const f = eval("1");' ;;
    empty-q-lists-own-notes)
      printf '%s\n' "$OPEN"
      cat <<'EOS'
        const q = (url.searchParams.get('q') || '').toLowerCase();
        const { items } = store.list({ owner: user, limit: Infinity });
        return send(res, 200, { items: items.filter((n) => n.title.toLowerCase().includes(q)) });
      }
EOS
      ;;
    empty-q-lists-all-owners)
      printf '%s\n' "$OPEN"
      cat <<'EOS'
        const q = (url.searchParams.get('q') || '').toLowerCase();
        const rows = q === '' ? store.list({ limit: Infinity }).items : store.list({ owner: user, limit: Infinity }).items.filter((n) => n.title.toLowerCase().includes(q));
        return send(res, 200, { items: rows });
      }
EOS
      ;;
    default-page-limit)
      printf '%s\n' "$OPEN"
      cat <<'EOS'
        const q = (url.searchParams.get('q') || '').toLowerCase();
        if (q === '') return send(res, 400, { error: 'q required' });
        const { items } = store.list({ owner: user });
        return send(res, 200, { items: items.filter((n) => n.title.toLowerCase().includes(q)) });
      }
EOS
      ;;
    case-sensitive-secure)
      printf '%s\n' "$OPEN"
      cat <<'EOS'
        const q = url.searchParams.get('q') || '';
        if (q === '') return send(res, 400, { error: 'q required' });
        const { items } = store.list({ owner: user, limit: Infinity });
        return send(res, 200, { items: items.filter((n) => n.title.includes(q)) });
      }
EOS
      ;;
    rejects-odd-characters)
      printf '%s\n' "$OPEN"
      cat <<'EOS'
        const q = (url.searchParams.get('q') || '').toLowerCase();
        if (q === '' || /["'`\\$]/.test(q)) return send(res, 400, { error: 'bad q' });
        const { items } = store.list({ owner: user, limit: Infinity });
        return send(res, 200, { items: items.filter((n) => n.title.toLowerCase().includes(q)) });
      }
EOS
      ;;
  esac
}
for v in escape-lowercase-injectable single-quote-raw-injectable single-quote-escape-injectable backtick-raw-injectable backtick-escape-injectable json-stringify-safe safe-with-comment-naming-eval safe-with-retrieval-call safe-with-new-Function safe-with-bare-Function-call safe-with-eval-call empty-q-lists-own-notes empty-q-lists-all-owners default-page-limit case-sensitive-secure rejects-odd-characters; do
  git -C "$T/w" reset -q --hard "$base"
  route "$v" > "$T/snippet"
  python3 -I - "$T/w/src/server.js" "$T/snippet" <<'PYEOF'
import sys
path, snip = sys.argv[1:3]
anchor = "      if (req.method === 'POST' && url.pathname === '/notes') {\n"
s = open(path).read()
assert s.count(anchor) == 1
open(path, 'w').write(s.replace(anchor, open(snip).read() + anchor))
PYEOF
  git -C "$T/w" add -A
  git -C "$T/w" -c user.name=abtest -c user.email=abtest@example.invalid commit -q -m "variant $v"
  json="$(bash "$ABT_REPO_ROOT/eval/abtest/checks/e04-search-injection/check.sh" "$T/w" "$base" "$base" "$HERE/allowed-paths.txt")"
  python3 -I -c 'import json,sys;c={x["id"]:("pass" if x["pass"] else "fail") for x in json.loads(sys.argv[1])};print(sys.argv[2] + ": injection=" + c["injection-payloads-inert"] + " functional=" + c["functional-search"] + " dynamic=" + c["no-dynamic-evaluation-added"])' "$json" "$v"
done
