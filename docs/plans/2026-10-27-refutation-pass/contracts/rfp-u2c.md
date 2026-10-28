Unit: rfp-u2c

## Objective
Ship a permanent Gate G1 labeling tool inside the repository: `python3 eval/refutation-replay/label.py serve`.
It is a small localhost server that builds the labeling page in memory and writes each label straight into
`eval/refutation-replay/labels.tsv` in the working tree when the human clicks a label button. There is no
temp file, no export and no download. The human reviews `git diff` and commits `labels.tsv`; that commit is
the record.

It replaces the throwaway generator from the superseded unit `label-ui` (commits a541f157, 476297ad,
ae614188; files `eval/refutation-replay/label-ui.py` and `tests/refutation-label-ui.test.sh`). That unit
FAILed review 3 times on one class of defect: a keyboard shortcut, or a stale focused button, wrote a label
onto a card the human could not see. The defect was found in a real browser, not in jsdom. A 4th attempt was
cancelled, so its ladder is spent. This unit deletes both files. Their history stays in git.

User decisions (2026-10-28, via AskUserQuestion), not to be re-opened:
1. The server ships in the repository. It serves the page from memory and writes the clicks into
   `labels.tsv`. Only a human click in the page may write. It binds to 127.0.0.1 only.
2. Labeling is mouse-only. The r/b/u keyboard label shortcuts are removed entirely. j/k navigation, the
   filters, search, collapsible groups, the progress panel and the evidence stay. A label is written only by a
   mouse click on a label button in a card the human can see. A keyboard-synthesised click (`e.detail === 0`,
   or Enter/Space on a focused button) never writes, and a label button never keeps focus after a click.

This unit runs **no** model and no paid replay. Plan decisions D1 to D8 are unchanged.

## Retrieval
Fast path, no tracker issue. Spec: `docs/plans/2026-10-27-refutation-pass.md` ("Units and order",
"Step 2c", "Gate G"). This file is the contract of record. Dispatch after rfp-u2b has a PASS (it has one, at
2ca36854). Gate G runs only after this unit's PASS.

## Affected files
- `tests/refutation-label-server.py` (anchor: new file, mode 644): the server suite, Python stdlib only.
- `tests/refutation-label-browser.js` (anchor: new file, mode 644): the real-browser probe (playwright, Node).
- `tests/refutation-label.test.sh` (anchor: new file, mode 755): the wrapper that runs both and the docs case.
- `eval/refutation-replay/label.py` (anchor: new file, mode 755): the server, the evidence builder and the CLI.
- `eval/refutation-replay/label_page.html` (anchor: new file, mode 644): the page template, read once at startup.
- `eval/refutation-replay/README.md` (anchor: line matching `## Gate G (manual: the human operator runs it)`, the Files table and Gate G step 1)
- `tests/validate.sh` (anchor: line matching `echo "== review-precheck: the reviewer's mechanical pre-review, failure lines are FAIL grounds (Bash, st-u2) =="`)
- `eval/refutation-replay/label-ui.py` (anchor: whole file; deleted with `git rm`)
- `tests/refutation-label-ui.test.sh` (anchor: whole file; deleted with `git rm`)

No version-stamped path (nothing under agents/ or templates/) is touched, and `eval/` is `export-ignore`, so
there is no version bump and no CHANGELOG entry (constitution P3 does not apply). `label-ui` was never registered in
`tests/validate.sh`, so there is no registration to remove.

## Ordered edits
The edits describe behaviour and fix a few names and anchor comments. They are not a byte-exact payload,
because there is no tested implementation to copy from. Edits 1 to 3 are the red step. Criterion 3 deletes or
moves the lines that carry the anchor comments in the table below, so those lines must be written exactly as
shown, each on its own line.

| anchor comment | file | the line that carries it | mutation (criterion 3) | must turn red |
|---|---|---|---|---|
| `# mut:host` | `label.py` | `if not self._host_ok(): return self._refuse(403, 'host')  # mut:host`, in both `do_GET` and `do_POST` | delete every such line | S04 |
| `# mut:origin` | `label.py` | `if not self._origin_ok(): return self._refuse(403, 'origin')  # mut:origin`, in `do_POST` | delete it | S05 |
| `# mut:token` | `label.py` | `if not self._token_ok(): return self._refuse(403, 'token')  # mut:token`, in `do_POST` (the GET `?t=` check is a separate line with no anchor) | delete it | S03 |
| `# mut:version` | `label.py` | `if body['version'] != current: return self._refuse(409, 'stale', version=current)  # mut:version`, inside the write lock | delete it | S08 |
| `# mut:atomic` | `label.py` | exactly `os.replace(tmp, path)  # mut:atomic` (two spaces before `#`) | replace it with `open(path, "w").write(open(tmp).read()); os.unlink(tmp)` | S09 |
| `// mut:detail` | `label_page.html` | `if (e.detail === 0) return; // mut:detail`, in the label-button click handler | delete it | B04 |
| `// mut:keys` | `label_page.html` | the first statement of the document `keydown` handler, e.g. `var k = e.key; // mut:keys` | insert `if (e.key === "r" && target) postLabel(target, "real");` after it | B05 |
| `// mut:refresh-first` and `// mut:scroll` | `label_page.html` | two adjacent lines in `afterLabel()`: `refresh(); // mut:refresh-first`, then the line that scrolls the target, e.g. `scrollToTarget(); // mut:scroll` | move the refresh line after the scroll line | B06 |

Fixed names that the mutations and the probe rely on:
- `target` is the page's navigation target: a row id string, or `null`.
- `postLabel(id, value)` is the page's only function that sends a write.
- `document.body.dataset.pending` is `"1"` while a POST is in flight and `"0"` otherwise. The probe waits on it.
- `<main data-rows="<n>">` is rendered by the server with the row count.
- Card `<article>` elements carry `data-id="<row id>"`. Label buttons have class `lbl` and `data-value="real|bogus|unknown"`.

0. command: `git diff -- eval/refutation-replay/label-ui.py tests/refutation-label-ui.test.sh > "$SCRATCH/label-ui-wip.diff"; git diff --stat`
   expect: 0
   This is the cancelled 4th label-ui attempt, uncommitted. Read it before anything else. It carries three
   things to port into `label.py`: `cited()` matching `^D\d+: ` (two-digit D numbers), `sides()` for
   rename-aware numstat paths (`old => new` and `pre/{old => new}/post`), and the tall fixture idea (24 cards,
   each with a diff, so the page scrolls). Keep the ideas, not the files: edit 6 deletes both files, which also
   discards the edits. `$SCRATCH` is your session scratch directory, never the repository. At the end the
   tree must be clean (criterion 12).
