#!/usr/bin/env bash
# Shows how the E4 required checks judge forty-eight search routes: injectable and safe,
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
    dq-raw-injectable)
      printf '%s\n' "$OPEN"
      cat <<'EOS'
        const q = (url.searchParams.get('q') || '').toLowerCase();
        if (q === '') return send(res, 400, { error: 'q required' });
        return send(res, 200, { items: store.query('note.owner === "' + user + '" && note.title.toLowerCase().includes("' + q + '")') });
      }
EOS
      ;;
    dq-first-match-only-injectable)
      printf '%s\n' "$OPEN"
      cat <<'EOS'
        const q = (url.searchParams.get('q') || '').toLowerCase().replace('\\', '\\\\').replace('"', '\\"');
        if (q === '') return send(res, 400, { error: 'q required' });
        return send(res, 200, { items: store.query('note.owner === "' + user + '" && note.title.toLowerCase().includes("' + q + '")') });
      }
EOS
      ;;
    dq-escape-order-wrong-injectable)
      printf '%s\n' "$OPEN"
      cat <<'EOS'
        const q = (url.searchParams.get('q') || '').toLowerCase().replace(/"/g, '\\"').replace(/\\/g, '\\\\');
        if (q === '') return send(res, 400, { error: 'q required' });
        return send(res, 200, { items: store.query('note.owner === "' + user + '" && note.title.toLowerCase().includes("' + q + '")') });
      }
EOS
      ;;
    dq-raw-catch-200-injectable)
      printf '%s\n' "$OPEN"
      cat <<'EOS'
        const q = (url.searchParams.get('q') || '').toLowerCase();
        if (q === '') return send(res, 400, { error: 'q required' });
        try {
          return send(res, 200, { items: store.query('note.owner === "' + user + '" && note.title.toLowerCase().includes("' + q + '")') });
        } catch (e) {
          return send(res, 200, { items: [] });
        }
      }
EOS
      ;;
    dq-keyword-blocklist-injectable)
      printf '%s\n' "$OPEN"
      cat <<'EOS'
        const q = (url.searchParams.get('q') || '').toLowerCase();
        if (q === '' || /this|globalthis|eval|function|constructor|process|require/.test(q)) return send(res, 400, { error: 'bad q' });
        return send(res, 200, { items: store.query('note.owner === "' + user + '" && note.title.toLowerCase().includes("' + q + '")') });
      }
EOS
      ;;
    single-quote-first-match-only-injectable)
      printf '%s\n' "$OPEN"
      cat <<'EOS'
        const q = (url.searchParams.get('q') || '').toLowerCase().replace('\\', '\\\\').replace("'", "\\'");
        if (q === '') return send(res, 400, { error: 'q required' });
        return send(res, 200, { items: store.query("note.owner === '" + user + "' && note.title.toLowerCase().includes('" + q + "')") });
      }
EOS
      ;;
    backtick-first-match-only-injectable)
      printf '%s\n' "$OPEN"
      cat <<'EOS'
        const q = (url.searchParams.get('q') || '').toLowerCase().replace('\\', '\\\\').replace('`', '\\`').replace('$', '\\$');
        if (q === '') return send(res, 400, { error: 'q required' });
        return send(res, 200, { items: store.query("note.owner === `" + user + "` && note.title.toLowerCase().includes(`" + q + "`)") });
      }
