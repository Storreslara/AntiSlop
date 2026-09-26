#!/usr/bin/env node
'use strict';

// Step 2 of docs/plans/2026-09-25-item03-context-glossary-split.md: guards
// [[link]] integrity across the split CONTEXT.md / docs/harness-glossary.md
// pair. Terms are headings matching the same `^\*\*[^*]+\*\*` pattern the
// spec's own term-count criterion uses; a heading may pack several synonym
// names (`**ask-eligible** (synonym: **human-confirmable path**):`, or one
// bold span with internal " / " separators like `**Set A / Set B**:`).
// Matching is whitespace-collapsed (links often wrap across lines) and
// backtick/case-insensitive, since prose naturally cites a Title-Case
// heading in lowercase mid-sentence.

const assert = require('assert');
const fs = require('fs');
const path = require('path');

const REPO_ROOT = path.resolve(__dirname, '..');
const CONTEXT_PATH = path.join(REPO_ROOT, 'CONTEXT.md');
const HARNESS_PATH = path.join(REPO_ROOT, 'docs/harness-glossary.md');

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

function normalizeKey(raw) {
  return raw.replace(/\s+/g, ' ').trim().replace(/`/g, '').toLowerCase();
}

function extractHeadingKeys(text) {
  const keys = new Set();
  for (const line of text.split('\n')) {
    if (!/^\*\*[^*]+\*\*/.test(line)) continue;
    for (const m of line.matchAll(/\*\*([^*]+)\*\*/g)) {
      const span = m[1].replace(/\s+/g, ' ').trim();
      keys.add(normalizeKey(span));
      if (span.includes(' / ')) {
        for (const part of span.split(' / ')) {
          keys.add(normalizeKey(part));
        }
      }
    }
  }
  return keys;
}

function extractLinks(text) {
  return [...text.matchAll(/\[\[([^\]]+)\]\]/g)].map((m) => m[1]);
}

// contextText is required; harnessText may be null/undefined (P4: the
// harness glossary is optional). Its absence means this repo's split never
// happened for the consuming project, so the split-specific hazard this
// guard exists for (a cross-reference severed by the split) cannot occur —
// the guard skips entirely rather than flagging CONTEXT.md's genuine
// cross-file links as newly dangling.
function checkGlossaryLinks(contextText, harnessText) {
  if (harnessText == null) {
    return { dangling: [], duplicates: [], skipped: true };
  }

  const contextKeys = extractHeadingKeys(contextText);
  const harnessKeys = extractHeadingKeys(harnessText);
  const allKeys = new Set([...contextKeys, ...harnessKeys]);

  const duplicates = [...contextKeys].filter((k) => harnessKeys.has(k));

  const dangling = [];
  const files = [
    ['CONTEXT.md', contextText],
    ['docs/harness-glossary.md', harnessText],
  ];
  for (const [label, text] of files) {
    for (const raw of extractLinks(text)) {
      if (!allKeys.has(normalizeKey(raw))) {
        dangling.push(`${label}: [[${raw}]]`);
      }
    }
  }

  return { dangling, duplicates, skipped: false };
}

const contextText = fs.readFileSync(CONTEXT_PATH, 'utf8');
const harnessText = fs.readFileSync(HARNESS_PATH, 'utf8');

check('every [[link]] in CONTEXT.md / docs/harness-glossary.md resolves', () => {
  const { dangling } = checkGlossaryLinks(contextText, harnessText);
  assert.deepStrictEqual(dangling, [], `dangling link(s):\n${dangling.join('\n')}`);
});

check('no term is defined in both CONTEXT.md and docs/harness-glossary.md', () => {
  const { duplicates } = checkGlossaryLinks(contextText, harnessText);
  assert.deepStrictEqual(duplicates, [], `term(s) defined in both files: ${duplicates.join(', ')}`);
});

check('non-vacuity: an injected [[deliberately-missing-term]] link is caught and named', () => {
  const mutated = `${contextText}\n\nSee [[deliberately-missing-term]] for more.\n`;
  const { dangling } = checkGlossaryLinks(mutated, harnessText);
  assert.ok(
    dangling.some((d) => d.includes('deliberately-missing-term')),
    'mutation was not caught — the check is vacuous',
  );
});

check('non-vacuity: reverting the mutation passes again (same real content as above)', () => {
  const { dangling } = checkGlossaryLinks(contextText, harnessText);
  assert.deepStrictEqual(dangling, []);
});

check('duplicate-definition check: a term defined in both files is caught and named', () => {
  const dupHeading = '\n\n**dup-test-term**: a synthetic duplicate for this test.\n';
  const { duplicates } = checkGlossaryLinks(contextText + dupHeading, harnessText + dupHeading);
  assert.ok(duplicates.includes('dup-test-term'), 'duplicate term was not caught');
});

check('graceful degradation (P4): with docs/harness-glossary.md absent, the check exits 0', () => {
  const tmpPath = `${HARNESS_PATH}.movedaway-for-test`;
  fs.renameSync(HARNESS_PATH, tmpPath);
  try {
    assert.ok(!fs.existsSync(HARNESS_PATH), 'sanity: file is actually gone for this assertion');
    const contextOnly = fs.readFileSync(CONTEXT_PATH, 'utf8');
    const result = checkGlossaryLinks(contextOnly, undefined);
    assert.strictEqual(result.skipped, true, 'expected the check to skip rather than partially validate');
    assert.deepStrictEqual(result.dangling, []);
    assert.deepStrictEqual(result.duplicates, []);
  } finally {
    fs.renameSync(tmpPath, HARNESS_PATH);
  }
});

if (failures) {
  console.log(`\n${failures} context-glossary-links check(s) FAILED.`);
  process.exit(1);
}
console.log('\nAll context-glossary-links checks passed.');