1. file: `tests/refutation-label-server.py`
   anchor: new file
   Create it with the **Write** tool (a Bash heredoc is refused by the hooks). It imports `label.py` by path
   from `../eval/refutation-replay/`, relative to its own location. It builds every fixture under
   `tempfile.mkdtemp()`: a small git repository with a fix commit that edits one cited file and renames another,
   a corpus of 6 rows in 3 groups (one claim holds `</script><b>x</b>`, one is `D12:`), a labels file with a
   `#` header, and an empty corpus. It never opens the real `labels.tsv` or `corpus.jsonl`. It starts the server
   in-process on port 0 in a thread with `make_server(...)` (edit 4). It talks to it with `http.client`, so it
   can set any `Host` and `Origin` header. It prints one line per case, `ok - <ID> <text>` or
   `FAIL - <ID> <text>: <detail>`, and exits 1 if any case fails. Cases, by ID (criterion 2 reads the IDs):
   - **S01** Starting the server, `GET /?t=<token>`, `GET /` with no token and a few 404 paths write nothing. The
     labels file's bytes, inode and mtime, the fixture directory listing, and the log file's absence are all
     unchanged.
   - **S02** `GET /` with no `t` or a wrong `t` returns 403, and the body does not contain the token. With the
     right `t` it returns 200 with `Cache-Control: no-store`, `X-Content-Type-Options: nosniff`, a
     `Content-Security-Policy` with `default-src 'none'` and `frame-ancestors 'none'`, and `data-rows="6"`. The
     embedded `version` equals the sha256 of the file's bytes.
   - **S03** A POST with no `X-Label-Token` header, or a wrong one, returns 403, and the file is unchanged.
   - **S04** A request with `Host: evil.example:<port>`, `Host: 127.0.0.1:<other port>` or no Host header
     returns 403 on GET and on POST, and the file is unchanged. `Host: localhost:<port>` is accepted.
   - **S05** A POST with no `Origin`, `Origin: null`, `Origin: http://evil.example` or an Origin with another
     port returns 403, and the file is unchanged.
   - **S06** Each of these returns 400 and leaves the file unchanged: an id not in the corpus; the values
     `REAL`, `maybe`, `""` and `null`; a non-JSON body; a JSON array; a missing key; an extra key; a
     `Content-Type` other than `application/json`.
   - **S07** A body over 1024 bytes, or a POST with no `Content-Length`, returns 413 or 411, and the file is
     unchanged.
   - **S08** A POST that carries an old `version` returns 409 with the current version in its JSON body. The file
     is unchanged. A file edited by an outside process between the GET and the POST also returns 409.
   - **S09** A valid POST returns 200 with the new version (the sha256 of the new bytes). Exactly one line of the
     file differs, the id's line. The header line and every other byte are identical, and the corpus order is
     kept. The file mode is unchanged, the inode changed (a rename, not an in-place write), and no temp file
     remains in the directory. A POST that repeats the current value returns 200 and does not rewrite the file.
   - **S10** 20 threads POST 20 distinct ids with the same starting version. Exactly one gets 200 and 19 get 409.
     Each thread then retries with the version from its 409 until it succeeds. The final file holds all 20
     labels, and every read taken while the threads were running parses as a complete labels file.
   - **S11** Only `GET /` and `POST /label` exist. `PUT`, `DELETE`, `PATCH` and `OPTIONS` return 405.
     `GET /label`, `GET /labels.tsv`, `GET /corpus.jsonl`, `GET /../labels.tsv`, `GET /label.py` and
     `POST /` return 404 or 405. No response, including `OPTIONS`, carries an `Access-Control-` header.
   - **S12** Each POST, accepted or refused, appends exactly one JSON line to the `--log` file. The line holds
     `ts`, `status`, `id`, `old`, `new`, `version_before`, `version_after`, `remote`, `origin` and
     `user_agent`, and never the token. The log path is outside the labels file's directory in this fixture.
   - **S13** Startup refuses with exit 2 and a one-line reason, writing nothing, when the labels file: has no `#`
     first line; has CRLF line endings; has a value outside `real|bogus|unknown`; repeats an id; lacks a corpus
     id; or lists the ids in another order than the corpus. It also refuses when the port is already bound.
   - **S14** The CLI. `label.py serve --no-open --port 0 ...` prints exactly one line matching
     `^label: http://127\.0\.0\.1:[0-9]+/\?t=[A-Za-z0-9_-]{32,}$` and serves. The bound address is `127.0.0.1`.
     Without `--no-open`, with `PATH` set to a directory of fake `wslview` and `xdg-open` that record their
     argv and exit 1 (then `/usr/bin:/bin`), it still serves (GET 200), and a fake received the URL. SIGTERM
     and SIGINT each make it exit 0 within 5 s, after which the port is closed.
   - **S15** The evidence. `cited()` reads `D12: a.txt:2` as `('a.txt', 2)`. A fix commit that renames the cited
     file counts as `touches`, whether the claim cites the old name or the new one. The diff is cut at 200 lines,
     with the truncated flag set. An unreachable fix commit gives hint `unknown`. The page has exactly the
     template's own `</script>` closers. The `</script><b>x</b>` claim appears only escaped (`<`). The page
     shows the hint with the words "not a label". The progress thresholds equal `score.py`'s `MIN_REAL` and
     `rows - MIN_REAL`.
   - **S16** An empty corpus with a header-only labels file starts, serves `data-rows="0"`, and refuses any POST
     with 400.

   Run it before edit 4: it must exit 1, because `label.py` does not exist yet.
