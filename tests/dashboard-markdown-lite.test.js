#!/usr/bin/env node
'use strict';

// Test suite for bin/microworld-dashboard/markdown-lite.js:
// Dual-environment markdown renderer (CommonJS-requirable and page-injectable).
// Covers U1-C3 cases from docs/plans/2026-08-18-dashboard-usability-revision.md.

const { renderMarkdown } = require('../bin/microworld-dashboard/markdown-lite');

const failures = [];

function check(label, fn) {
  console.log(`Test ${label}...`);
  try {
    fn();
    console.log('  ✓ ok');
  } catch (err) {
    console.log('  ✗ ' + err.message);
    failures.push(`${label} ${err.message}`);
  }
}

function assert(cond, message) {
  if (!cond) throw new Error(message);
}

function contains(text, substring) {
  assert(text.includes(substring), `expected output to contain "${substring}", got: ${text}`);
}

function notContains(text, substring) {
  assert(!text.includes(substring), `expected output NOT to contain "${substring}", got: ${text}`);
}

// Headings
check('H1 heading', () => {
  const result = renderMarkdown('# H');
  contains(result, '<h1>H</h1>');
});

check('H2 heading', () => {
  const result = renderMarkdown('## H2');
  contains(result, '<h2>H2</h2>');
});

check('H3 heading', () => {
  const result = renderMarkdown('### H3');
  contains(result, '<h3>H3</h3>');
});

check('H6 heading', () => {
  const result = renderMarkdown('###### H6');
  contains(result, '<h6>H6</h6>');
});

// Bold
check('Bold text', () => {
  const result = renderMarkdown('**b**');
  contains(result, '<strong>b</strong>');
});

// Italic
check('Italic text', () => {
  const result = renderMarkdown('*i*');
  contains(result, '<em>i</em>');
});

// Inline code
check('Inline code', () => {
  const result = renderMarkdown('`c`');
  contains(result, '<code>c</code>');
});

// Fenced code blocks
check('Fenced code block', () => {
  const result = renderMarkdown('```\ncode\n```');
  contains(result, '<pre><code>');
});

// Unordered lists
check('Unordered list', () => {
  const result = renderMarkdown('- a\n- b');
  const ulCount = (result.match(/<ul>/g) || []).length;
  assert(ulCount === 1, `expected exactly one <ul>, found ${ulCount}`);
  const liCount = (result.match(/<li>/g) || []).length;
  assert(liCount === 2, `expected exactly two <li>, found ${liCount}`);
});

// Ordered lists
check('Ordered list', () => {
  const result = renderMarkdown('1. a\n2. b');
  const olCount = (result.match(/<ol>/g) || []).length;
  assert(olCount === 1, `expected exactly one <ol>, found ${olCount}`);
  const liCount = (result.match(/<li>/g) || []).length;
  assert(liCount === 2, `expected exactly two <li>, found ${liCount}`);
});

// Blockquote
check('Blockquote', () => {
  const result = renderMarkdown('> q');
  contains(result, '<blockquote>');
});

// Horizontal rule
check('Horizontal rule', () => {
  const result = renderMarkdown('---');
  contains(result, '<hr');
});

// Paragraph
check('Paragraph', () => {
  const result = renderMarkdown('plain');
  contains(result, '<p>');
});

// XSS: HTML tags should be escaped
check('HTML tags are escaped', () => {
  const result = renderMarkdown('<img src=x onerror=alert(1)>');
  notContains(result, '<img');
});

// XSS: Ampersands escaped
check('Ampersands are escaped', () => {
  const result = renderMarkdown('a & b');
  contains(result, '&amp;');
});

// XSS: Less-than signs escaped
check('Less-than signs are escaped', () => {
  const result = renderMarkdown('a < b');
  contains(result, '&lt;');
});

// XSS: Greater-than signs escaped
check('Greater-than signs are escaped', () => {
  const result = renderMarkdown('a > b');
  contains(result, '&gt;');
});

// XSS: Quotes escaped
check('Quotes are escaped', () => {
  const result = renderMarkdown('a " b \' c');
  contains(result, '&quot;');
  contains(result, '&#39;');
});

// XSS: Mixed escaping
check('Complex string with multiple escape chars', () => {
  const result = renderMarkdown('a & b " c \' d <e>');
  contains(result, '&amp;');
  contains(result, '&lt;');
  contains(result, '&gt;');
  notContains(result, '<e>');
});

// Links with valid schemes
check('HTTPS link', () => {
  const result = renderMarkdown('[a](https://x.test/p)');
  contains(result, 'href="https://x.test/p"');
  contains(result, 'rel="noopener noreferrer"');
  contains(result, 'target="_blank"');
});

check('HTTP link', () => {
  const result = renderMarkdown('[a](http://x.test/p)');
  contains(result, 'href="http://x.test/p"');
});

check('Relative link', () => {
  const result = renderMarkdown('[a](./rel/path.md)');
  contains(result, 'href="./rel/path.md"');
});

// Links with forbidden schemes
check('JavaScript link is NOT rendered as link', () => {
  const result = renderMarkdown('[a](javascript:alert(1))');
  notContains(result, 'javascript:');
  notContains(result, 'href=');
});

// XSS: forged NUL-byte sentinel markers cannot smuggle raw HTML or bypass
// the link-scheme allowlist
check('Forged NUL marker cannot smuggle raw HTML via bold', () => {
  const result = renderMarkdown('\x00BOLD\x00<img src=x onerror=alert(1)>\x00/BOLD\x00');
  notContains(result, '<img');
});

check('Forged NUL marker cannot smuggle raw HTML via italic', () => {
  const result = renderMarkdown('\x00ITALIC\x00<svg onload=alert(1)>\x00/ITALIC\x00');
  notContains(result, '<svg');
});

check('Forged NUL marker cannot bypass link-scheme allowlist', () => {
  const result = renderMarkdown('\x00LINK\x00click\x00HREF\x00javascript:alert(1)\x00/LINK\x00');
  // No anchor is emitted at all: the forged marker is neutered into plain
  // escaped text, never reaches isValidLinkScheme, and never becomes an href.
  notContains(result, 'href=');
});

// Non-string input handling
check('Null input returns string', () => {
  const result = renderMarkdown(null);
  assert(typeof result === 'string', 'expected string return type');
  notContains(result, '<img');
});

check('Undefined input returns string', () => {
  const result = renderMarkdown(undefined);
  assert(typeof result === 'string', 'expected string return type');
});

check('Number input returns string', () => {
  const result = renderMarkdown(42);
  assert(typeof result === 'string', 'expected string return type');
});

check('Array input returns string and is safe', () => {
  const result = renderMarkdown(['<img src=x onerror=alert(1)>']);
  assert(typeof result === 'string', 'expected string return type');
  notContains(result, '<img');
});

// Test exit on failures
if (failures.length > 0) {
  console.log('\n' + failures.length + ' test(s) failed:');
  failures.forEach(f => console.log('  - ' + f));
  process.exit(1);
} else {
  console.log('\nAll tests passed.');
  process.exit(0);
}
