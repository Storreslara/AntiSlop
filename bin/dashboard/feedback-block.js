'use strict';

// Pure formatter for microworld feedback blocks.
// Takes a context object and produces the exact markdown shape for LLM parsing
// and human grep-ability.

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
  }

  return output;
}

module.exports = { formatFeedbackBlock };
