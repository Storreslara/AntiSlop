#!/usr/bin/env node
// AC-E1: Every *.sh under hooks/scripts/ is either protected or exempted with reason

const fs = require('fs');
const path = require('path');
const { execSync } = require('child_process');

const projectDir = path.resolve(__dirname, '..');
const hooksDir = path.join(projectDir, 'hooks', 'scripts');
const configPath = path.join(projectDir, '.claude', 'persona-config.json');

// Exemption list: scripts that are deliberately not protected, with reasoning
const exemptions = {
  'harness-integrity-gate.sh': 'Self-protecting instead: its own Write/Edit ' +
    'branch hardcodes a deny on writes to hooks/hooks.json, ' +
    '.claude/settings.json, and itself (Set B). gh418\'s "Do NOT touch" ' +
    'section reserves adding it to protectedPaths as an operator decision, ' +
    'not something this unit bakes in.',
};

const config = JSON.parse(fs.readFileSync(configPath, 'utf8'));
const protectedPaths = config.protectedPaths || [];

// Extract all patterns from protectedPaths (handle both string and object formats)
const patterns = protectedPaths.map(entry =>
  typeof entry === 'string' ? entry : entry.pattern
);

// Enumerate all .sh files under hooks/scripts/
function getAllShFiles(dir, baseDir = '') {
  const files = [];
  const entries = fs.readdirSync(dir, { withFileTypes: true });

  for (const entry of entries) {
    const fullPath = path.join(dir, entry.name);
    const relPath = baseDir ? path.join(baseDir, entry.name) : entry.name;

    if (entry.isDirectory()) {
      files.push(...getAllShFiles(fullPath, relPath));
    } else if (entry.isFile() && entry.name.endsWith('.sh')) {
      files.push(relPath);
    }
  }

  return files;
}

// Check if a path matches any pattern (mimics bash case statement)
function matchesPattern(filePath, patterns) {
  for (const pattern of patterns) {
    // Convert glob pattern to regex
    const regexPattern = pattern
      .replace(/\./g, '\\.')
      .replace(/\*/g, '[^/]*')
      .replace(/\?/g, '.');

    const regex = new RegExp(`^${regexPattern}$`);
    if (regex.test(filePath)) {
      return true;
    }
  }
  return false;
}

const allFiles = getAllShFiles(hooksDir);
const uncovered = [];
const covered = [];

for (const file of allFiles) {
  const isExempt = exemptions[file] !== undefined;
  // Check both relative path (from hooks/scripts) and full path (from project root)
  const fullPath = path.join('hooks', 'scripts', file);
  const isProtected = matchesPattern(file, patterns) || matchesPattern(fullPath, patterns);

  if (!isProtected && !isExempt) {
    uncovered.push(file);
  } else if (isProtected) {
    covered.push(file);
  }
}

// Report results
console.log(`Total hook scripts found: ${allFiles.length}`);
console.log(`Protected: ${covered.length}`);
console.log(`Exempted: ${Object.keys(exemptions).length}`);

if (uncovered.length > 0) {
  console.error(`\nERROR: ${uncovered.length} script(s) not covered:\n`);
  for (const file of uncovered) {
    console.error(`  - hooks/scripts/${file}`);
  }
  console.error('\nEvery script must be either in protectedPaths or exemptions.');
  process.exit(1);
}

// Verify all exemptions have reasons
function findExemptionsMissingReasons(exemptionsMap) {
  return Object.entries(exemptionsMap)
    .filter(([, reason]) => !reason || !reason.trim())
    .map(([script]) => script);
}

for (const script of findExemptionsMissingReasons(exemptions)) {
  console.error(`ERROR: Exemption for ${script} has no reason`);
  process.exit(1);
}

// Self-test: exemptions is currently empty, so the reasonless-exemption path
// above is otherwise dead code. Prove findExemptionsMissingReasons() actually
// catches a reasonless exemption, independent of the live (empty) map.
const selfTestMissing = findExemptionsMissingReasons({ 'fake-script.sh': '' });
if (selfTestMissing.length !== 1 || selfTestMissing[0] !== 'fake-script.sh') {
  console.error('ERROR: self-test failed - findExemptionsMissingReasons() did not flag a reasonless exemption');
  process.exit(1);
}

console.log('\n✓ All hook scripts are covered');
if (Object.keys(exemptions).length > 0) {
  console.log('\nExempted scripts:');
  for (const [script, reason] of Object.entries(exemptions)) {
    console.log(`  - ${script}: ${reason}`);
  }
}

process.exit(0);
