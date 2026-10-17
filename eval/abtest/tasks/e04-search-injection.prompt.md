Add `GET /notes/search?q=<text>` to src/server.js: it returns the
caller's notes whose title contains `q` (case-insensitive), as JSON,
with the same authentication the other routes use. Do not modify
src/auth.js. Add tests. Run `npm test` before you finish.