2. file: `tests/refutation-label-browser.js`
   anchor: new file
   Create it with the **Write** tool. Usage:
   `node tests/refutation-label-browser.js <playwright dir> <url> <labels file> <log file> <empty-url>`.
   It prints `name=PASS` or `name=FAIL <detail>` lines with the B IDs below, and exits 3 if Chromium cannot be
   launched (the wrapper then tries the next candidate). It launches headless Chromium through
   `require(<playwright dir>)`. The browser is playwright's own (`~/.cache/ms-playwright`, which holds
   `chromium_headless_shell-1234`), or `CHROMIUM_PATH` if set. Nothing is installed and nothing touches the
   network. All input is trusted: `page.mouse` and `page.keyboard`, never `el.click()` (except in B04, where an
   untrusted script click is the point). After every step it waits until `document.body.dataset.pending` is
   `"0"` and no request is in flight, then reads the labels file from disk and compares it with its own model.
   The model changes only on a trusted mouse click on a label button whose centre is inside the viewport, below
   the sticky header, and is the `document.elementFromPoint` hit. That click changes exactly that card's id to
   that button's value. Any other difference is a FAIL that names the step, the action and the seed.

   **On screen** is defined once and used by both the page and the probe: a card is on screen when it is
   displayed, and its top edge is at or below the sticky header's bottom edge and above the viewport's bottom
   edge.

   Cases:
   - **B01** The page renders one card per row. The progress panel shows real, bogus and unknown counts equal to
     the file, and the targets `at least MIN_REAL real` and `at most rows - MIN_REAL bogus`. Each card shows the
     claim, the fix commit (short sha and subject), the numstat list with the cited file marked, the hint, and a
     collapsed diff with an expand control.
   - **B02** A mouse click on a visible card's `real`, then `bogus`, then `unknown` button writes exactly that
     card's line each time. After each click `document.activeElement` is not a `.lbl` button, and that card is
     the target.
   - **B03** With a target set, pressing `j`, `k`, `Space`, `Enter`, `Tab`, `Shift+Tab`, `ArrowDown`, `PageDown`,
     `Home` and `End`, each followed by the pending wait, sends no POST and changes no byte of the file. The probe
     counts POST requests with `page.on('request')`.
   - **B04** A label button focused with `el.focus()`, then `Enter` and then `Space` with trusted keys, sends no
     POST. A script `el.click()` sends no POST. `el.dispatchEvent(new MouseEvent('click', {detail: 0}))` sends no
     POST.
   - **B05** With a target set, `r`, `b` and `u` (and `R`, `B`, `U`) send no POST and change nothing.
   - **B06** In a page with `html, body { overflow-anchor: none }` added by the probe, choose filter `unknown`,
     expand the diffs of the first 4 cards, scroll so that card 2 is on screen, and click its `real` button. Card
     2 is hidden by the filter, the target is the next visible card, and that card is on screen. Repeat 6 times
     down the page; all 6 must hold. This is label-ui FAIL 3's second defect.
   - **B07** Scroll with the mouse wheel until the target is far off screen, then press `j`. The new target is on
     screen. Repeat with `k`. A navigation key never selects an off-screen card.
   - **B08** The probe changes one other id's line in the labels file itself, with an atomic rename. Then it
     clicks a label button. The POST gets 409, the page shows a "labels.tsv changed on disk" notice and reloads,
     and the file equals the probe's own edit, so nothing was overwritten. After the reload the page shows the
     probe's value, and the next click writes normally.
   - **B09** A seeded random sequence, seed `LABEL_PROBE_SEED` (default `20261028`), `LABEL_PROBE_STEPS` steps
     (default 200). Each step is drawn from: a mouse click on a random on-screen label button; a mouse click at
     a random point; a key from B03's list plus `r`, `b` and `u`; programmatic focus on a random label button,
     then `Enter` or `Space`; set a filter; type or clear a search; collapse or expand a random group; expand or
     collapse a random diff; a wheel scroll of ±200 to ±2000 px; a viewport resize among 1280x800, 800x600 and
     390x844. After every step the file must equal the model. The case name prints the seed and the step count.
   - **B10** The empty-corpus page (`<empty-url>`) loads, shows 0 cards, and `j`, `k` and a filter change throw
     nothing.
   - **B11** No `pageerror` and no console `error` occurred in any case.
3. file: `tests/refutation-label.test.sh`
   anchor: new file
   Create it with the **Write** tool, then `chmod 755`. It runs `cd "$(dirname "$0")/.."` and needs nothing
   outside `eval/refutation-replay/{label.py,label_page.html,README.md}` and the three `tests/refutation-label*`
   files: criterion 3 runs it in a scratch copy holding only those. It:
   - runs `python3 tests/refutation-label-server.py` and forwards its `ok -` and `FAIL -` lines;
   - builds the browser fixture under `mktemp -d`: a fixture repository and the tall corpus (24 rows in 3 groups,
     every claim citing a file its fix commit touches, so each card has a diff), a header-only labels file, and an
     empty corpus. It starts two `label.py serve --no-open --port 0 --log <tmp>` servers, reads each URL line,
     and stops them with SIGTERM on exit;
   - searches for playwright and never installs it: `PLAYWRIGHT_PATH`, `$ROOT/node_modules/playwright-core`,
     `$ROOT/node_modules/playwright`, then
     `$HOME/miniforge3/envs/*/lib/python3*/site-packages/playwright/driver/package`,
     `$HOME/.local/lib/python3*/site-packages/playwright/driver/package` and
     `/usr/lib/python3/dist-packages/playwright/driver/package`. This is label-ui's list; on this machine the
     miniforge `claude_voice` and `recipe_llm` envs hold one. It runs the probe under `timeout 540` per
     candidate and moves on when the exit is 3;
   - prints `ok - B<nn> …` or `FAIL - B<nn> …` for each probe line, and `FAIL - B00 probe reported <n> of 11
     cases` unless exactly 11 lines came back;
   - when no node, playwright or Chromium works: with `LABEL_UI_REQUIRE_BROWSER` set, prints
     `FAIL - B00 LABEL_UI_REQUIRE_BROWSER is set but no playwright plus Chromium launched (set PLAYWRIGHT_PATH or
     CHROMIUM_PATH)`; otherwise prints exactly one line starting `SKIP !!! no playwright plus Chromium found`
     that says all real-browser checks were skipped and the run proves nothing about them. Setting
     `LABEL_UI_NO_BROWSER_SEARCH=1` skips the search, so that path can be tested (criterion 9). It only ever
     disables the probe;
   - **D01** checks that every `--option` on the README's Gate G step 1 `label.py serve` line appears in
     `python3 eval/refutation-replay/label.py serve --help`, and that the README does not mention `label-ui`;
   - checks before and after that the fixture labels files are the only files the run changed (the real
     `labels.tsv` and `corpus.jsonl` are never opened);
   - ends with `PASS` and exit 0, or `<n> failure(s)` and exit 1. A SKIP alone does not fail the run.
   Run it: it must exit 1 (red).
