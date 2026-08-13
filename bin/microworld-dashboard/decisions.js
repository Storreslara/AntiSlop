#!/usr/bin/env node
'use strict';

// Read-only enumeration of the four human-decision touchpoints: escalations,
// milestone-briefing candidates (docs/plans/*.md), milestone findings
// records, and pending-review flags joined to their unit. Reads only --
// never touches discover.js or GET /api/bundles (D-7). Fails soft per
// entry, matching discover.js's convention: malformed or missing input is
// flagged on the entry, never thrown.

const fs = require('fs');
const path = require('path');

function listFiles(dirPath) {
  try {
    return fs.readdirSync(dirPath);
  } catch (err) {
    return [];
  }
}

function enumerateEscalations(projectRoot) {
  const reviewedDir = path.join(projectRoot, '.claude', 'reviewed');
  const escalations = [];

  for (const name of listFiles(reviewedDir)) {
    if (!name.endsWith('.escalated')) continue;
    const taskId = name.slice(0, -'.escalated'.length);

    let firstLine = '';
    try {
      firstLine = fs.readFileSync(path.join(reviewedDir, name), 'utf8').split('\n', 1)[0];
    } catch (err) {
      continue; // unreadable marker -- nothing to report for this file
    }

    const match = firstLine.match(/^ESCALATE-TO-HUMAN (\S+) (\S+) trigger: (.*) microworld: (\S+)$/);
    const entry = {
      taskId,
      timestamp: match ? match[2] : null,
      trigger: match ? match[3] : null,
      microworld: match ? match[4] : null,
      packetMissing: false,
      packetBody: null,
    };

    try {
      entry.packetBody = fs.readFileSync(path.join(projectRoot, '.claude', 'human-review', taskId, 'PACKET.md'), 'utf8');
    } catch (err) {
      entry.packetMissing = true;
    }

    escalations.push(entry);
  }

  return escalations;
}

function enumerateBriefings(projectRoot) {
  const plansDir = path.join(projectRoot, 'docs', 'plans');
  const briefings = [];

  for (const name of listFiles(plansDir).sort()) {
    if (!name.endsWith('.md')) continue;

    let heading = null;
    try {
      const content = fs.readFileSync(path.join(plansDir, name), 'utf8');
      const headingLine = content.split('\n').find((line) => line.startsWith('# '));
      heading = headingLine ? headingLine.slice(2).trim() : null;
    } catch (err) {
      // unreadable -- still list the path, heading stays null
    }

    briefings.push({ path: path.join('docs', 'plans', name), heading });
  }

  return briefings;
}

function enumerateFindings(projectRoot) {
  const auditDir = path.join(projectRoot, '.claude', 'milestone-audit');
  const findings = [];

  for (const slug of listFiles(auditDir)) {
    let content;
    try {
      content = fs.readFileSync(path.join(auditDir, slug, 'FINDINGS.md'), 'utf8');
    } catch (err) {
      continue; // no FINDINGS.md here -- not a findings record
    }

    const lines = content.split('\n');
    const body = lines.slice(1).join('\n');
    const match = (lines[0] || '').match(/^FINDINGS (\S+) (\S+) count: (\d+)$/);

    if (!match) {
      findings.push({ slug, timestamp: null, count: null, body, malformed: true, malformedReason: 'first line does not parse' });
      continue;
    }

    findings.push({ slug: match[1], timestamp: match[2], count: parseInt(match[3], 10), body, malformed: false });
  }

  return findings;
}

// The newest .review-join.<unit-id> stamp with no .pass marker written after
// it (D-5) -- the unit a standing pending-review flag is presumed to be
// waiting on. Returns null when no such stamp exists. Filename-derived,
// matching ADR-0016's path grammar; a unit-id containing a path separator is
// skipped, mirroring the traversal guard reviewer-route-gate.sh applies
// before writing it.
function joinPendingReviewUnit(projectRoot) {
  const dotDir = path.join(projectRoot, '.claude');
  const reviewedDir = path.join(dotDir, 'reviewed');
  let newest = null;

  for (const name of listFiles(dotDir)) {
    if (!name.startsWith('.review-join.')) continue;
    const unitId = name.slice('.review-join.'.length);
    if (!unitId || unitId.includes('/') || unitId.includes('..')) continue;

    let stampMtime;
    try {
      stampMtime = fs.statSync(path.join(dotDir, name)).mtimeMs;
    } catch (err) {
      continue;
    }

    let passWrittenAfter = false;
    try {
      passWrittenAfter = fs.statSync(path.join(reviewedDir, `${unitId}.pass`)).mtimeMs > stampMtime;
    } catch (err) {
      // no .pass marker -- nothing written after the stamp
    }
    if (passWrittenAfter) continue;

    if (!newest || stampMtime > newest.stampMtime) {
      newest = { unitId, stampMtime };
    }
  }

  return newest ? newest.unitId : null;
}

function enumeratePendingReview(projectRoot) {
  const dotDir = path.join(projectRoot, '.claude');
  const pendingReview = [];
  const unit = joinPendingReviewUnit(projectRoot);

  for (const name of listFiles(dotDir)) {
    if (!name.startsWith('.pending-review.')) continue;
    const flagPath = path.join(dotDir, name);

    let content;
    try {
      content = fs.readFileSync(flagPath, 'utf8');
    } catch (err) {
      continue; // flag vanished mid-read -- nothing to report
    }

    const entry = { agentId: name.slice('.pending-review.'.length), state: 'pending', reason: null, timestamp: null, unit };

    if (content.startsWith('defer: ')) {
      entry.state = 'deferred';
      entry.reason = content.slice('defer: '.length).replace(/\n$/, '');
    } else {
      const match = content.match(/^(\S+) agent=\S+/);
      entry.timestamp = match ? match[1] : null;
    }

    pendingReview.push(entry);
  }

  return pendingReview;
}

function enumerateDecisions(projectRoot) {
  return {
    escalations: enumerateEscalations(projectRoot),
    briefings: enumerateBriefings(projectRoot),
    findings: enumerateFindings(projectRoot),
    pendingReview: enumeratePendingReview(projectRoot),
  };
}

module.exports = { enumerateDecisions };
