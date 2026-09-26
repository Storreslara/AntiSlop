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
const { spawnSync } = require('child_process');
const fs = require('fs');
const os = require('os');
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

// A `[[bracket]]` occurrence wrapped in backtick code-span delimiters
// (`` `[[example]]` ``) is illustrative syntax, not a live cross-reference —
// exclude it rather than flag it as dangling.
function extractLinks(text) {
  return [...text.matchAll(/\[\[([^\]]+)\]\]/g)]
    .filter((m) => text[m.index - 1] !== '`' || text[m.index + m[0].length] !== '`')
    .map((m) => m[1]);
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
const harnessText = fs.existsSync(HARNESS_PATH) ? fs.readFileSync(HARNESS_PATH, 'utf8') : null;

if (harnessText == null) {
  // P4: nothing below can be asserted without the second file, and its
  // absence is not an error — see checkGlossaryLinks' contract above.
  console.log('SKIP docs/harness-glossary.md absent — link-integrity checks skipped (P4)');
} else {
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

  check('a backtick-wrapped [[bracket]] is illustrative syntax, not a dangling link', () => {
    const mutated = `${contextText}\n\nSyntax looks like \`[[example-syntax-term]]\`.\n`;
    const { dangling } = checkGlossaryLinks(mutated, harnessText);
    assert.ok(
      !dangling.some((d) => d.includes('example-syntax-term')),
      'a code-span-wrapped example was flagged as a dangling link',
    );
  });

  check('the same bracket text unwrapped is still caught as dangling', () => {
    const mutated = `${contextText}\n\nSee [[example-syntax-term]] for more.\n`;
    const { dangling } = checkGlossaryLinks(mutated, harnessText);
    assert.ok(
      dangling.some((d) => d.includes('example-syntax-term')),
      'the exclusion is over-broad — it also skipped a plain (non-code-span) link',
    );
  });

  check('duplicate-definition check: a term defined in both files is caught and named', () => {
    const dupHeading = '\n\n**dup-test-term**: a synthetic duplicate for this test.\n';
    const { duplicates } = checkGlossaryLinks(contextText + dupHeading, harnessText + dupHeading);
    assert.ok(duplicates.includes('dup-test-term'), 'duplicate term was not caught');
  });
}

// Exercises the real entry point, not checkGlossaryLinks() directly: the
// module-level read is the thing that breaks when the file is absent. Runs a
// copy of this script from a sandbox repo root holding only CONTEXT.md, so
// the live tracked docs/harness-glossary.md is never touched and an
// interrupted run can strand nothing but a temp dir.
if (!process.env.GLOSSARY_LINKS_SUBPROCESS) {
  check('graceful degradation (P4): with docs/harness-glossary.md absent, this script exits 0', () => {
    const sandbox = fs.mkdtempSync(path.join(os.tmpdir(), 'glossary-links-'));
    try {
      fs.mkdirSync(path.join(sandbox, 'tests'));
      fs.copyFileSync(CONTEXT_PATH, path.join(sandbox, 'CONTEXT.md'));
      const scriptCopy = path.join(sandbox, 'tests', path.basename(__filename));
      fs.copyFileSync(__filename, scriptCopy);
      assert.ok(
        !fs.existsSync(path.join(sandbox, 'docs/harness-glossary.md')),
        'sanity: the sandbox repo root has no harness glossary',
      );
      const run = spawnSync(process.execPath, [scriptCopy], {
        encoding: 'utf8',
        env: { ...process.env, GLOSSARY_LINKS_SUBPROCESS: '1' },
      });
      assert.strictEqual(
        run.status,
        0,
        `expected exit 0 with the glossary absent, got ${run.status}:\n${run.stdout}${run.stderr}`,
      );
    } finally {
      fs.rmSync(sandbox, { recursive: true, force: true });
    }
  });
}

if (failures) {
  console.log(`\n${failures} context-glossary-links check(s) FAILED.`);
  process.exit(1);
}
console.log('\nAll context-glossary-links checks passed.');