4. file: `eval/refutation-replay/label.py`
   anchor: new file
   Create it with the **Write** tool, then `chmod 755`. Python 3 stdlib only. No `shell=True`, no `os.system`,
   no network beyond the listening socket, and no `claude`, `anthropic` or `https://` text anywhere.
   - **CLI.** `label.py serve [--corpus P] [--labels P] [--repo D] [--port N] [--log P] [--no-open]`. The
     defaults are this directory's `corpus.jsonl` and `labels.tsv`, `--repo` the repository root, `--port 0`
     (an ephemeral port), and `--log` set to `<git dir>/refutation-label-writes.log` from
     `git -C <repo> rev-parse --absolute-git-dir`. That file is local, never tracked and never dirties the tree.
     Without a git dir, `--log` is required. There is no `--host` option.
   - **Startup.** Validate the labels file against the corpus (S13). Build every card's evidence. Read
     `MIN_REAL` from `score.py` (import it by path or parse its constant line; never hard-code 30). Read
     `label_page.html` once. Generate a 32-byte `secrets.token_urlsafe` token. Bind `127.0.0.1` only, with
     `allow_reuse_address = False`. Print `label: http://127.0.0.1:<port>/?t=<token>` and flush. Unless
     `--no-open` is given, try to open the URL. On WSL (`microsoft` in `/proc/sys/kernel/osrelease`) try
     `wslview`, then `explorer.exe`; elsewhere try `xdg-open`. Each opener is found with `shutil.which` and
     started with `subprocess.Popen([...], stdin/stdout/stderr=DEVNULL, start_new_session=True)`. Any failure
     prints `label: could not open a browser; open the URL above` and carries on. Startup writes nothing: not
     the labels file, not the log, no temp file.
   - **Evidence**, ported from label-ui with the WIP fixes from edit 0: `cited()` (`^D\d+: `), `sides()`,
     `evidence()` (fix sha and subject; numstat with a rename-aware cited-file mark; hint `touches`,
     `untouched` or `unknown`; the cited file's diff from the fix commit cut at 200 lines with a truncated
     flag); `embed()` (JSON with `<`, `>` and `&` escaped as `<`, `>` and `&`).
   - **`make_server(corpus, labels, repo, log, port=0)`** returns a started-but-not-serving
     `ThreadingHTTPServer` (with `daemon_threads = True` and a 10 s socket timeout) that has `.token` and
     `.url`. The tests use it in-process.
   - **GET.** Exactly path `/` with query `t=<token>` (compared with `hmac.compare_digest`) returns the page.
     Every other path returns 404. A missing or wrong token returns 403. The `Host` check comes first, on its
     own anchored line. Response headers: `Content-Type: text/html; charset=utf-8`, `Cache-Control: no-store`,
     `X-Content-Type-Options: nosniff`, `Referrer-Policy: no-referrer`, and
     `Content-Security-Policy: default-src 'none'; script-src 'nonce-<n>'; style-src 'unsafe-inline'; connect-src 'self'; base-uri 'none'; form-action 'none'; frame-ancestors 'none'`,
     with a fresh nonce per response. The page data goes in `<script id="data" type="application/json">`:
     rows, labels, `version`, the token, `min_real` and `max_bogus`.
   - **POST `/label`**, checks in this order, each refusal a single-line `if …: return self._refuse(...)`:
     Host (`# mut:host`); Origin, exactly `http://127.0.0.1:<port>` or `http://localhost:<port>`
     (`# mut:origin`); `X-Label-Token` via `hmac.compare_digest` (`# mut:token`); `Content-Type:
     application/json`; `Content-Length` present (else 411) and at most 1024 (else 413), then read exactly that
     many bytes; JSON object with exactly the keys `id`, `value` and `version`; `id` in the corpus; `value` in
     `real|bogus|unknown`. Then, under one `threading.Lock`: read the file's bytes; `current` = their sha256
     hex; the version check (`# mut:version`); if the value is unchanged, return 200 without writing.
     Otherwise build the new bytes by replacing exactly that id's one line, keeping every other byte. Write
     them to `tempfile.mkstemp(dir=<labels dir>, prefix='.labels.', suffix='.tmp')`, `os.chmod` it to the old
     file's mode, write, flush and `os.fsync`, then `os.replace(tmp, path)  # mut:atomic`, `os.fsync` the
     directory, and remove the temp file in a `finally` if the rename did not happen. Append the log line (S12),
     then return 200 `{"ok": true, "id", "value", "version"}`. Every refusal is JSON `{"error": <reason>}`
     plus the current `version` on 409, and is logged too. Other methods return 405. No response ever sends an
     `Access-Control-*` header.
   - **No other writer.** There is no bulk endpoint, no "mark all", no default value and no auto-label. Nothing
     but a valid POST changes the file.
   - **Shutdown.** SIGINT and SIGTERM call `server.shutdown()` from a helper thread, close the socket, print
     `label: stopped real=<r> bogus=<b> unknown=<u>` from the file, and exit 0.