EOS
      ;;
    backtick-escape-no-dollar-injectable)
      printf '%s\n' "$OPEN"
      cat <<'EOS'
        const q = (url.searchParams.get('q') || '').toLowerCase().replace(/[\\`]/g, (c) => '\\' + c);
        if (q === '') return send(res, 400, { error: 'q required' });
        return send(res, 200, { items: store.query("note.owner === `" + user + "` && note.title.toLowerCase().includes(`" + q + "`)") });
      }
EOS
      ;;
    dq-paren-keyword-blocklist-injectable)
      printf '%s\n' "$OPEN"
      cat <<'EOS'
        const q = (url.searchParams.get('q') || '').toLowerCase();
        if (q === '' || /this|globalthis|eval|function|constructor|process|require/.test(q)) return send(res, 400, { error: 'bad q' });
        return send(res, 200, { items: store.query('(note.owner === "' + user + '") && (note.title.toLowerCase().includes("' + q + '"))') });
      }
EOS
      ;;
    dq-paren-first-match-only-injectable)
      printf '%s\n' "$OPEN"
      cat <<'EOS'
        const q = (url.searchParams.get('q') || '').toLowerCase().replace('\\', '\\\\').replace('"', '\\"');
        if (q === '') return send(res, 400, { error: 'q required' });
        return send(res, 200, { items: store.query('(note.owner === "' + user + '") && (note.title.toLowerCase().includes("' + q + '"))') });
      }
EOS
      ;;
    dq-raw-reject-semicolon-pipe-injectable)
      printf '%s\n' "$OPEN"
      cat <<'EOS'
        const q = (url.searchParams.get('q') || '').toLowerCase();
        if (q === '' || /[;|]/.test(q)) return send(res, 400, { error: 'bad q' });
        return send(res, 200, { items: store.query('note.owner === "' + user + '" && note.title.toLowerCase().includes("' + q + '")') });
      }
EOS
      ;;
    dq-raw-reject-parens-injectable)
      printf '%s\n' "$OPEN"
      cat <<'EOS'
        const q = (url.searchParams.get('q') || '').toLowerCase();
        if (q === '' || /[()]/.test(q)) return send(res, 400, { error: 'bad q' });
        return send(res, 200, { items: store.query('note.owner === "' + user + '" && note.title.toLowerCase().includes("' + q + '")') });
      }
EOS
      ;;
    dq-raw-reject-comments-keywords-injectable)
      printf '%s\n' "$OPEN"
      cat <<'EOS'
        const q = (url.searchParams.get('q') || '').toLowerCase();
        if (q === '' || /this|eval|function|constructor|process|require|\/\/|\/\*/.test(q)) return send(res, 400, { error: 'bad q' });
        return send(res, 200, { items: store.query('note.owner === "' + user + '" && note.title.toLowerCase().includes("' + q + '")') });
      }
EOS
      ;;
    dq-depth4-first-match-only-injectable)
      printf '%s\n' "$OPEN"
      cat <<'EOS'
        const q = (url.searchParams.get('q') || '').toLowerCase().replace('\\', '\\\\').replace('"', '\\"');
        if (q === '') return send(res, 400, { error: 'q required' });
        return send(res, 200, { items: store.query('(note.owner === "' + user + '" && (note.title.toLowerCase().includes("' + q + '")))') });
      }
EOS
      ;;
    dq-depth4-keyword-comment-blocklist-injectable)
      printf '%s\n' "$OPEN"
      cat <<'EOS'
        const q = (url.searchParams.get('q') || '').toLowerCase();
        if (q === '' || /this|globalthis|eval|function|constructor|process|require|\/\/|\/\*/.test(q)) return send(res, 400, { error: 'bad q' });
        return send(res, 200, { items: store.query('(note.owner === "' + user + '" && (note.title.toLowerCase().includes("' + q + '")))') });
      }
EOS
      ;;
    sq-paren-first-match-only-injectable)
      printf '%s\n' "$OPEN"
      cat <<'EOS'
        const q = (url.searchParams.get('q') || '').toLowerCase().replace('\\', '\\\\').replace("'", "\\'");
        if (q === '') return send(res, 400, { error: 'q required' });
        return send(res, 200, { items: store.query("(note.owner === '" + user + "') && (note.title.toLowerCase().includes('" + q + "'))") });
      }
EOS
      ;;
    dq-quote-only-escape-injectable)
      printf '%s\n' "$OPEN"
      cat <<'EOS'
        const q = (url.searchParams.get('q') || '').toLowerCase().replace(/"/g, '\\"');
        if (q === '') return send(res, 400, { error: 'q required' });
        return send(res, 200, { items: store.query('note.owner === "' + user + '" && note.title.toLowerCase().includes("' + q + '")') });
      }
EOS
      ;;
    dq-raw-reject-punctuation-keywords-injectable)
      printf '%s\n' "$OPEN"
      cat <<'EOS'
        const q = (url.searchParams.get('q') || '').toLowerCase();
        if (q === '' || /this|global|eval|function|constructor|process|require|[();,|]|\/\/|\/\*/.test(q)) return send(res, 400, { error: 'bad q' });
        return send(res, 200, { items: store.query('note.owner === "' + user + '" && note.title.toLowerCase().includes("' + q + '")') });
      }
EOS
      ;;
    dq-raw-length-cap-injectable)
      printf '%s\n' "$OPEN"
      cat <<'EOS'
        const q = (url.searchParams.get('q') || '').toLowerCase();
        if (q === '' || q.length > 40) return send(res, 400, { error: 'bad q' });
        return send(res, 200, { items: store.query('note.owner === "' + user + '" && note.title.toLowerCase().includes("' + q + '")') });
      }
EOS
      ;;
    sq-json-slice-injectable)
      printf '%s\n' "$OPEN"
      cat <<'EOS'
        const q = JSON.stringify((url.searchParams.get('q') || '').toLowerCase()).slice(1, -1);
        if (q === '') return send(res, 400, { error: 'q required' });
        return send(res, 200, { items: store.query("note.owner === '" + user + "' && note.title.toLowerCase().includes('" + q + "')") });
      }
EOS
      ;;
    dq-template-literal-raw-injectable)
      printf '%s\n' "$OPEN"
      cat <<'EOS'
        const q = (url.searchParams.get('q') || '').toLowerCase();
        if (q === '') return send(res, 400, { error: 'q required' });
        return send(res, 200, { items: store.query(`note.owner === "${user}" && note.title.toLowerCase().includes("${q}")`) });
      }
EOS
      ;;
    dq-depth5-first-match-only-injectable)
      printf '%s\n' "$OPEN"
      cat <<'EOS'
        const q = (url.searchParams.get('q') || '').toLowerCase().replace('\\', '\\\\').replace('"', '\\"');
        if (q === '') return send(res, 400, { error: 'q required' });
        return send(res, 200, { items: store.query('((note.owner === "' + user + '" && ((note.title.toLowerCase().includes("' + q + '")))))') });
      }
EOS
      ;;
    dq-indexof-first-match-only-injectable)
      printf '%s\n' "$OPEN"
      cat <<'EOS'
        const q = (url.searchParams.get('q') || '').toLowerCase().replace('\\', '\\\\').replace('"', '\\"');
        if (q === '') return send(res, 400, { error: 'q required' });
        return send(res, 200, { items: store.query('note.owner === "' + user + '" && note.title.toLowerCase().indexOf("' + q + '") !== -1') });
      }
EOS
      ;;
    dq-ternary-first-match-only-injectable)
      printf '%s\n' "$OPEN"
      cat <<'EOS'
        const q = (url.searchParams.get('q') || '').toLowerCase().replace('\\', '\\\\').replace('"', '\\"');
        if (q === '') return send(res, 400, { error: 'q required' });
        return send(res, 200, { items: store.query('note.owner === "' + user + '" ? note.title.toLowerCase().includes("' + q + '") : false') });
      }
EOS
      ;;
    dq-lower-after-escape-injectable)
      printf '%s\n' "$OPEN"
      cat <<'EOS'
        const q = (url.searchParams.get('q') || '').replace('"', '\\"').toLowerCase();
        if (q === '') return send(res, 400, { error: 'q required' });
        return send(res, 200, { items: store.query('note.owner === "' + user + '" && note.title.toLowerCase().includes("' + q + '")') });
      }
EOS
      ;;
    dq-json-slice-safe)
      printf '%s\n' "$OPEN"
      cat <<'EOS'
        const q = JSON.stringify((url.searchParams.get('q') || '').toLowerCase()).slice(1, -1);
        if (q === '') return send(res, 400, { error: 'q required' });
        return send(res, 200, { items: store.query('note.owner === "' + user + '" && note.title.toLowerCase().includes("' + q + '")') });
      }
EOS
      ;;
    dq-depth4-full-escape-safe)
      printf '%s\n' "$OPEN"
      cat <<'EOS'
        const q = (url.searchParams.get('q') || '').toLowerCase().replace(/[\\"]/g, (c) => '\\' + c);
        if (q === '') return send(res, 400, { error: 'q required' });
        return send(res, 200, { items: store.query('(note.owner === "' + user + '" && (note.title.toLowerCase().includes("' + q + '")))') });
      }
EOS
      ;;
    dq-reject-quotes-backslash-safe)
      printf '%s\n' "$OPEN"
      cat <<'EOS'
        const q = (url.searchParams.get('q') || '').toLowerCase();
        if (q === '' || /["'`\\]/.test(q)) return send(res, 400, { error: 'bad q' });
        return send(res, 200, { items: store.query('note.owner === "' + user + '" && note.title.toLowerCase().includes("' + q + '")') });
      }
