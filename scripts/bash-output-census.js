#!/usr/bin/env node
'use strict';

// Re-runnable census of Bash tool-result char counts across this project's
// transcript store, so the output-cap value in
// docs/plans/2026-09-23-cost-governance-output-cap-and-effort-tiers.md stays
// independently re-derivable. See that doc's Step 1 for the schema this
// mirrors: pair each `tool_use` named "Bash" to its `tool_result` by
// `tool_use_id` (may be on a different JSONL line), sum the resolved content
// length, and report percentiles plus per-candidate-cap savings.

const fs = require('fs');
const os = require('os');
const path = require('path');

// Candidate cap values mirroring the spec's Context table.
const CAPS = [4000, 8000, 12000, 16000, 30000];

function parseArgs(argv) {
  const args = { json: false, dir: null };
  for (let i = 0; i < argv.length; i++) {
    if (argv[i] === '--json') args.json = true;
    else if (argv[i] === '--dir') args.dir = argv[++i];
  }
  return args;
}

function defaultTranscriptDir() {
  const slug = process.cwd().replace(/\//g, '-');
  return path.join(os.homedir(), '.claude', 'projects', slug);
}

// tool_result.content is either a string, or an array of {type:"text",
// text} blocks (both forms occur in this repo's real transcripts).
function resultContentLength(content) {
  if (typeof content === 'string') return content.length;
  if (Array.isArray(content)) {
    return content.reduce((sum, block) => {
      if (block && block.type === 'text' && typeof block.text === 'string') {
        return sum + block.text.length;
      }
      return sum;
    }, 0);
  }
  return 0;
}

function parseJsonlLines(filePath) {
  const lines = fs.readFileSync(filePath, 'utf8').split('\n');
  const parsed = [];
  for (const line of lines) {
    const trimmed = line.trim();
    if (!trimmed) continue;
    try {
      parsed.push(JSON.parse(trimmed));
    } catch (err) {
      // Skip malformed lines rather than aborting the whole census.
    }
  }
  return parsed;
}

function bashResultLengthsInFile(filePath) {
  const parsed = parseJsonlLines(filePath);
  const toolNames = new Map();
  for (const obj of parsed) {
    const content = obj.message && obj.message.content;
    if (!Array.isArray(content)) continue;
    for (const block of content) {
      if (block && block.type === 'tool_use' && block.id) {
        toolNames.set(block.id, block.name);
      }
    }
  }
  const lengths = [];
  for (const obj of parsed) {
    const content = obj.message && obj.message.content;
    if (!Array.isArray(content)) continue;
    for (const block of content) {
      if (block && block.type === 'tool_result' && toolNames.get(block.tool_use_id) === 'Bash') {
        lengths.push(resultContentLength(block.content));
      }
    }
  }
  return lengths;
}

function collectBashResultLengths(dir) {
  let files = [];
  try {
    files = fs.readdirSync(dir).filter((f) => f.endsWith('.jsonl'));
  } catch (err) {
    return [];
  }
  const lengths = [];
  for (const file of files) {
    lengths.push(...bashResultLengthsInFile(path.join(dir, file)));
  }
  return lengths;
}

// Nearest-rank percentile over a value already sorted ascending.
function percentile(sorted, p) {
  const n = sorted.length;
  if (n === 0) return 0;
  const idx = Math.min(n, Math.ceil((p / 100) * n)) - 1;
  return sorted[idx];
}

function computeCaps(sorted, totalChars) {
  const count = sorted.length;
  return CAPS.map((cap) => {
    let callsOver = 0;
    let charsDeferred = 0;
    for (const len of sorted) {
      if (len > cap) {
        callsOver++;
        charsDeferred += len - cap;
      }
    }
    return {
      cap,
      callsOver,
      pctCallsOver: count === 0 ? 0 : (callsOver / count) * 100,
      charsDeferred,
      pctCharsDeferred: totalChars === 0 ? 0 : (charsDeferred / totalChars) * 100,
    };
  });
}

function census(dir) {
  const sorted = collectBashResultLengths(dir).sort((a, b) => a - b);
  const count = sorted.length;
  const totalChars = sorted.reduce((a, b) => a + b, 0);
  return {
    count,
    totalChars,
    p50: percentile(sorted, 50),
    p75: percentile(sorted, 75),
    p90: percentile(sorted, 90),
    p95: percentile(sorted, 95),
    p99: percentile(sorted, 99),
    max: count === 0 ? 0 : sorted[count - 1],
    caps: computeCaps(sorted, totalChars),
  };
}

function formatText(result) {
  const lines = [`Bash tool results: ${result.count}`, `Total chars: ${result.totalChars}`, ''];
  lines.push('statistic  chars');
  for (const key of ['p50', 'p75', 'p90', 'p95', 'p99', 'max']) {
    lines.push(`${key}  ${result[key]}`);
  }
  lines.push('', 'cap  calls over  % of calls  chars deferred  % of chars');
  for (const c of result.caps) {
    lines.push(
      `${c.cap}  ${c.callsOver}  ${c.pctCallsOver.toFixed(2)}%  ${c.charsDeferred}  ${c.pctCharsDeferred.toFixed(2)}%`
    );
  }
  return lines.join('\n');
}

function main() {
  const args = parseArgs(process.argv.slice(2));
  const result = census(args.dir || defaultTranscriptDir());
  console.log(args.json ? JSON.stringify(result) : formatText(result));
}

if (require.main === module) {
  main();
}

module.exports = { census, percentile, resultContentLength };