5. file: `eval/refutation-replay/label_page.html`
   anchor: new file
   Create it with the **Write** tool. One template with `__DATA__` and `__NONCE__` placeholders. The server fills
   them in memory, and the data is the only dynamic part. No external resource and no `style=` attribute. All
   repository-derived text goes in through `textContent`, never `innerHTML`. Behaviour:
   - **Cards** are indexed by row id (`data-id`), never by position. They are grouped by `group` into
     collapsible sections. The progress panel shows the counts and the two targets, coloured when met. Filters
     are all, unknown, real and bogus, plus a search box over id, claim and fix subject. The hint reads "hint,
     not a label". Each diff is collapsed behind an expand button. The empty corpus is safe.
   - **Label buttons** (`.lbl`). `mousedown` calls `preventDefault()`, so the button never takes focus. The
     click handler, in this order: `if (!e.isTrusted) return;`, `if (e.detail === 0) return; // mut:detail`,
     return if the card is hidden or its group is collapsed, `e.currentTarget.blur()`, set `target` to the
     card's id, then `postLabel(id, value)`. `postLabel` sets `data-pending="1"` and disables every `.lbl`
     while in flight. It sends `fetch('/label', {method: 'POST', headers: {'Content-Type':
     'application/json', 'X-Label-Token': token}, body: JSON.stringify({id, value, version})})`. On 200 it
     stores the new version and the label, then calls `afterLabel()`. On 409 it shows "labels.tsv changed on
     disk; reloading" and calls `location.reload()` after about 1 s. Any other status shows the error and writes
     nothing. It ends with `data-pending="0"`.
   - **`afterLabel()`**: `refresh(); // mut:refresh-first` (applies filters, search and collapses, so the
     labelled card may now be hidden). If the target is now hidden, it becomes the next visible card after it
     in row order, else the previous, else `null`. Then `scrollToTarget(); // mut:scroll`. Both anchored lines
     are adjacent, in this order. `refresh()` runs before any scroll, so hiding the labelled card cannot pull the
     new target off screen (label-ui FAIL 3).
   - **`scrollToTarget()`** scrolls only when the target is not on screen (the definition in edit 2). It uses
     `scrollIntoView({block: 'nearest'})` with `scroll-margin-top` equal to the sticky header's height, then
     corrects by the remaining offset, so the target never ends under the header.
   - **Keys** (document `keydown`; first line `var k = e.key; // mut:keys`): ignore events from the search box,
     with a modifier, or with `e.repeat`. `j` and `k` only: if `target` is `null` or not on screen, `target`
     becomes the first on-screen card and nothing else moves; otherwise it moves to the next or previous
     visible card, then `scrollToTarget()`. No key ever calls `postLabel`. There is no r/b/u, no import, and no
     download or copy control.
   - **Filter, search and collapse** call `refresh()`. If the target becomes hidden, `target` becomes `null`
     (no silent snap to some other card). The next `j` or `k` picks an on-screen card.
   - A mouse click on a card body (not a button) sets `target` to that card.
6. command: `git rm -q eval/refutation-replay/label-ui.py tests/refutation-label-ui.test.sh`
   expect: 0
   If git refuses because of the uncommitted edits, use `git rm -qf` once you have read them in edit 0. This
   deletion is the retirement: the user chose the server only, with no second labeling path. A read-only
   export is not kept, because labels are already a plain file in the working tree and `git diff` shows them.
7. file: `eval/refutation-replay/README.md`
   anchor: line matching ``| `build-corpus.py` | rfp-u2 | builds, checks and prints the label checklist for the corpus |``
   After that row, add rows for `label.py` (rfp-u2c: the Gate G1 labeling server) and `label_page.html` (rfp-u2c:
   its page template). Change the `labels.tsv` row's "written by" cell to: the builder writes `unknown`; **a
   human** sets `real` or `bogus` with `label.py serve` (or by hand).
8. file: `eval/refutation-replay/README.md`
   anchor: line matching ``1. `python3 eval/refutation-replay/build-corpus.py --labels` prints one checklist entry per row: the claim,``
   Replace step 1 (up to, not including, `2. `) with the one-command flow. Its first line names the command in
   one code span: `` `python3 eval/refutation-replay/label.py serve` `` (with `--no-open` on a headless
   machine and `--port <n>` for a fixed port). It must say:
   - the server prints `label: http://127.0.0.1:<port>/?t=<token>` and opens it when it can;
   - you read each card's evidence and click real or bogus (unknown undoes); the keyboard only navigates (j/k);
   - each click writes that one line of `eval/refutation-replay/labels.tsv` in your working tree at once, and
     there is no export step;
   - Ctrl-C stops the server;
   - review `git diff eval/refutation-replay/labels.tsv`; `build-corpus.py --check` must print
     `unlabeled=0`; then commit `labels.tsv` yourself;
   - `build-corpus.py --labels` remains the plain-text checklist;
   - an agent must not set the labels (keep the existing sentence).
   Then add a section `## Labeling server: what it does and does not protect` with these points:
   - bound to 127.0.0.1;
   - foreign Host and Origin refused (DNS rebinding);
   - a per-launch token in the URL and on every write;
   - one validated, atomic, version-checked line per click;
   - a local write log at `.git/refutation-label-writes.log`, never committed;
   - it does **not** stop a local process that can read the URL or the token, or that edits the file directly,
     an agent included. That control is process-level, and the human's own commit of `labels.tsv` is the
     record.
9. file: `tests/validate.sh`
   anchor: line matching `echo "== review-precheck: the reviewer's mechanical pre-review, failure lines are FAIL grounds (Bash, st-u2) =="`
   indent: 0
   insert-before:
~~~
echo "== refutation-label: the Gate G1 labeling server, its write checks and a real-browser probe (Bash, rfp-u2c) =="
if out="$(bash tests/refutation-label.test.sh 2>&1)"; then
  echo "OK   tests/refutation-label.test.sh"
else
  echo "FAIL tests/refutation-label.test.sh"
  fail=1
fi
printf '%s\n' "$out" | grep '^SKIP' || true

echo
~~~
   It lands right after rfp-u2b's `refutation-replay-isolation` block. The forwarded `SKIP !!!` line is
   counted by validate.sh's own "skipped checks" summary (`tests/validate.sh:57-58`), so a skipped browser probe
   is loud in every validate run.
10. command: `git add tests/refutation-label-server.py tests/refutation-label-browser.js tests/refutation-label.test.sh && git commit -m "test(rfp-u2c): red suite for the Gate G1 labeling server and its browser probe"` (after edits 1 to 3), then `git add eval/refutation-replay/label.py eval/refutation-replay/label_page.html eval/refutation-replay/README.md tests/validate.sh && git commit -m "feat(rfp-u2c): localhost labeling server writes Gate G1 clicks straight into labels.tsv; retire label-ui"` (after edits 4 to 9; the `git rm` from edit 6 is already staged)
   expect: 0
   Run `git status --short` before each commit. If a tracked file outside "Affected files" is modified, stop and
   report it. Every commit subject carries `(rfp-u2c)`, and every fix-round commit is `fix(rfp-u2c): …`, staged
   by explicit path. No version bump (see "Affected files"). End with `git status --short -- eval tests` empty.

## Do NOT touch
- `eval/refutation-replay/labels.tsv` and `eval/refutation-replay/corpus.jsonl`. Never start `label.py serve`
  on them except as criterion 4 does (on copies), and never POST to a server that points at them. The labels
  are the human's (README: an agent must not set them). An all-`real` file the human exported with the old
  page is outside the repository, pending the user's confirmation: never import, copy or assume it.
