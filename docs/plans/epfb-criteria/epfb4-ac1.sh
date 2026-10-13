#!/usr/bin/env bash
# epfb-4 AC4.1 (item g): parseProtocolSections handles an inline code span, a
# CRLF closer, an unclosed fence and a tilde info string, and round-trips.
D=$(cd "$(dirname "$0")" && pwd); . "$D/../epf-criteria/lib.sh"
node -e '
const c = require("./bin/cli.js");
const cases = [
  ["pre\n## A\n```x``` is inline code\n## B", ["A", "B"]],
  ["pre\r\n## A\r\n```\r\n## not a header\r\n```\r\n## B\r\n", ["A", "B"]],
  ["pre\n## A\n```\n## swallowed\n## also swallowed", ["A"]],
  ["pre\n## A\n~~~ `tilde info may hold backticks`\n## not a header\n~~~\n## B", ["A", "B"]],
];
for (const [t, want] of cases) {
  const r = c.parseProtocolSections(t);
  if (JSON.stringify(r.sections.map((s) => s.header)) !== JSON.stringify(want)) { console.log("headers", JSON.stringify(t)); process.exit(1); }
  if ([r.preamble, ...r.sections.map((s) => s.text)].join("\n") !== t) { console.log("round-trip", JSON.stringify(t)); process.exit(1); }
}'
