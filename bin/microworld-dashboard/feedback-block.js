'use strict';

// Pure formatter for microworld feedback blocks.
// Takes a context object and produces the exact markdown shape for LLM parsing
// and human grep-ability.
//
// Dual-environment, single implementation: this file is loaded two ways.
//   - Node (CommonJS): required directly by the test suite via `require()`.
//   - Browser: bin/microworld-dashboard/server.js's `GET /` handler reads this file's
//     source verbatim and injects it into a classic (non-module) <script>
//     tag ahead of index.html's own module script (see the
//     `__FEEDBACK_BLOCK_SOURCE__` placeholder there). A top-level function
//     declaration in a classic script becomes a page global, so index.html's
//     module script calls `formatFeedbackBlock` by name with no import
//     machinery required. There is exactly one implementation of this shape;
//     nothing reimplements it.

/**
 * Format a feedback block for clipboard export.
 *
 * @param {object} context - Context object with:
 *   - unitSlug: unit identifier (e.g., 'test-unit')
 *   - functionId: function id (e.g., 'test-fn')
 *   - functionGroup: group/class name (e.g., 'TestClass')
 *   - functionLabel: display label (e.g., 'Test Function')
 *   - comment: human's freetext comment (verbatim)
 *   - sha: git HEAD sha at copy time
 *   - location: optional { file, startLine, endLine }
 *   - cell: optional cell object with { inputs, result }
 *
 * @returns {string} Formatted markdown block
 */
function formatFeedbackBlock(context) {
  const {
    unitSlug,
    functionId,
    functionGroup,
    functionLabel,
    comment = '',
    sha,
    location = null,
    cell = null,
  } = context;

  let output = '';

  // Header
  output += `## Microworld feedback — ${unitSlug} / ${functionLabel}\n\n`;

  // Metadata
  output += `- function: \`${functionId}\` (group: \`${functionGroup}\`)\n`;

  // Location line
  if (location) {
    const { file, startLine, endLine } = location;
    output += `- location: \`${file}:${startLine}-${endLine}\`\n`;
  } else {
    output += `- location: not declared\n`;
  }

  output += `- commit: ${sha}\n`;
  output += `- bundle: microworlds/${unitSlug}/\n`;

  // Comment section
  output += `\n### Comment\n${comment}\n`;

  // Last run section (only for cells)
  if (cell && cell.inputs !== undefined && cell.result !== undefined) {
    output += `\n### Last run\n`;

    // Inputs (compact JSON)
    const inputsJson = JSON.stringify(cell.inputs);
    output += `- inputs: ${inputsJson}\n`;

    // Exit code and duration
    const exitCode = cell.result.exitCode;
    const durationMs = cell.result.durationMs;
    output += `- exit: ${exitCode}   duration: ${durationMs}ms\n`;

    // Output (if present)
    if (cell.result.stdout) {
      output += `\n\`\`\`\n${cell.result.stdout}\n\`\`\`\n`;
    } else if (cell.result.stderr) {
      output += `\n\`\`\`\n${cell.result.stderr}\n\`\`\`\n`;
    }

    // Explicit truncation marker -- required by the plan's fixed block shape
    // ("<output, fenced, truncated with an explicit marker>"), unambiguous
    // and grep-able.
    if (cell.result.truncated) {
      output += `\n*(output truncated)*\n`;
    }
  }

  return output;
}

// CommonJS export, guarded so the same source is inert when embedded as a
// classic browser <script> (where `module` is undefined and this branch is
// simply skipped, leaving `formatFeedbackBlock` as a page global instead).
if (typeof module !== 'undefined' && module.exports) {
  module.exports = { formatFeedbackBlock };
}
