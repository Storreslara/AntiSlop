#!/usr/bin/env node
'use strict';

// Tail and parse .claude/microworld-audit.log emitted by the PostToolUse rerun hook.
// Line format: <timestamp> unit=<slug> result=<pass|fail|timeout|error> file=<path> [reason=<...>]
// Returns a map { slug -> { unit, result, file, reason? } } (most recent line per unit only).
// Absent or unreadable log → empty map, never an error.

const fs = require('fs');
const readline = require('readline');
const path = require('path');

async function parseAuditLog(projectRoot) {
  const auditPath = path.join(projectRoot, '.claude', 'microworld-audit.log');
  const statusByUnit = {};

  if (!fs.existsSync(auditPath)) {
    return statusByUnit;
  }

  try {
    const fileStream = fs.createReadStream(auditPath, { encoding: 'utf8' });
    const rl = readline.createInterface({
      input: fileStream,
      crlfDelay: Infinity,
    });

    for await (const line of rl) {
      const parsed = parseLine(line);
      if (parsed) {
        statusByUnit[parsed.unit] = parsed;
      }
    }
  } catch (err) {
    // Unreadable log → return empty map, no error
  }

  return statusByUnit;
}

function parseLine(line) {
  // Expected format: <timestamp> unit=<slug> result=<pass|fail|timeout|error> file=<path> [reason=<...>]
  if (!line.trim()) {
    return null;
  }

  const match = line.match(/^[^\s]+\s+unit=(\S+)\s+result=(\S+)\s+file=(\S+)(?:\s+reason=(.+))?$/);
  if (!match) {
    return null;
  }

  const [, unit, result, file, reason] = match;
  const parsed = { unit, result, file };
  if (reason) {
    parsed.reason = reason;
  }
  return parsed;
}

module.exports = { parseAuditLog };
