#!/usr/bin/env node
'use strict';

// Discovers microworld bundles from microworlds/*/manifest.json.
// Enumerates unit, description, functions[], and live status from audit log.
// Fails soft always — malformed JSON, missing manifest, missing/non-executable entry never crash the server.
// Returns [ { id, unit, source, description, disabled, disabledReason, functions, status } ]

const fs = require('fs');
const path = require('path');
const { parseAuditLog } = require('./audit-log');

async function discover(projectRoot) {
  const microworldsPath = path.join(projectRoot, 'microworlds');
  const bundles = [];

  if (!fs.existsSync(microworldsPath)) {
    return bundles;
  }

  let entries;
  try {
    entries = fs.readdirSync(microworldsPath);
  } catch (err) {
    return bundles;
  }

  // Load audit log status for all units
  const auditStatus = await parseAuditLog(projectRoot);

  for (const unitSlug of entries) {
    const bundlePath = path.join(microworldsPath, unitSlug);
    const manifestPath = path.join(bundlePath, 'manifest.json');

    let manifest;
    try {
      const content = fs.readFileSync(manifestPath, 'utf8');
      manifest = JSON.parse(content);
    } catch (err) {
      // Malformed JSON or missing manifest — mark disabled with reason
      bundles.push({
        id: `working:${unitSlug}`,
        unit: unitSlug,
        source: 'working',
        description: '(error reading manifest)',
        disabled: true,
        disabledReason: err.code === 'ENOENT' ? 'manifest.json not found' : `malformed JSON: ${err.message}`,
        functions: [],
        status: auditStatus[unitSlug] || null,
      });
      continue;
    }

    // Extract unit and description from manifest
    const unit = manifest.unit || unitSlug;
    const description = manifest.description || '';

    // Validate and process functions[]
    const functions = [];
    const functionsArray = manifest.functions || [];

    for (const fn of functionsArray) {
      if (!fn.entry) {
        functions.push({
          id: fn.id || '',
          group: fn.group || '',
          label: fn.label || '',
          description: fn.description || '',
          location: fn.location || null,
          inputs: fn.inputs || [],
          disabled: true,
          disabledReason: 'entry field not found in manifest',
        });
        continue;
      }

      // Check if entry is executable
      const entryPath = path.join(bundlePath, fn.entry);
      let isExecutable = false;
      try {
        const stat = fs.statSync(entryPath);
        // Check if executable bit is set (mode & 0111)
        isExecutable = (stat.mode & parseInt('0111', 8)) !== 0;
      } catch (err) {
        // File does not exist or cannot be statted
      }

      if (!isExecutable) {
        functions.push({
          id: fn.id || '',
          group: fn.group || '',
          label: fn.label || '',
          description: fn.description || '',
          location: fn.location || null,
          inputs: fn.inputs || [],
          disabled: true,
          disabledReason: fs.existsSync(entryPath) ? 'entry is not executable' : 'entry file not found',
        });
        continue;
      }

      // Entry is valid
      functions.push({
        id: fn.id || '',
        group: fn.group || '',
        label: fn.label || '',
        description: fn.description || '',
        location: fn.location || null,
        inputs: fn.inputs || [],
        disabled: false,
      });
    }

    // Check if any function is disabled
    const hasDisabledFunctions = functions.some((f) => f.disabled);

    bundles.push({
      id: `working:${unitSlug}`,
      unit,
      source: 'working',
      description,
      disabled: hasDisabledFunctions,
      disabledReason: hasDisabledFunctions ? 'some functions cannot be invoked' : '',
      functions,
      status: auditStatus[unitSlug] || null,
    });
  }

  return bundles;
}

module.exports = { discover };
