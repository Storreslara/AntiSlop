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

  // (2) Lexical containment check. Necessary but NOT sufficient: this only
  // catches ../ and absolute-path escapes textually. A symlink living inside
  // the root but pointing outside it passes this check untouched, which is
  // exactly what step (3) below exists to catch.
  const lexicalProjectRoot = path.resolve(projectRoot);
  const normalizedResolved = path.normalize(resolvedPath);

  // Use path.relative to detect escapes
  const relative = path.relative(lexicalProjectRoot, normalizedResolved);

  // If relative starts with '..' or is absolute, it's outside the root
  if (relative.startsWith('..') || path.isAbsolute(relative)) {
    return {
      success: false,
      reason: 'Path escapes project root',
      statusCode: 400,
    };
  }

  // Verify the normalized path actually starts with the root
  if (!normalizedResolved.startsWith(lexicalProjectRoot + path.sep) && normalizedResolved !== lexicalProjectRoot) {
    return {
      success: false,
      reason: 'Path is outside project root',
      statusCode: 400,
    };
  }

  // (3) Real (symlink-resolved) containment check -- this is the actual
  // security gate (guardrail 6). Resolve BOTH the project root and the
  // candidate path with realpath and compare those, not the lexical paths,
  // so a symlink inside the root pointing outside it is caught rather than
  // followed.
  let realProjectRoot;
  try {
    realProjectRoot = fs.realpathSync.native(lexicalProjectRoot);
  } catch (err) {
    // The project root itself is expected to always exist; if it doesn't,
    // nothing downstream can succeed either.
    return {
      success: false,
      reason: `Project root could not be resolved: ${err.message}`,
      statusCode: 404,
    };
  }

  let realResolvedPath;
  try {
    realResolvedPath = fs.realpathSync.native(resolvedPath);
  } catch (err) {
    if (err.code === 'ENOENT') {
      // Doesn't exist -- can't be realpath'd. Fall through to the existing
      // file-not-found handling below rather than treating this as a 400.
      realResolvedPath = null;
    } else {
      return {
        success: false,
        reason: `Path resolution error: ${err.message}`,
        statusCode: 400,
      };
    }
  }

  if (
    realResolvedPath !== null &&
    realResolvedPath !== realProjectRoot &&
    !realResolvedPath.startsWith(realProjectRoot + path.sep)
  ) {
    return {
      success: false,
      reason: 'Path escapes project root',
      statusCode: 400,
    };
  }

  // (4) Check file exists
  if (!fs.existsSync(resolvedPath)) {
    return {
      success: false,
      reason: `File does not exist: ${file}`,
      statusCode: 404,
    };
  }

  // (5) Read file and check line range
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

  if (endLine < startLine) {
    return {
      success: false,
      reason: `endLine (${endLine}) before startLine (${startLine})`,
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
