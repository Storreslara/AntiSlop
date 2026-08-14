#!/usr/bin/env node
'use strict';

// Regression coverage for gh348-10 (finding N1): CONTEXT.md's "Protocol
// excerpt" entry and .claude/wiki/protocol-delivery-tiers.md each hardcode
// the canonical-section count for the full-tier and slim-tier protocol
// templates in prose. Nothing previously asserted those prose counts still
// matched the live `## `-delimited section count in the templates
// themselves, so a template edit that added/removed a section could leave
// both docs silently stale (exactly what happened before d41ebd7).

const assert = require('assert');
const fs = require('fs');
const path = require('path');

const REPO_ROOT = path.resolve(__dirname, '..');

let failures = 0;

function check(name, fn) {
  try {
    fn();
    console.log(`OK   ${name}`);
  } catch (err) {
    console.log(`FAIL ${name}: ${err.message}`);
    failures++;
  }
}

function liveSectionCount(templateRelPath) {
  const text = fs.readFileSync(path.join(REPO_ROOT, templateRelPath), 'utf8');
  return (text.match(/^## /gm) || []).length;
}

const contextMd = fs.readFileSync(path.join(REPO_ROOT, 'CONTEXT.md'), 'utf8');
const wikiMd = fs.readFileSync(path.join(REPO_ROOT, '.claude/wiki/protocol-delivery-tiers.md'), 'utf8');

const liveFullCount = liveSectionCount('templates/persona-protocol.md');
const liveSlimCount = liveSectionCount('templates/persona-protocol-slim.md');

check('CONTEXT.md "Protocol excerpt" entry\'s full-tier count matches templates/persona-protocol.md', () => {
  const excerptStart = contextMd.indexOf('**Protocol excerpt**:');
  assert.ok(excerptStart !== -1, 'CONTEXT.md has no "Protocol excerpt" entry');
  const excerptText = contextMd.slice(excerptStart, excerptStart + 400);
  const m = excerptText.match(/`templates\/persona-protocol\.md`'s (\d+)\s+`## `-delimited canonical sections/);
  assert.ok(m, 'could not find the "...\'s N `## `-delimited canonical sections" claim in the Protocol excerpt entry');
  const documented = Number(m[1]);
  assert.strictEqual(
    documented,
    liveFullCount,
    `CONTEXT.md documents ${documented} full-tier sections, but templates/persona-protocol.md has ${liveFullCount}`,
  );
});

check('wiki "Full tier" bullet count matches templates/persona-protocol.md', () => {
  const twoFilesStart = wikiMd.indexOf('## The two files');
  const howInliningStart = wikiMd.indexOf('## How inlining works');
  assert.ok(twoFilesStart !== -1 && howInliningStart !== -1, 'wiki is missing expected "## The two files" / "## How inlining works" headers');
  const twoFilesText = wikiMd.slice(twoFilesStart, howInliningStart);
  const m = twoFilesText.match(/\*\*Full tier\*\*[\s\S]*?- (\d+) sections:/);
  assert.ok(m, 'could not find the Full tier "- N sections:" bullet in the wiki');
  const documented = Number(m[1]);
  assert.strictEqual(
    documented,
    liveFullCount,
    `wiki documents ${documented} full-tier sections, but templates/persona-protocol.md has ${liveFullCount}`,
  );
});

check('wiki "Slim tier" bullet count matches templates/persona-protocol-slim.md', () => {
  const twoFilesStart = wikiMd.indexOf('## The two files');
  const howInliningStart = wikiMd.indexOf('## How inlining works');
  assert.ok(twoFilesStart !== -1 && howInliningStart !== -1, 'wiki is missing expected "## The two files" / "## How inlining works" headers');
  const twoFilesText = wikiMd.slice(twoFilesStart, howInliningStart);
  const m = twoFilesText.match(/\*\*Slim tier\*\*[\s\S]*?- (\d+) sections:/);
  assert.ok(m, 'could not find the Slim tier "- N sections:" bullet in the wiki');
  const documented = Number(m[1]);
  assert.strictEqual(
    documented,
    liveSlimCount,
    `wiki documents ${documented} slim-tier sections, but templates/persona-protocol-slim.md has ${liveSlimCount}`,
  );
});

if (failures) {
  console.log(`\n${failures} protocol-doc-drift check(s) FAILED.`);
  process.exit(1);
}
console.log('\nAll protocol-doc-drift checks passed.');
