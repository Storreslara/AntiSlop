'use strict';

// Vendored, dependency-free markdown renderer for dashboard document panes.
// Dual-environment, single implementation: CommonJS-requirable and injectable
// as a page global. No external dependencies.
// Escape-first XSS model: renderInline escapes its whole argument once, as its
// first statement, and that is the only escape site on the inline path. Every
// replace after it merely wraps already-escaped spans in renderer-generated
// tags, so no code path there ever holds unescaped user text. Do not add a
// second escape call inside renderInline.

function escapeHtml(text) {
  return String(text)
    .replace(/&/g, '&amp;')
    .replace(/</g, '&lt;')
    .replace(/>/g, '&gt;')
    .replace(/"/g, '&quot;')
    .replace(/'/g, '&#39;');
}

function isValidLinkScheme(href) {
  if (typeof href !== 'string') return false;
  if (href.startsWith('http://') || href.startsWith('https://') || href.startsWith('./') || href.startsWith('/') || href.startsWith('../')) {
    return true;
  }
  // Relative link without ./ or /
  if (!href.includes(':')) {
    return true;
  }
  return false;
}

// Tables. Cells are never escaped here: every cell goes through renderInline,
// the one escape site on the inline path, and the emitted tags carry no attributes.
// A backslash escapes a following `|` or `\\`; an unescaped `|` that ends the
// row closes it and adds no empty cell.
function mdSplitRow(row) {
  let s = row.trim();
  if (s.startsWith('|')) s = s.slice(1);
  const cells = [];
  let cur = '';
  let endedOnPipe = false;
  for (let k = 0; k < s.length; k++) {
    endedOnPipe = false;
    if (s[k] === '\\' && (s[k + 1] === '|' || s[k + 1] === '\\')) { cur += s[k + 1]; k++; }
    else if (s[k] === '|') { cells.push(cur.trim()); cur = ''; endedOnPipe = true; }
    else cur += s[k];
  }
  if (!endedOnPipe) cells.push(cur.trim());
  return cells;
}

// True when a line opens another block (fence, heading, rule, blockquote or
// list item), so a table body stops before it even if it contains a `|`.
function mdStartsBlock(trimmed) {
  return trimmed.startsWith('```') || /^#+\s/.test(trimmed) || trimmed === '---' || trimmed === '***' ||
    trimmed === '___' || trimmed.startsWith('> ') || trimmed.startsWith('- ') || trimmed.startsWith('* ') ||
    /^\d+\.\s/.test(trimmed);
}

function mdIsDelimiterRow(row, width) {
  if (!row.includes('|')) return false;
  const cells = mdSplitRow(row);
  return cells.length === width && cells.every((c) => /^:?-+:?$/.test(c));
}

function renderMarkdown(input) {
  // Fail closed: non-string input returns empty escaped string
  if (typeof input !== 'string') {
    return '<p></p>';
  }

  const lines = input.split('\n');
  let html = '';
  let i = 0;

  while (i < lines.length) {
    const line = lines[i];
    const trimmed = line.trim();

    // Fenced code blocks
    if (trimmed.startsWith('```')) {
      let codeLines = [];
      i++;
      while (i < lines.length && !lines[i].trim().startsWith('```')) {
        codeLines.push(escapeHtml(lines[i]));
        i++;
      }
      html += '<pre><code>' + codeLines.join('\n') + '</code></pre>';
      i++; // Skip closing ```
      continue;
    }

    // Headings
    if (trimmed.match(/^#+\s/)) {
      const match = trimmed.match(/^(#+)\s+(.*)/);
      if (match) {
        const level = match[1].length;
        const content = match[2];
        html += `<h${level}>${escapeHtml(content)}</h${level}>`;
        i++;
        continue;
      }
    }

    // Horizontal rule
    if (trimmed === '---' || trimmed === '***' || trimmed === '___') {
      html += '<hr />';
      i++;
      continue;
    }

    // Blockquote
    if (trimmed.startsWith('> ')) {
      let quoteLines = [];
      while (i < lines.length && lines[i].trim().startsWith('> ')) {
        quoteLines.push(escapeHtml(lines[i].trim().substring(2)));
        i++;
      }
      html += '<blockquote><p>' + quoteLines.join('<br />') + '</p></blockquote>';
      continue;
    }

    // Unordered list
    if (trimmed.startsWith('- ') || trimmed.startsWith('* ')) {
      let listItems = [];
      while (i < lines.length && (lines[i].trim().startsWith('- ') || lines[i].trim().startsWith('* '))) {
        const item = lines[i].trim().substring(2);
        listItems.push(renderInline(item));
        i++;
      }
      html += '<ul>' + listItems.map(item => '<li>' + item + '</li>').join('') + '</ul>';
      continue;
    }

    // Ordered list
    if (trimmed.match(/^\d+\.\s/)) {
      let listItems = [];
      while (i < lines.length && lines[i].trim().match(/^\d+\.\s/)) {
        const item = lines[i].trim().replace(/^\d+\.\s+/, '');
        listItems.push(renderInline(item));
        i++;
      }
      html += '<ol>' + listItems.map(item => '<li>' + item + '</li>').join('') + '</ol>';
      continue;
    }

    // Table: a header row, then a delimiter row with the same cell count.
    if (trimmed.includes('|') && i + 1 < lines.length) {
      const head = mdSplitRow(trimmed);
      if (mdIsDelimiterRow(lines[i + 1], head.length)) {
        i += 2;
        let rows = '';
        while (i < lines.length && lines[i].trim() !== '' && lines[i].includes('|') && !mdStartsBlock(lines[i].trim())) {
          const cells = mdSplitRow(lines[i]);
          let tr = '';
          for (let c = 0; c < head.length; c++) tr += '<td>' + renderInline(cells[c] || '') + '</td>';
          rows += '<tr>' + tr + '</tr>';
          i++;
        }
        html += '<table><thead><tr>' + head.map((c) => '<th>' + renderInline(c) + '</th>').join('') + '</tr></thead>' +
          (rows ? '<tbody>' + rows + '</tbody>' : '') + '</table>';
        continue;
      }
    }

    // Paragraph (non-empty line that's not special)
    if (trimmed.length > 0) {
      html += '<p>' + renderInline(trimmed) + '</p>';
      i++;
      continue;
    }

    // Empty line
    i++;
  }

  return html;
}

function renderInline(text) {
  // The one and only escape on this path. Everything below operates on escaped
  // text and only adds tags, so no span can be left unescaped or escaped twice.
  let result = escapeHtml(text);

  // Inline code first (nothing inside backticks should be processed further)
  result = result.replace(/`([^`]+)`/g, '<code>$1</code>');

  // Links: [text](url). The href is already escaped, so it lands safe in the
  // attribute; a non-allowlisted scheme emits no anchor at all.
  result = result.replace(/\[([^\]]+)\]\(([^)]+)\)/g, function(m, label, href) {
    if (isValidLinkScheme(href)) {
      return '<a href="' + href + '" rel="noopener noreferrer" target="_blank">' + label + '</a>';
    }
    return label;
  });

  // Bold before italic, so ** is not consumed by the single-* pattern
  result = result.replace(/\*\*([^*]+)\*\*/g, '<strong>$1</strong>');
  result = result.replace(/\*([^*]+)\*/g, '<em>$1</em>');

  return result;
}

if (typeof module !== 'undefined' && module.exports) {
  module.exports = { renderMarkdown };
}
