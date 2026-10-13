#!/usr/bin/env bash
# epf-5 AC5.1: parseProtocolSections is exported and fence-aware, and round-trips.
D=$(cd "$(dirname "$0")" && pwd); . "$D/lib.sh"
node -e '
const c = require("./bin/cli.js");
if (typeof c.parseProtocolSections !== "function") { console.log("not exported"); process.exit(1); }
const cases = [
  ["pre\n## A\n```\n## not a header\n```\n## B\nx", ["A", "B"]],
  ["pre\n## A\n~~~\n## not a header\n~~~\n## B", ["A", "B"]],
  ["pre\n## A\n````\n```\n## still fenced\n````\n## B", ["A", "B"]],
  ["pre\n## A\n  ```sh\n## inside an indented fence\n  ```\n## B", ["A", "B"]],
];
for (const [t, want] of cases) {
  const r = c.parseProtocolSections(t);
  if (JSON.stringify(r.sections.map((s) => s.header)) !== JSON.stringify(want)) { console.log("headers", JSON.stringify(t)); process.exit(1); }
  if ([r.preamble, ...r.sections.map((s) => s.text)].join("\n") !== t) { console.log("round-trip", JSON.stringify(t)); process.exit(1); }
}'
