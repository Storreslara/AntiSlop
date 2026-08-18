'use strict';

// Vendored, dependency-free markdown renderer for dashboard document panes.
// Dual-environment, single implementation: CommonJS-requirable and injectable
// as a page global. No external dependencies.
// Escape-first XSS model: every text span is escaped before tag emission.

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

function renderMarkdown(input) {
  // Fail closed: non-string input returns empty escaped string
  if (typeof input !== 'string') {
    return '<p></p>';
  }

  // Strip NUL bytes: renderInline uses \x00-delimited sentinels internally to
  // mark already-processed spans. An input-supplied NUL could otherwise forge
  // a marker and smuggle unescaped HTML through, so none may survive to reach
  // renderInline.
  input = input.replace(/\x00/g, '');

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
  let result = text;

  // Process inline formatting in order, using unique markers to protect content
  // Inline code first (nothing inside backticks should be processed further)
  result = result.replace(/`([^`]+)`/g, function(m, code) {
    return '\x00INLINE_CODE\x00' + escapeHtml(code) + '\x00/INLINE_CODE\x00';
  });

  // Links: [text](url)
  result = result.replace(/\[([^\]]+)\]\(([^)]+)\)/g, function(m, label, href) {
    if (isValidLinkScheme(href)) {
      return '\x00LINK\x00' + escapeHtml(label) + '\x00HREF\x00' + escapeHtml(href) + '\x00/LINK\x00';
    }
    return escapeHtml(label);
  });

  // Bold: **text**
  result = result.replace(/\*\*([^*]+)\*\*/g, function(m, text) {
    return '\x00BOLD\x00' + escapeHtml(text) + '\x00/BOLD\x00';
  });

  // Italic: *text*
  result = result.replace(/\*([^*]+)\*/g, function(m, text) {
    return '\x00ITALIC\x00' + escapeHtml(text) + '\x00/ITALIC\x00';
  });

  // Escape remaining plain text (split by markers and escape non-marked portions)
  result = result.split(/(\x00[^/]*\x00|\x00\/[^/]*\x00)/g).map(function(part) {
    if (part.startsWith('\x00')) {
      return part; // Marker - don't escape
    }
    return escapeHtml(part); // Plain text - escape it
  }).join('');

  // Replace markers with actual HTML
  result = result.replace(/\x00INLINE_CODE\x00([^\x00]*)\x00\/INLINE_CODE\x00/g, '<code>$1</code>');
  result = result.replace(/\x00BOLD\x00([^\x00]*)\x00\/BOLD\x00/g, '<strong>$1</strong>');
  result = result.replace(/\x00ITALIC\x00([^\x00]*)\x00\/ITALIC\x00/g, '<em>$1</em>');
  result = result.replace(/\x00LINK\x00([^\x00]*)\x00HREF\x00([^\x00]*)\x00\/LINK\x00/g, '<a href="$2" rel="noopener noreferrer" target="_blank">$1</a>');

  return result;
}

if (typeof module !== 'undefined' && module.exports) {
  module.exports = { renderMarkdown };
}
