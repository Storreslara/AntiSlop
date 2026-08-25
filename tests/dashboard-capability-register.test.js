#!/usr/bin/env node
'use strict';

// Bijection test: routes declared in bin/microworld-dashboard/server.js must
// exactly match routes registered in docs/microworld-dashboard-capabilities.md.
// This prevents the register from silently rotting as routes are added or removed.
// Also validates: every status is load-bearing or speculative, and every
// load-bearing row has a non-empty "Cited by" cell.

const fs = require('fs');
const path = require('path');
const assert = require('assert');

const REPO_ROOT = path.resolve(__dirname, '..');
const SERVER_JS = path.join(REPO_ROOT, 'bin/microworld-dashboard/server.js');
const CAPABILITIES_MD = path.join(REPO_ROOT, 'docs/microworld-dashboard-capabilities.md');

function extractRoutesFromServerJs() {
  const content = fs.readFileSync(SERVER_JS, 'utf8');
  const routes = new Set();

  // Match all pathname === '/api/...' literals
  const pathLiterals = content.match(/pathname === '(\/api\/[^']+)'/g) || [];
  pathLiterals.forEach((match) => {
    const route = match.match(/pathname === '([^']+)'/)[1];
    routes.add(route);
  });

  return Array.from(routes).sort();
}

function extractRoutesFromCapabilitiesMd() {
  const content = fs.readFileSync(CAPABILITIES_MD, 'utf8');
  const routes = new Set();

  // Extract all `/api/...` route paths from markdown table Route cells.
  // Routes can be aggregated in one cell with comma separation.
  // They appear in backticks with optional HTTP method: `GET /api/bundles`
  const lines = content.split('\n');
  let inTable = false;
  for (const line of lines) {
    // Start of table
    if (line.includes('| Route |')) {
      inTable = true;
      continue;
    }

    // End of table or separator line
    if (inTable && (line.includes('---') || (!line.startsWith('|') && line.trim() !== ''))) {
      if (line.includes('---')) continue; // Skip separator
      if (!line.startsWith('|')) inTable = false; // End of table
      continue;
    }

    // Process table rows
    if (inTable && line.startsWith('|')) {
      // Extract Route cell (first column after opening |)
      const match = line.match(/^\|\s*([^|]+)\s*\|/);
      if (!match) continue;

      const routeCell = match[1].trim();

      // Extract all `/api/...` patterns (with or without backticks or HTTP method)
      // Match: `GET /api/...`, `POST /api/...`, or just `/api/...`
      const routeMatches = routeCell.match(/`?(?:GET|POST)?\s*(\/api\/[^\s`'",;|]+)`?/g) || [];
      routeMatches.forEach((rm) => {
        // Clean up: remove backticks and HTTP methods
        let route = rm.replace(/`/g, '').trim();
        route = route.replace(/^(?:GET|POST)\s+/, '');
        if (route.startsWith('/api/')) {
          routes.add(route);
        }
      });
    }
  }

  return Array.from(routes).sort();
}

function validateCapabilitiesTableStructure() {
  const content = fs.readFileSync(CAPABILITIES_MD, 'utf8');
  const lines = content.split('\n');
  const failures = [];
  let inTable = false;
  let foundTable = false;

  for (const line of lines) {
    // Start of table
    if (line.includes('| Route |')) {
      inTable = true;
      foundTable = true;
      continue;
    }

    // End of table or skip non-table lines
    if (inTable && line.includes('---')) {
      continue; // Skip separator
    }

    if (inTable && (!line.startsWith('|') || !line.trim())) {
      if (line.trim()) inTable = false; // End of table
      continue;
    }

    // Validate table rows
    if (inTable && line.startsWith('|')) {
      // Split cells by |
      const cells = line.split('|').map(c => c.trim()).filter(c => c.length > 0);
      if (cells.length < 4) {
        failures.push(`Row has fewer than 4 cells: ${line}`);
        continue;
      }

      const routeCell = cells[0];
      const capabilityCell = cells[1];
      const statusCell = cells[2];
      const citedByCell = cells[3];

      // Validate status contains 'load-bearing' or 'speculative'
      const statusLower = statusCell.toLowerCase();
      if (!statusLower.includes('load-bearing') && !statusLower.includes('speculative')) {
        failures.push(
          `Row with route "${routeCell}" has invalid status "${statusCell}". ` +
          `Must contain 'load-bearing' or 'speculative'`
        );
        continue;
      }

      // If status contains 'load-bearing', cited-by must be non-empty
      if (statusLower.includes('load-bearing') && !citedByCell) {
        failures.push(
          `Row with route "${routeCell}" has status "load-bearing" ` +
          `but empty "Cited by" cell`
        );
      }
    }
  }

  if (!foundTable) {
    throw new Error('Could not find Capabilities table in markdown');
  }

  return failures;
}

async function runTests() {
  const failures = [];

  // Test (A): Extract routes from both sources
  console.log('Test (A): Extract routes from server.js and capabilities.md...');
  let serverRoutes = [];
  let capRoutes = [];
  try {
    serverRoutes = extractRoutesFromServerJs();
    console.log(`  Found ${serverRoutes.length} routes in server.js: ${serverRoutes.join(', ')}`);
    capRoutes = extractRoutesFromCapabilitiesMd();
    console.log(`  Found ${capRoutes.length} routes in capabilities.md: ${capRoutes.join(', ')}`);
    console.log('  ✓ Test (A) passed');
  } catch (err) {
    failures.push(`Test (A) ERROR: ${err.message}`);
    return process.exit(failures.length > 0 ? 1 : 0);
  }

  // Test (B): Bijection — sets must be equal
  console.log('Test (B): Bijection — server.js routes equal capabilities.md routes...');
  if (serverRoutes.length !== capRoutes.length) {
    failures.push(
      `Test (B) FAILED: route count mismatch. ` +
      `server.js has ${serverRoutes.length}, capabilities.md has ${capRoutes.length}`
    );
  } else {
    const serverSet = new Set(serverRoutes);
    const capSet = new Set(capRoutes);

    const inServerNotCap = serverRoutes.filter(r => !capSet.has(r));
    const inCapNotServer = capRoutes.filter(r => !serverSet.has(r));

    if (inServerNotCap.length > 0) {
      failures.push(
        `Test (B) FAILED: routes in server.js but not in capabilities.md: ${inServerNotCap.join(', ')}`
      );
    }
    if (inCapNotServer.length > 0) {
      failures.push(
        `Test (B) FAILED: routes in capabilities.md but not in server.js: ${inCapNotServer.join(', ')}`
      );
    }

    if (inServerNotCap.length === 0 && inCapNotServer.length === 0) {
      console.log('  ✓ Test (B) passed (bijection confirmed)');
    }
  }

  // Test (C): Validate table structure (status values and load-bearing citations)
  console.log('Test (C): Validate table structure (status values and load-bearing citations)...');
  try {
    const structureFailures = validateCapabilitiesTableStructure();
    if (structureFailures.length > 0) {
      structureFailures.forEach(f => failures.push(`Test (C) FAILED: ${f}`));
    } else {
      console.log('  ✓ Test (C) passed (all rows have valid status and citations)');
    }
  } catch (err) {
    failures.push(`Test (C) ERROR: ${err.message}`);
  }

  // Summary
  console.log();
  if (failures.length > 0) {
    console.error('FAILURES:');
    failures.forEach((f) => console.error('  ' + f));
    process.exit(1);
  } else {
    console.log('All capability register tests passed!');
    process.exit(0);
  }
}

runTests().catch((err) => {
  console.error('Test suite error:', err);
  process.exit(1);
});