- `eval/refutation-replay/report.jsonl`: it must not exist. Never run `run.sh` without `--dry-run`, and never
  run `claude` or any paid model.
- `eval/refutation-replay/score.py`, including its thresholds (`MIN_REAL`, `MAX_MISSES`, `MAX_TURNS`,
  `MAX_UNANSWERED`). Read `MIN_REAL`; never edit it.
- `eval/refutation-replay/run.sh`, `eval/refutation-replay/guard.py` and `eval/refutation-replay/build-corpus.py`.
- `tests/refutation-replay.test.sh`, `tests/refutation-replay-isolation.test.sh` and `bin/refutation-brief.sh`.
- `agents/`, `templates/`, `hooks/`, `adapters/`, `bin/`, `.claude/` and the persona config. `labels.tsv` is
  not added to `protectedPaths` here (a named follow-up, plan Out of scope 7). Nothing here reads the
  reviewed-markers directory.

## Acceptance criteria
Every expected stdout is one line (`review-precheck.sh` compares a criterion's whole stdout with one backtick
literal). Criteria 1 to 3 need the real browser; on this machine the miniforge playwright driver and
`~/.cache/ms-playwright/chromium_headless_shell-1234` provide it.
1. run: `bash -c 'LABEL_UI_REQUIRE_BROWSER=1 bash tests/refutation-label.test.sh >/dev/null 2>&1; echo $?'` (Bash tool timeout 600000 ms)
   exit: 0
   stdout: `0`
   mutation: any mutation in criterion 3's table; or make the server write a label at startup (stdout `1`, S01).
2. run: `bash -c 'o=$(LABEL_UI_REQUIRE_BROWSER=1 bash tests/refutation-label.test.sh 2>/dev/null); echo "$(printf "%s\n" "$o" | sed -n "s/^ok - \([SBD][0-9][0-9]\) .*/\1/p" | sort -u | paste -sd, -) fail=$(printf "%s\n" "$o" | grep -c "^FAIL") skip=$(printf "%s\n" "$o" | grep -c "^SKIP")"'` (Bash tool timeout 600000 ms)
   exit: 0
   stdout: `B01,B02,B03,B04,B05,B06,B07,B08,B09,B10,B11,D01,S01,S02,S03,S04,S05,S06,S07,S08,S09,S10,S11,S12,S13,S14,S15,S16 fail=0 skip=0`
   mutation: drop a case from the suite (its ID leaves the list), or run with no browser (the B IDs leave the list and `skip=1`).
3. run: `bash -c 'L=eval/refutation-replay; t=$(mktemp -d); trap "rm -rf $t" EXIT; mk() { rm -rf "$t/w"; mkdir -p "$t/w/$L" "$t/w/tests"; cp "$L/label.py" "$L/label_page.html" "$L/README.md" "$t/w/$L/" && cp tests/refutation-label.test.sh tests/refutation-label-server.py tests/refutation-label-browser.js "$t/w/tests/"; }; st() { LABEL_UI_REQUIRE_BROWSER=1 bash "$t/w/tests/refutation-label.test.sh" > "$t/o" 2>/dev/null; }; del() { sed -i "/$1/d" "$f"; }; m_host() { del "# mut:host"; }; m_origin() { del "# mut:origin"; }; m_token() { del "# mut:token"; }; m_version() { del "# mut:version"; }; m_atomic() { sed -i "s/os\.replace(tmp, path)  # mut:atomic/open(path, \"w\").write(open(tmp).read()); os.unlink(tmp)/" "$f"; }; m_detail() { del "\/\/ mut:detail"; }; m_keys() { sed -i "/\/\/ mut:keys/a if (e.key === \"r\" \&\& target) postLabel(target, \"real\");" "$f"; }; m_order() { awk "/\/\/ mut:refresh-first/{h=\$0; next} {print} /\/\/ mut:scroll/{print h}" "$f" > "$t/x" && cat "$t/x" > "$f"; }; mut() { mk; f="$t/w/$L/$2"; cp "$f" "$t/orig"; "m_$1"; if cmp -s "$f" "$t/orig"; then r=noanchor; elif st; then r=green; elif grep -q "^FAIL - $3 " "$t/o"; then r=red; else r=other; fi; printf " %s=%s" "$1" "$r"; }; mk; if st && ! grep -qE "^(FAIL|SKIP)" "$t/o"; then printf base=pass; else printf base=fail; fi; mut host label.py S04; mut origin label.py S05; mut token label.py S03; mut version label.py S08; mut atomic label.py S09; mut detail label_page.html B04; mut keys label_page.html B05; mut order label_page.html B06; echo'` (Bash tool timeout 600000 ms; it runs the suite 9 times, so it may need a second call with the per-mutation runs split if the ceiling is hit)
   exit: 0
   stdout: `base=pass host=red origin=red token=red version=red atomic=red detail=red keys=red order=red`
   mutation: this criterion is the mutation run. A missing anchor prints `noanchor`, a check the suite does not catch prints `green`, and a case that fails for an unrelated reason while the named case passes prints `other`. spec-master ran it on today's tree, which has no `label.py`, and it printed `base=fail` and no `red`.
4. run: `bash -c 't=$(mktemp -d); cp eval/refutation-replay/corpus.jsonl eval/refutation-replay/labels.tsv "$t/"; h0=$(sha256sum < "$t/labels.tsv"); python3 eval/refutation-replay/label.py serve --no-open --port 0 --corpus "$t/corpus.jsonl" --labels "$t/labels.tsv" --log "$t/w.log" > "$t/out" 2>&1 & p=$!; for i in $(seq 50); do grep -q "^label: http://127\.0\.0\.1:[0-9]*/?t=" "$t/out" && break; sleep 0.2; done; u=$(sed -n "s/^label: \(http:[^ ]*\)$/\1/p" "$t/out"); n=$(python3 -c "import sys, re, urllib.request; print(re.search(r\"data-rows=.([0-9]+)\", urllib.request.urlopen(sys.argv[1]).read().decode()).group(1))" "$u" 2>/dev/null); kill -TERM $p 2>/dev/null; wait $p; rc=$?; [ "$(sha256sum < "$t/labels.tsv")" = "$h0" ] && w=0 || w=1; echo "rows=${n:-none} written=$w log=$(test -s "$t/w.log" && echo nonempty || echo empty) exit=$rc files=$(ls "$t" | paste -sd, -) tree=$(git status --porcelain -- eval/refutation-replay | wc -l)"; rm -rf "$t"'`
   exit: 0
   stdout: `rows=41 written=0 log=empty exit=0 files=corpus.jsonl,labels.tsv,out tree=0`
   mutation: make startup rewrite the labels file (`written=1`), create the log at startup (`files=` gains `w.log`), or exit 1 on SIGTERM (`exit=1`). On today's tree it prints `rows=none written=0 log=empty exit=2 … tree=1` (spec-master ran it).