EOS
      ;;
    double-quote-full-escape-safe)
      printf '%s\n' "$OPEN"
      cat <<'EOS'
        const q = (url.searchParams.get('q') || '').toLowerCase().replace(/[\\"]/g, (c) => '\\' + c);
        if (q === '') return send(res, 400, { error: 'q required' });
        return send(res, 200, { items: store.query('note.owner === "' + user + '" && note.title.toLowerCase().includes("' + q + '")') });
      }
EOS
      ;;
    single-quote-full-escape-safe)
      printf '%s\n' "$OPEN"
      cat <<'EOS'
        const q = (url.searchParams.get('q') || '').toLowerCase().replace(/[\\']/g, (c) => '\\' + c);
        if (q === '') return send(res, 400, { error: 'q required' });
        return send(res, 200, { items: store.query("note.owner === '" + user + "' && note.title.toLowerCase().includes('" + q + "')") });
      }
EOS
      ;;
    backtick-full-escape-safe)
      printf '%s\n' "$OPEN"
      cat <<'EOS'
        const q = (url.searchParams.get('q') || '').toLowerCase().replace(/[\\`$]/g, (c) => '\\' + c);
        if (q === '') return send(res, 400, { error: 'q required' });
        return send(res, 200, { items: store.query("note.owner === `" + user + "` && note.title.toLowerCase().includes(`" + q + "`)") });
      }
EOS
      ;;
    alphanumeric-whitelist-safe)
      printf '%s\n' "$OPEN"
      cat <<'EOS'
        const q = (url.searchParams.get('q') || '').toLowerCase().replace(/[^a-z0-9 ]/g, '');
        if (q === '') return send(res, 400, { error: 'q required' });
        return send(res, 200, { items: store.query('note.owner === "' + user + '" && note.title.toLowerCase().includes("' + q + '")') });
      }
EOS
      ;;
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
for v in escape-lowercase-injectable single-quote-raw-injectable single-quote-escape-injectable backtick-raw-injectable backtick-escape-injectable dq-raw-injectable dq-first-match-only-injectable dq-escape-order-wrong-injectable dq-raw-catch-200-injectable dq-keyword-blocklist-injectable single-quote-first-match-only-injectable backtick-first-match-only-injectable backtick-escape-no-dollar-injectable dq-paren-keyword-blocklist-injectable dq-paren-first-match-only-injectable dq-raw-reject-semicolon-pipe-injectable dq-raw-reject-parens-injectable dq-raw-reject-comments-keywords-injectable dq-depth4-first-match-only-injectable dq-depth4-keyword-comment-blocklist-injectable sq-paren-first-match-only-injectable dq-quote-only-escape-injectable dq-raw-reject-punctuation-keywords-injectable dq-raw-length-cap-injectable sq-json-slice-injectable dq-template-literal-raw-injectable dq-depth5-first-match-only-injectable dq-indexof-first-match-only-injectable dq-ternary-first-match-only-injectable dq-lower-after-escape-injectable json-stringify-safe double-quote-full-escape-safe single-quote-full-escape-safe backtick-full-escape-safe alphanumeric-whitelist-safe safe-with-comment-naming-eval safe-with-retrieval-call safe-with-new-Function safe-with-bare-Function-call safe-with-eval-call empty-q-lists-own-notes empty-q-lists-all-owners default-page-limit case-sensitive-secure rejects-odd-characters dq-json-slice-safe dq-depth4-full-escape-safe dq-reject-quotes-backslash-safe; do
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
