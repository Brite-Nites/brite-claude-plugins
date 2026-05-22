#!/usr/bin/env node
/**
 * Normalize FDA story-doc frontmatter to the regenerate-flow-index.mts contract.
 *
 * Provenance: SKELETON shipped by `flow-architecture` plugin templates (BC-11029).
 *
 * This is a starting-point skeleton, NOT a finished reference impl. The data
 * tables below (PARENT_ISSUES, DISPLAY_NAMES, STATUS_OVERRIDES, DOMAIN_FOLDER)
 * are inherently project-specific — populate them with your project's flow
 * inventory before running. Without populated tables, the script is a no-op.
 *
 * Reads each docs/product/flows/<domain>/<FLOW-ID>.md, merges contract fields
 * with existing fields per the preservation rule, writes back.
 *
 * Recommended use: as a one-shot migration script after a retrofit when you
 * need to bring existing FDA-shaped story docs into compliance with the
 * regenerate-flow-index.mts contract.
 */

import fs from 'node:fs';
import path from 'node:path';
import { fileURLToPath } from 'node:url';
import matter from 'gray-matter';

const __filename = fileURLToPath(import.meta.url);
const REPO_ROOT = path.resolve(path.dirname(__filename), '..');
const FLOWS_DIR = path.join(REPO_ROOT, 'docs/product/flows');

// TODO: populate per-project. Map every FLOW-ID to its Linear parent issue ID.
// Example shape:
//   { 'IDN-01': 'BC-10764', 'IDN-02': 'BC-10778', ... }
const PARENT_ISSUES = {};

// TODO: populate per-project. Map every FLOW-ID to its display name from
// master-flow-inventory.md.
const DISPLAY_NAMES = {};

// TODO: populate per-project. Per-flow status overrides; default for any
// flow not in this table is { status: 'NOT_STARTED', eng_status: 'not-started' }.
// Example: { 'ACL-01': { status: 'BUILT', eng_status: 'done' } }.
const STATUS_OVERRIDES = {};

// TODO: populate per-project. Map 3-letter domain code -> domain folder slug
// matching the actual folder layout under docs/product/flows/.
// Example: { IDN: 'identity-directory', LSM: 'lifecycle-state-machine' }
const DOMAIN_FOLDER = {};

// All FLOW-IDs derived from PARENT_ISSUES — keeps the data tables aligned.
const ALL_FLOWS = Object.keys(PARENT_ISSUES);

const LAST_REVIEWED = new Date().toISOString().slice(0, 10);

const report = [];
const errors = [];

if (ALL_FLOWS.length === 0) {
  process.stdout.write(JSON.stringify({
    status: 'no-op',
    note: 'PARENT_ISSUES table is empty — populate the data tables in this script to enable normalization.',
    story_docs_normalized: [],
    errors: [],
  }, null, 2) + '\n');
  process.exit(0);
}

for (const flowId of ALL_FLOWS) {
  const code = flowId.split('-')[0];
  const folder = DOMAIN_FOLDER[code];
  if (!folder) {
    errors.push({ flow_id: flowId, error: `unknown domain code ${code}` });
    continue;
  }
  const filePath = path.join(FLOWS_DIR, folder, `${flowId}.md`);
  if (!fs.existsSync(filePath)) {
    errors.push({ flow_id: flowId, error: `file not found: ${filePath}` });
    continue;
  }

  const raw = fs.readFileSync(filePath, 'utf8');
  const parsed = matter(raw);
  const existing = parsed.data || {};
  let body = parsed.content;

  const override = STATUS_OVERRIDES[flowId] || {};
  const newStatus = override.status || 'NOT_STARTED';
  const newEngStatus = override.eng_status || 'not-started';

  // Contract-required fields. Preservation rule: keep existing values only
  // where they match the regen-contract domain. For `status`, `domain`,
  // `eng_status`, etc., we overwrite slug-style legacy values with the
  // contract taxonomy.
  const contract = {
    flow_id: flowId,
    domain: code,
    display_name: existing.display_name || DISPLAY_NAMES[flowId],
    status: newStatus,
    parent_issue: PARENT_ISSUES[flowId],
    qa_status: 'not-tested',
    eng_status: newEngStatus,
    design_status: 'not-started',
    docs_status: 'not-started',
    figma: existing.figma || 'TBD',
    last_reviewed: LAST_REVIEWED,
  };

  const merged = { ...existing };

  if (!merged.linear_parent && PARENT_ISSUES[flowId]) {
    merged.linear_parent = PARENT_ISSUES[flowId];
  }

  const fieldsAdded = [];
  const fieldsPreserved = Object.keys(existing).filter(
    (k) => !Object.keys(contract).includes(k) || (k === 'display_name' && existing.display_name)
  );

  for (const [k, v] of Object.entries(contract)) {
    if (!(k in existing)) {
      fieldsAdded.push(k);
    } else if (existing[k] !== v) {
      fieldsAdded.push(`${k}(normalized)`);
    }
    merged[k] = v;
  }

  const ordered = {};
  const contractOrder = [
    'flow_id', 'domain', 'display_name', 'status', 'parent_issue',
    'qa_status', 'eng_status', 'design_status', 'docs_status',
    'figma', 'last_reviewed', 'linear_parent',
  ];
  for (const k of contractOrder) {
    if (k in merged) ordered[k] = merged[k];
  }
  for (const k of Object.keys(merged)) {
    if (!(k in ordered)) ordered[k] = merged[k];
  }

  // Normalize H1 to `# <FLOW-ID>: <Display Name>`
  const expectedH1 = `# ${flowId}: ${DISPLAY_NAMES[flowId]}`;
  const h1Re = /^#\s+[A-Z]+-\d+\s*[:—–-]\s*.+$/m;
  if (h1Re.test(body)) {
    body = body.replace(h1Re, expectedH1);
  } else {
    if (!/^#\s+/m.test(body.trimStart())) {
      body = `${expectedH1}\n\n${body}`;
    }
  }

  const output = matter.stringify(body, ordered, { lineWidth: -1 });

  fs.writeFileSync(filePath, output, 'utf8');

  report.push({
    path: path.relative(REPO_ROOT, filePath),
    fields_added: fieldsAdded,
    fields_preserved: fieldsPreserved,
  });
}

const summary = {
  status: errors.length === 0 ? 'success' : 'partial',
  story_docs_normalized: report,
  errors,
};

process.stdout.write(JSON.stringify(summary, null, 2) + '\n');