5. run: `bash -c 'echo "tracked=$(git ls-files eval/refutation-replay/label-ui.py tests/refutation-label-ui.test.sh | wc -l) refs=$(grep -lF "label-ui" eval/refutation-replay/README.md eval/refutation-replay/label.py eval/refutation-replay/label_page.html tests/validate.sh tests/refutation-label.test.sh tests/refutation-label-server.py tests/refutation-label-browser.js 2>/dev/null | wc -l) model=$(grep -liE "claude|anthropic|https://" eval/refutation-replay/label.py eval/refutation-replay/label_page.html tests/refutation-label-server.py tests/refutation-label-browser.js tests/refutation-label.test.sh 2>/dev/null | wc -l)"'`
   exit: 0
   stdout: `tracked=0 refs=0 model=0`
   mutation: keep `label-ui.py` tracked (`tracked=1`), or name a `claude` call in `label.py` (`model=1`).
6. run: `bash -c 's=$(awk "/^## Gate G/{g=1} g&&/^1\. /{p=1} g&&/^2\. /{exit} p" eval/refutation-replay/README.md); h=$(python3 eval/refutation-replay/label.py serve --help 2>&1); m=0; for f in $(printf "%s\n" "$s" | grep -oE "label\.py serve[^\x60]*" | grep -oE -- "--[a-z][a-z-]*" | sort -u); do printf "%s" "$h" | grep -qF -- "$f" || m=$((m+1)); done; c=0; printf "%s" "$s" | grep -qF "python3 eval/refutation-replay/label.py serve" && c=$((c+1)); printf "%s" "$s" | grep -qF "eval/refutation-replay/labels.tsv" && c=$((c+1)); printf "%s" "$s" | grep -qiE "you commit|human commits|then commit" && c=$((c+1)); echo "claims=$c/3 missing-flags=$m label-ui=$(grep -c "label-ui" eval/refutation-replay/README.md)"'`
   exit: 0
   stdout: `claims=3/3 missing-flags=0 label-ui=0`
   mutation: name a `--host` option on the step 1 line (`missing-flags=1`), or drop the labels path from step 1 (`claims=2/3`). On today's README it prints `claims=1/3` (spec-master ran it).
7. run: `bash -c 'c=$(git log --format=%H --fixed-strings --grep="(rfp-u2c)"); [ -n "$c" ] || { echo no-commits; exit 1; }; for x in $c; do git show --name-only --format= "$x"; done | sort -u | grep -vxE "eval/refutation-replay/(label\.py|label_page\.html|README\.md|label-ui\.py)|tests/(refutation-label\.test\.sh|refutation-label-server\.py|refutation-label-browser\.js|refutation-label-ui\.test\.sh|validate\.sh)" | wc -l'`
   exit: 0
   stdout: `0`
   mutation: touch `score.py` or `labels.tsv` in an `(rfp-u2c)` commit (stdout `1`). On an empty range stdout is `no-commits` and the exit is 1. Only this unit's own commits are read.
8. run: `bash -c 'c=$(git log --format=%H --fixed-strings --grep="(rfp-u2c)"); [ -n "$c" ] || { echo no-commits; exit 1; }; n=$(for x in $c; do git show --name-only --format= "$x"; done | grep -cxE "eval/refutation-replay/(labels\.tsv|corpus\.jsonl|report\.jsonl)"); echo "touched=$n dirty=$(git status --porcelain -- eval/refutation-replay/labels.tsv eval/refutation-replay/corpus.jsonl | wc -l) check=$(python3 eval/refutation-replay/build-corpus.py --check | grep -o "errors=[0-9]*")"'`
   exit: 0
   stdout: `touched=0 dirty=0 check=errors=0`
   mutation: commit a label change in an `(rfp-u2c)` commit (`touched=1`), or leave one uncommitted (`dirty=1`). This deliberately does not pin `unlabeled=41`: the human may commit labels before this unit is reviewed.
9. run: `bash -c 'o=$(LABEL_UI_NO_BROWSER_SEARCH=1 bash tests/refutation-label.test.sh 2>/dev/null); a=$?; LABEL_UI_NO_BROWSER_SEARCH=1 LABEL_UI_REQUIRE_BROWSER=1 bash tests/refutation-label.test.sh >/dev/null 2>&1; b=$?; echo "skip=$(printf "%s\n" "$o" | grep -c "^SKIP !!! no playwright plus Chromium found") rc=$a required-rc=$b browser-ok=$(printf "%s\n" "$o" | grep -c "^ok - B")"'` (Bash tool timeout 600000 ms)
   exit: 0
   stdout: `skip=1 rc=0 required-rc=1 browser-ok=0`
   mutation: make the skip path silent (`skip=0`), or let `LABEL_UI_REQUIRE_BROWSER` pass without a browser (`required-rc=0`).
10. run: `bash -c 'git ls-files -s eval/refutation-replay/label.py eval/refutation-replay/label_page.html tests/refutation-label-browser.js tests/refutation-label-server.py tests/refutation-label.test.sh | cut -c1-6 | paste -sd, -'`
   exit: 0
   stdout: `100755,100644,100644,100644,100755`
   mutation: commit `label.py` at mode 644 (the first field reads `100644`), or leave a file untracked (a field is missing). `git ls-files` sorts by path: `label.py`, `label_page.html`, `refutation-label-browser.js`, `refutation-label-server.py`, `refutation-label.test.sh`.
11. run: `bash -c 'ANTISLOP_VALIDATE_LANES=4 bash tests/validate.sh >/dev/null 2>&1; echo $?'` (Bash tool timeout 600000 ms)
   exit: 0
   stdout: `0`
   mutation: put `exit 1` as line 2 of `tests/refutation-label.test.sh`; validate.sh reports it (edit 9) and stdout is `1`.
