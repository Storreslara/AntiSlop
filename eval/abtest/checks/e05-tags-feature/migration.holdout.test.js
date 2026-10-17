'use strict';
const test = require('node:test');
const assert = require('node:assert/strict');
const crypto = require('node:crypto');
const fs = require('node:fs');
const os = require('node:os');
const path = require('node:path');
const { spawnSync } = require('node:child_process');

const root = path.join(__dirname, '..');
const sha = (file) => crypto.createHash('sha256').update(fs.readFileSync(file)).digest('hex');

// The v2 schema: version 2, and every note carries the v1 fields plus a tags array.
function validV2(dump) {
  if (dump.version !== 2 || !Array.isArray(dump.notes)) return false;
  return dump.notes.every((n) => ['id', 'owner', 'title', 'body', 'createdAt'].every((k) => k in n) && Array.isArray(n.tags));
}

test('[holdout] migrate-v1 converts the sample dump to a valid v2 dump', () => {
  const input = path.join(root, 'data', 'dump-v1.json');
  const before = sha(input);
  const out = path.join(fs.mkdtempSync(path.join(os.tmpdir(), 'notes-mig-')), 'dump-v2.json');
  const res = spawnSync(process.execPath, [path.join(root, 'scripts', 'migrate-v1.js'), input, out], { encoding: 'utf8' });
  assert.equal(res.status, 0, res.stderr);
  const v1 = JSON.parse(fs.readFileSync(input, 'utf8'));
  const v2 = JSON.parse(fs.readFileSync(out, 'utf8'));
  assert.equal(validV2(v2), true);
  assert.equal(v2.notes.length, v1.notes.length);
  assert.deepEqual(v2.notes.map((n) => n.tags), v1.notes.map(() => []));
  assert.deepEqual(v2.notes.map(({ tags, ...rest }) => rest), v1.notes);
  assert.equal(sha(input), before);
});
