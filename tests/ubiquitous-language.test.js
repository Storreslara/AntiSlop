#!/usr/bin/env node
'use strict';

// Structural / mutual-distinguishability checks for
// skills/ubiquitous-language/SKILL.md's prose (gh-305). SKILL.md is pure
// prose with no programmatic entry point, so this cannot test whether the
// lens actually catches drift (P2: "governs the plumbing, not the lens") -
// it only guards the doc's shape: both modes documented, the no-glossary
// degradation text naming its two dependents, and the three lenses / two
// modes not having collapsed into copy-pasted boilerplate.
//
// Usage:
//   node tests/ubiquitous-language.test.js                   # real file, exits 0
//   UL_TEST_MUTATE=1 node tests/ubiquitous-language.test.js  # mutated copy
//     (degradation paragraph + three lenses' distinguishing language
//     collapsed to identical boilerplate) - exits non-zero, proving the
//     checks below are not vacuous. Never touches the real file on disk.

const fs = require('fs');
const path = require('path');

const REPO_ROOT = path.resolve(__dirname, '..');
const SKILL_PATH = path.join(REPO_ROOT, 'skills', 'ubiquitous-language', 'SKILL.md');

function extract(content, re) {
  const m = content.match(re);
  return m ? m[0] : null;
}

// Runs the four structural/distinguishability checks against `content`,
// returning a list of failure descriptions (empty = all passed).
function checkSkillText(content) {
  const failures = [];

  if (!/^## Diff mode$/m.test(content)) failures.push('missing "## Diff mode" heading');
  if (!/^## Prose mode$/m.test(content)) failures.push('missing "## Prose mode" heading');

  const degradation = extract(content, /\*\*Degradation \(no glossary\):\*\*[\s\S]*?(?=\n\n)/);
  if (!degradation || !degradation.includes('CONTEXT.md') || !degradation.includes('scribe')) {
    failures.push('degradation paragraph missing, or does not name both CONTEXT.md and scribe in the same paragraph');
  }

  const lensTerms = {
    lens1: 'different meaning',
    lens2: 'synonym',
    lens3: 'no glossary entry',
  };
  const lensText = {
    lens1: extract(content, /1\. \*\*[\s\S]*?(?=\n\n2\. \*\*)/),
    lens2: extract(content, /2\. \*\*[\s\S]*?(?=\n\n3\. \*\*)/),
    lens3: extract(content, /3\. \*\*[\s\S]*?(?=\n\nIf a lens)/),
  };
  for (const [name, text] of Object.entries(lensText)) {
    if (!text) { failures.push(`${name} paragraph not found`); continue; }
    if (!text.includes(lensTerms[name])) {
      failures.push(`${name} missing its own identifying term "${lensTerms[name]}"`);
    }
    for (const [otherName, otherTerm] of Object.entries(lensTerms)) {
      if (otherName !== name && text.includes(otherTerm)) {
        failures.push(`${name} unexpectedly contains ${otherName}'s term "${otherTerm}" (not mutually distinguishing)`);
      }
    }
  }

  const diffSection = extract(content, /## Diff mode\n[\s\S]*?(?=\n## Prose mode)/);
  const proseSection = extract(content, /## Prose mode\n[\s\S]*$/);
  if (!diffSection || !diffSection.includes('file:line')) {
    failures.push('diff mode section missing "file:line" anchor language');
  }
  if (diffSection && diffSection.includes('quoted span')) {
    failures.push('diff mode section unexpectedly contains "quoted span"');
  }
  if (!proseSection || !proseSection.includes('quoted span')) {
    failures.push('prose mode section missing "quoted span" anchor language');
  }
  if (proseSection && proseSection.includes('file:line')) {
    failures.push('prose mode section unexpectedly contains "file:line"');
  }

  return failures;
}

// Builds a mutated COPY (never touches the real file) with the degradation
// paragraph and the three lenses' distinguishing language collapsed to
// identical boilerplate - the only "stub" available for a prose artifact.
function buildMutatedCopy(content) {
  const boilerplate = 'This lens checks something relevant to terminology drift.';
  return content
    .replace(
      /\*\*Degradation \(no glossary\):\*\*[\s\S]*?(?=\n\n)/,
      '**Degradation (no glossary):** if reference material is unavailable, note that and stop. Not a finding, not an error.'
    )
    .replace(/1\. \*\*[\s\S]*?(?=\n\n2\. \*\*)/, `1. **Lens one.** ${boilerplate}`)
    .replace(/2\. \*\*[\s\S]*?(?=\n\n3\. \*\*)/, `2. **Lens two.** ${boilerplate}`)
    .replace(/3\. \*\*[\s\S]*?(?=\n\nIf a lens)/, `3. **Lens three.** ${boilerplate}`);
}

const realContent = fs.readFileSync(SKILL_PATH, 'utf8');
const mutate = process.env.UL_TEST_MUTATE === '1';
const content = mutate ? buildMutatedCopy(realContent) : realContent;

const failures = checkSkillText(content);
if (failures.length === 0) {
  console.log(`OK   skills/ubiquitous-language/SKILL.md passes all 4 structural/distinguishability checks${mutate ? ' (mutated copy)' : ''}`);
  process.exit(0);
} else {
  for (const f of failures) console.log(`FAIL ${f}`);
  console.log(`${failures.length} check(s) FAILED${mutate ? ' (mutated copy, as expected)' : ''}.`);
  process.exit(1);
}
