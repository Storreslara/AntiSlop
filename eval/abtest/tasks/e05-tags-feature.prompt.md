Add tags to notes, end to end:
1. `POST /notes` accepts `tags` (array of 0–5 lowercase slugs matching
   /^[a-z0-9-]{1,20}$/; reject otherwise with 400).
2. `GET /notes?tag=<slug>` filters by tag; `node src/cli.js list --tag
   <slug>` does the same.
3. `GET /tags` returns `{tag: count}` for the caller's notes.
4. `scripts/migrate-v1.js <in> <out>` converts a v1 dump to v2 (adds
   `tags: []` to every note and sets `"version": 2`).
5. Update README.md's route table and data-format section.
6. Tests for each of the above.
Keep each part small and committed separately. Run `npm test` before
you finish.