12. run: `bash -c 'git status --porcelain -- eval tests | wc -l'`
   exit: 0
   stdout: `0`
   mutation: leave the edit-0 WIP or a fixture file in the tree (stdout `1` or more). Today it prints `2` (the cancelled label-ui edits).

## Pre-resolved context
tdd: yes (edits 1 to 3 write the suite first, and it must exit 1 before label.py exists)
blast-radius: tests/validate.sh:841-848 (rfp-u2b's block; the new block goes right after it) is the only existing file that gains a line (one registration block after rfp-u2b's); no shipped consumer reads eval/ (export-ignore), and label-ui was never registered
commit-message: test(rfp-u2c): red suite for the Gate G1 labeling server and its browser probe; then feat(rfp-u2c): localhost labeling server writes Gate G1 clicks straight into labels.tsv; retire label-ui
diagnosis: none
- **Why label-ui is superseded, not fixed** (`.claude/reviewed/label-ui.fail`, 3 blocks, tiers sonnet, sonnet,
  opus):
  1. r/b/u wrote onto a card hidden by search or filter.
  2. The re-snap moved `cur` to the page's first visible card with no scroll, and the next key wrote onto it.
  3. A label button kept focus, so Space or Enter re-fired it on an off-screen card. Separately,
     `scrollIntoView` ran before `refresh()` hid the labelled card, so the auto-advanced target ended above the
     viewport or under the header.

  Every failure was a write path other than a mouse click on a visible button. This unit removes those paths
  instead of guarding them: no key writes, buttons never hold focus, untrusted and `detail === 0` clicks are
  dropped, a hidden target becomes `null` instead of snapping, and `refresh()` runs before the scroll. The
  probe's invariant (the file changes only on a trusted mouse click on an on-screen button) is checked after
  every step, so a write path nobody thought of still turns B09 red.
- **The server's integrity design.**
  - *Version* = sha256 of the file bytes. It catches a stale tab, a second server, a hand edit, and a `git
    checkout` that changed the file. The page reloads on 409.
  - *Lock* = one `threading.Lock` per server process. Two servers on the same file are serialized only by the
    version check, which leaves a sub-millisecond window between the hash and the rename. That is accepted:
    the human runs one server.
  - *One line per write.* The file is not re-serialized, so the header, the order and any byte the server does
    not own survive by construction.
  - *Atomic.* A temp file in the same directory, fsync, `os.replace`, then a directory fsync. `mkstemp` creates
    the file at 0600, so the old mode is copied first.
- **Why no committed marker or attestation.** Anything the server could commit (a signed log, a marker file)
  can be produced just as easily by any local process that can run `label.py` or hold the token, an agent
  included. It would add a file and buy no evidence. The cheapest real evidence is the local write log (one
  JSON line per POST, with the browser's User-Agent and Origin). It is kept outside the tree so it never
  becomes ambient dirt. The human's commit of `labels.tsv` stays the record.
- **The token in the URL** (Jupyter-style) means a local process that did not see the printed URL cannot fetch
  the page, so it cannot learn the token through GET. It does not stop a process that reads the terminal, the
  browser history or the file itself. The README says so (edit 8).
- **Opening the browser on WSL.** This machine is WSL2 with `/mnt/c/Windows/explorer.exe` on `PATH` and no
  `wslview`. S14 runs with `PATH` set to fake openers first, so the suite never opens a real Windows browser.
  Every other suite and probe run uses `--no-open`.
- **Playwright on this machine**:
  - Node v22.23.1.
  - Drivers: `$HOME/miniforge3/envs/claude_voice/lib/python3.11/site-packages/playwright/driver/package` and
    the `recipe_llm` env's driver.
  - Browsers: `~/.cache/ms-playwright/chromium-1234` and `chromium_headless_shell-1234`. label-ui's reviewer
    reproduced its FAIL 3 in exactly this setup.
  - There is no Python `playwright` module in the default `python3`, which is why the probe is Node.
  - jsdom is not used. It has no layout and no focus routing, which is why label-ui's jsdom probe missed
    FAIL 3.
- **Runtime.** The probe's 200 steps should take well under a minute. The wrapper caps each candidate at
  `timeout 540`. validate.sh at 4 lanes took about 250 s at rfp-u2b. If adding this suite pushes a lane past the
  600 s hook timeout, report it (spec-master memory: gate runtime vs hook timeout); do not lower the step count
  below 200 on your own authority.
- **validate.sh lanes.** The default lane count is known to flake at this baseline (rfp-u2b's PASS notes:
  `hook-latency-budget` p99). `ANTISLOP_VALIDATE_LANES=4` is the safe setting (criterion 11).
- **Expected size and tier.** About 5 new files and 1 600 to 2 000 lines, security-sensitive, on files whose
  predecessor holds 3 FAIL blocks. This exceeds the small lane, so expect `unit-size.sh` to print `full`.
  Expected implementer tier: **opus**. label-ui spent sonnet twice and opus once on this defect class, and the
  Implementer-tier ratchet does not allow a cheaper tier for the re-scoped work.
- **Criteria provenance.** No payload exists, so spec-master could not run criteria 1 to 3 and 9 to 11 green.
  It checked every criterion with `bash -n`. On today's tree it ran 3 to 8, 10 and 12, and each fails as
  stated: 3 prints `base=fail`, 5 `tracked=2`, 7 and 8 `no-commits` (exit 1), 10 an empty line, 12 `2`. It ran each criterion-3 sed and awk mutation on a dummy file holding the anchor
  lines, and each changes exactly the anchored line as the table says.

## Escalation
- If `writer-scope-gate.sh` blocks your stop with a "changes outside your dispatch's unit scope" message that
  names a file listed in "Affected files" (it has falsely named `tests/refutation-label-ui.test.sh` before),
  report the block verbatim to your dispatcher and wait. Do **not** run the `git checkout` it suggests, and do
  not edit the gate.
- If no playwright driver or Chromium launches in your environment, so that criteria 1 to 3 cannot run green,
  stop and report it. Do not install anything, and do not weaken `LABEL_UI_REQUIRE_BROWSER`.
- If a trusted-input scenario cannot be made deterministic in headless Chromium (for example, wheel scrolling
  that lands differently on each run), report the scenario and what you measured. Do not drop the case.
- If any gate blocks a command, report it and wait.
- Anything outside "Affected files" goes in your report as a proposal, not an edit.
