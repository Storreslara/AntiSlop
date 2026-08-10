#!/usr/bin/env node
'use strict';

// Cross-language contract test: bash hook (microworld-rerun.sh) → JavaScript parser (audit-log.js).
// The test executes the REAL hook against a fixture and feeds its REAL emitted line into the
// REAL parser to prove the contract is satisfied. Includes mutation proof: changing the hook's
// emitted separator must make the test fail.

const fs = require('fs');
const path = require('path');
const os = require('os');
const { execSync } = require('child_process');
const { parseAuditLog } = require('../bin/dashboard/audit-log');

const REPO_ROOT = path.resolve(__dirname, '..');

function makeFixtureProject(name) {
  const tmpDir = fs.mkdtempSync(path.join(os.tmpdir(), `audit-contract-${name}-`));
  const microworldsDir = path.join(tmpDir, 'microworlds');
  fs.mkdirSync(microworldsDir);
  fs.mkdirSync(path.join(tmpDir, '.claude'));
  fs.mkdirSync(path.join(tmpDir, 'src'));
  fs.writeFileSync(path.join(tmpDir, 'src', 'app.js'), 'source\n');
  return tmpDir;
}

function makeFailingBundle(projectDir, slug, watchGlob) {
  // Create a bundle whose run.sh always fails (exit 1)
  const bundleDir = path.join(projectDir, 'microworlds', slug);
  fs.mkdirSync(bundleDir, { recursive: true });
  fs.mkdirSync(path.join(bundleDir, 'inputs'));
  fs.mkdirSync(path.join(bundleDir, 'expected'));

  const manifest = {
    unit: slug,
    watch: [watchGlob],
    description: 'fixture bundle that fails',
    timeoutSeconds: 10,
  };
  fs.writeFileSync(path.join(bundleDir, 'manifest.json'), JSON.stringify(manifest, null, 2));

  // run.sh that always fails
  const runShScript = `#!/usr/bin/env bash
set -euo pipefail
exit 1
`;
  fs.writeFileSync(path.join(bundleDir, 'run.sh'), runShScript);
  fs.chmodSync(path.join(bundleDir, 'run.sh'), 0o755);
}

function runHook(projectDir, editedFilePath, hookScript) {
  // Execute the hook with canned hook-input JSON
  const hookInput = JSON.stringify({
    tool_input: {
      file_path: path.join(projectDir, editedFilePath),
    },
  });

  const env = { ...process.env, CLAUDE_PROJECT_DIR: projectDir };
  try {
    execSync(`bash "${hookScript}"`, {
      input: hookInput,
      env,
      stdio: ['pipe', 'ignore', 'ignore'],
    });
  } catch (err) {
    // Hook exits 2 on bundle failure (expected); ignore
  }
}

async function runTests() {
  const failures = [];

  // Test (A): Real hook + real parser contract
  console.log('Test (A): Real hook emits audit line that real parser recovers...');
  try {
    const tmpDir = makeFixtureProject('contract-a');
    makeFailingBundle(tmpDir, 'test-unit', 'src/*.js');

    const hookScript = path.join(REPO_ROOT, 'hooks/scripts/microworld-rerun.sh');
    runHook(tmpDir, 'src/app.js', hookScript);

    // Parse the audit log with the real parser
    const auditStatus = await parseAuditLog(tmpDir);
    const status = auditStatus['test-unit'];

    if (!status) {
      failures.push(`Test (A) FAILED: no audit entry for test-unit`);
    } else if (status.unit !== 'test-unit') {
      failures.push(`Test (A) FAILED: unit mismatch, expected 'test-unit' got '${status.unit}'`);
    } else if (status.result !== 'fail') {
      failures.push(`Test (A) FAILED: result mismatch, expected 'fail' got '${status.result}'`);
    } else if (!status.file || !status.file.endsWith('src/app.js')) {
      failures.push(`Test (A) FAILED: file mismatch, expected path ending in 'src/app.js' got '${status.file}'`);
    } else {
      console.log('  ✓ Test (A) passed');
    }

    fs.rmSync(tmpDir, { recursive: true });
  } catch (err) {
    failures.push(`Test (A) ERROR: ${err.message}`);
  }

  // Test (B): Mutation proof — change the separator in hook, parser should fail
  console.log('Test (B): Mutation proof — change separator, parser fails...');
  try {
    const tmpDir = makeFixtureProject('contract-b');
    makeFailingBundle(tmpDir, 'test-unit', 'src/*.js');

    // Create a MUTATED copy of the hook with a different separator (| instead of space)
    const realHook = fs.readFileSync(path.join(REPO_ROOT, 'hooks/scripts/microworld-rerun.sh'), 'utf8');
    const mutatedHook = realHook.replace(
      'line="$(date -u +%Y-%m-%dT%H:%M:%SZ) unit=$1 result=$2 file=$3"',
      'line="$(date -u +%Y-%m-%dT%H:%M:%SZ)|unit=$1|result=$2|file=$3"'
    );

    // Write mutated hook to temp location
    const mutatedHookPath = path.join(tmpDir, 'mutated-hook.sh');
    fs.writeFileSync(mutatedHookPath, mutatedHook);
    fs.chmodSync(mutatedHookPath, 0o755);

    // Run the mutated hook
    runHook(tmpDir, 'src/app.js', mutatedHookPath);

    // Try to parse the mutated audit log
    const auditStatus = await parseAuditLog(tmpDir);
    const status = auditStatus['test-unit'];

    // The mutation should cause the parser to fail — status should be missing or malformed
    if (status) {
      failures.push(`Test (B) FAILED: mutation proof broken — parser accepted mutated separator. Got: ${JSON.stringify(status)}`);
    } else {
      console.log('  ✓ Test (B) passed (mutation proof: parser correctly rejected changed separator)');
    }

    fs.rmSync(tmpDir, { recursive: true });
  } catch (err) {
    failures.push(`Test (B) ERROR: ${err.message}`);
  }

  // Summary
  console.log();
  if (failures.length > 0) {
    console.error('FAILURES:');
    failures.forEach((f) => console.error('  ' + f));
    process.exit(1);
  } else {
    console.log('All contract tests passed!');
    process.exit(0);
  }
}

runTests().catch((err) => {
  console.error('Test suite error:', err);
  process.exit(1);
});
