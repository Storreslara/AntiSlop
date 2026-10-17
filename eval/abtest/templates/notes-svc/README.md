# notes-svc

A zero-dependency notes service (Node 18 or newer, no install step).

## Routes

| Method | Path | Behaviour |
|---|---|---|
| GET | `/notes` | The caller's notes, paged with `limit` and `cursor`; `title=<text>` keeps exact matches |
| POST | `/notes` | Create a note from a JSON body `{title, body}`; 400 without a title |
| DELETE | `/notes/:id` | Delete one of the caller's notes; 404 for any other id |

Every route needs `Authorization: Bearer <token>`; a missing or unknown token is a 401.

## Commands

- `npm test` runs the test suite.
- `node src/server.js` serves on `PORT` (default 3000).
- `node src/cli.js list [--title <text>]` lists notes; `NOTES_SEED=<file>` seeds the store from a JSON array.
- `node scripts/export.js` prints all notes as JSON.
