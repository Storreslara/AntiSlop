'use strict';

// Bounded, root-confined source excerpt reader for the microworld dashboard.
// Reads a range of lines from a project-relative file, with containment
// verification and error reporting. Read-only, never writes.

const fs = require('fs');
const path = require('path');

const MAX_LINES = 400;

/**
 * Read a bounded excerpt from a project-relative source file.
 *
 * @param {string} projectRoot - Absolute path to project root
 * @param {string} file - Project-relative file path (e.g., 'src/index.js')
 * @param {number} startLine - Start line number (1-indexed, inclusive)
 * @param {number} endLine - End line number (1-indexed, inclusive)
 * @returns {object} { success, lines, ... } or { success: false, reason, statusCode }
 */
function readSourceExcerpt(projectRoot, file, startLine, endLine) {
  // (1) Resolve file path against project root
  // Normalize to prevent path traversal via ../ or similar
  let resolvedPath;
  try {
    // Reject absolute paths outright
    if (path.isAbsolute(file)) {
      return {
        success: false,
        reason: 'Absolute paths are not allowed',
        statusCode: 400,
      };
    }

    // Resolve the path
    resolvedPath = path.resolve(projectRoot, file);
  } catch (err) {
    return {
      success: false,
      reason: `Path resolution error: ${err.message}`,
      statusCode: 400,
    };
  }

  // (2) Verify resolved path stays inside project root
  const realProjectRoot = path.resolve(projectRoot);
  const normalizedResolved = path.normalize(resolvedPath);

  // Use path.relative to detect escapes
  const relative = path.relative(realProjectRoot, normalizedResolved);

  // If relative starts with '..' or is absolute, it's outside the root
  if (relative.startsWith('..') || path.isAbsolute(relative)) {
    return {
      success: false,
      reason: 'Path escapes project root',
      statusCode: 400,
    };
  }

  // Verify the normalized path actually starts with the root
  if (!normalizedResolved.startsWith(realProjectRoot + path.sep) && normalizedResolved !== realProjectRoot) {
    return {
      success: false,
      reason: 'Path is outside project root',
      statusCode: 400,
    };
  }

  // (3) Check file exists
  if (!fs.existsSync(resolvedPath)) {
    return {
      success: false,
      reason: `File does not exist: ${file}`,
      statusCode: 404,
    };
  }

  // (4) Read file and check line range
  let content;
  try {
    content = fs.readFileSync(resolvedPath, 'utf8');
  } catch (err) {
    return {
      success: false,
      reason: `Cannot read file: ${err.message}`,
      statusCode: 404,
    };
  }

  const allLines = content.split('\n');
  const totalLines = allLines.length;

  // Line numbers are 1-indexed, but array is 0-indexed
  if (startLine < 1 || startLine > totalLines) {
    return {
      success: false,
      reason: `Start line ${startLine} is out of range (file has ${totalLines} lines)`,
      statusCode: 404,
    };
  }

  // Clamp endLine to file bounds and cap
  let cappedEndLine = Math.min(endLine, totalLines);
  cappedEndLine = Math.min(cappedEndLine, startLine + MAX_LINES - 1);

  // Extract lines (convert 1-indexed to 0-indexed)
  const lines = allLines.slice(startLine - 1, cappedEndLine);

  return {
    success: true,
    lines,
    startLine,
    endLine: startLine + lines.length - 1,
    totalLines,
  };
}

module.exports = { readSourceExcerpt };
