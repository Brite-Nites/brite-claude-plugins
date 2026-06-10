#!/usr/bin/env tsx
// Regenerate docs/product/flows/INDEX.md from story-doc front-matter.
// Pass --check to exit non-zero (without writing) if INDEX.md is out of date.
//
// Provenance: shipped by `flow-architecture` plugin templates (BC-11029).
// Per-discipline emoji policy: Eng/Design/Docs derive from `eng_status` /
// `design_status` / `docs_status` front-matter via `disciplineEmoji` (5-state
// taxonomy). QA derives from `qa_status` via `qaEmoji` (separate value set).
//
// Placeholder substituted at scaffold time:
//   <LINEAR_ORG_SLUG> — Linear workspace slug (the `<slug>` in https://linear.app/<slug>/...)
//   <PROJECT_NAME>    — display name for the consuming project's flow index

import { readFileSync, writeFileSync, readdirSync, statSync } from "node:fs";
import { join, relative, dirname, basename } from "node:path";
import { fileURLToPath } from "node:url";
import matter from "gray-matter";

const REPO_ROOT = (() => {
  const here = dirname(fileURLToPath(import.meta.url));
  return join(here, "..");
})();
const FLOWS_DIR = join(REPO_ROOT, "docs/product/flows");
const INVENTORY_PATH = join(REPO_ROOT, "docs/product/master-flow-inventory.md");
const INDEX_PATH = join(FLOWS_DIR, "INDEX.md");
const LINEAR_ORG = "<LINEAR_ORG_SLUG>";

export type Row = {
  flowId: string;
  domain: string;
  flowTitle: string;
  status: string;
  parentIssue: string;
  qaStatus: string;
  engStatus: string;
  designStatus: string;
  docsStatus: string;
  figma: string;
  liveUrl: string;
  storyPath: string;
};

export type DomainEntry = { code: string; display: string };

// ---------- helpers (exported for tests) ----------

export function qaEmoji(qa: string | null | undefined): string {
  switch ((qa ?? "").trim()) {
    case "signed-off":
      return "✓";
    case "failed":
    case "regression":
      return "❌";
    case "not-tested":
    case "":
    default:
      return "⏳";
  }
}

// Mirrors `qaEmoji` shape but uses the 5-state per-discipline taxonomy from
// `eng_status` / `design_status` / `docs_status` front-matter. Unknown / missing
// values default to ⏳ (matches `qaEmoji`'s safe-default policy).
export function disciplineEmoji(status: string | null | undefined): string {
  switch ((status ?? "").trim()) {
    case "done":
      return "✓";
    case "in-progress":
      return "🚧";
    case "blocked":
      return "❌";
    case "n/a":
      return "—";
    case "not-started":
    case "":
    default:
      return "⏳";
  }
}

export function numericSuffix(flowId: string): number {
  const match = flowId.match(/-(\d+)/);
  if (!match) return Number.MAX_SAFE_INTEGER;
  return Number.parseInt(match[1]!, 10);
}

export function parentCell(parent: string | null | undefined): string {
  const p = (parent ?? "").trim();
  if (!p || p === "TBD") return "TBD";
  if (/^[A-Z]+-\d+$/.test(p)) {
    return `[${p}](https://linear.app/${LINEAR_ORG}/issue/${p})`;
  }
  return p;
}

export function liveCell(url: string | null | undefined): string {
  const u = (url ?? "").trim();
  if (!u || u === "TBD") return "TBD";
  return `[${u}](${u})`;
}

export function pickLiveUrl(
  sandbox: string | null | undefined,
  staging: string | null | undefined,
  realApp: string | null | undefined,
): string {
  for (const candidate of [sandbox, staging, realApp]) {
    const v = (candidate ?? "").trim();
    if (v && v !== "TBD") return v;
  }
  return "TBD";
}

export function figmaCell(figma: string | null | undefined): string {
  const f = (figma ?? "").trim();
  if (!f || f === "TBD") return "TBD";
  if (/^https?:\/\//.test(f)) return `[frame](${f})`;
  return f;
}

// Escape pipes in a markdown table cell so a flow title like "Edit name | role"
// doesn't silently corrupt the row. GitHub-flavored markdown spec uses backslash-pipe.
export function escapeCell(text: string): string {
  return text.replace(/\|/g, "\\|");
}

export function renderTable(rows: Row[]): string {
  const header =
    "| ID | Flow | Status | Story | Parent | Eng | Design | QA | Docs | Figma | Live |\n" +
    "|---|---|---|---|---|---|---|---|---|---|---|";
  const body = rows
    .map((r) => {
      const story = `[📄](${r.storyPath})`;
      const parent = parentCell(r.parentIssue);
      const eng = disciplineEmoji(r.engStatus);
      const design = disciplineEmoji(r.designStatus);
      const qa = qaEmoji(r.qaStatus);
      const docs = disciplineEmoji(r.docsStatus);
      const figma = figmaCell(r.figma);
      const live = liveCell(r.liveUrl);
      return `| ${r.flowId} | ${escapeCell(r.flowTitle)} | ${r.status} | ${story} | ${parent} | ${eng} | ${design} | ${qa} | ${docs} | ${figma} | ${live} |`;
    })
    .join("\n");
  return `${header}\n${body}`;
}

// ---------- parsers ----------

function listMarkdownRecursive(dir: string): string[] {
  const entries = readdirSync(dir);
  const results: string[] = [];
  for (const entry of entries) {
    const full = join(dir, entry);
    const stat = statSync(full);
    if (stat.isDirectory()) {
      results.push(...listMarkdownRecursive(full));
    } else if (entry.endsWith(".md")) {
      const base = basename(entry);
      if (base === "INDEX.md" || base === "INDEX-archive.md" || base === "README.md") continue;
      results.push(full);
    }
  }
  return results;
}

export function parseDomainOrder(inventoryText: string): DomainEntry[] {
  const order: DomainEntry[] = [];
  const seen = new Set<string>();
  for (const line of inventoryText.split(/\r?\n/)) {
    // Match: "### <DOMAIN> — <Display> (N flows)" (em-dash, U+2014) and en-dash
    // (U+2013) and ASCII hyphen defensively. Display name may contain its own
    // parentheticals — only the trailing "(N flows)" suffix is stripped.
    const m = line.match(/^###\s+`?([A-Za-z][A-Za-z0-9-]*)`?\s+[—–-]\s+(.+?)(?:\s*\(\d+\s+flows?\))?\s*$/);
    if (!m) continue;
    const code = m[1]!;
    const display = m[2]!.trim();
    if (seen.has(code)) continue;
    seen.add(code);
    order.push({ code, display });
  }
  return order;
}

function extractH1Title(content: string, flowId: string): string {
  for (const line of content.split(/\r?\n/)) {
    const m = line.match(/^#\s+(.+?)\s*$/);
    if (!m) continue;
    const heading = m[1]!;
    // Heading shape: "DOMAIN-NN: Flow title"
    const colonIdx = heading.indexOf(":");
    if (colonIdx > 0 && heading.slice(0, colonIdx).trim() === flowId) {
      return heading.slice(colonIdx + 1).trim();
    }
    // Fallback: any H1 — return as-is and warn.
    return heading;
  }
  return "";
}

export function parseRow(filePath: string, repoRoot: string): Row | null {
  const text = readFileSync(filePath, "utf-8");
  const parsed = matter(text);
  const fm = parsed.data as Record<string, unknown>;
  // Legacy narrative docs (e.g. flow-domain overviews) can opt out of indexing
  // by setting `flow_index: skip` in front-matter — silent skip, no warning.
  if (fm.flow_index === "skip") {
    return null;
  }
  const flowId = typeof fm.flow_id === "string" ? fm.flow_id : null;
  const domain = typeof fm.domain === "string" ? fm.domain : null;
  if (!flowId || !domain) {
    console.warn(`  ⚠ ${relative(repoRoot, filePath)}: missing flow_id or domain — skipping`);
    return null;
  }
  // Status must be one of the 6-value INDEX taxonomy. An unknown value (a
  // lowercase `not-started`, a `draft`, a typo) is coerced to NOT_STARTED with a
  // warning rather than printed raw into the INDEX — unlike the discipline
  // columns below, status had no validation. The deterministic guard upstream is
  // the BC-13029 status A-lint; this is the render-time backstop. (BC-13028 #2.)
  const STATUS_TAXONOMY = ["NOT_STARTED", "IN_PROGRESS", "BUILT", "QA_SIGNED_OFF", "SHIPPED", "BLOCKED"];
  const rawStatus = typeof fm.status === "string" ? fm.status : "NOT_STARTED";
  let status = rawStatus;
  if (!STATUS_TAXONOMY.includes(status)) {
    console.warn(`  ⚠ ${relative(repoRoot, filePath)}: status "${rawStatus}" not in taxonomy {${STATUS_TAXONOMY.join("|")}} — coercing to NOT_STARTED`);
    status = "NOT_STARTED";
  }
  const parentIssue = typeof fm.parent_issue === "string" ? fm.parent_issue : "TBD";
  const qaStatus = typeof fm.qa_status === "string" ? fm.qa_status : "not-tested";
  const engStatus = typeof fm.eng_status === "string" ? fm.eng_status : "not-started";
  const designStatus = typeof fm.design_status === "string" ? fm.design_status : "not-started";
  const docsStatus = typeof fm.docs_status === "string" ? fm.docs_status : "not-started";
  const figma = typeof fm.figma === "string" ? fm.figma : "TBD";
  const sandboxUrl = typeof fm.sandbox_url === "string" ? fm.sandbox_url : "";
  const stagingUrl = typeof fm.staging_url === "string" ? fm.staging_url : "";
  const realAppUrl = typeof fm.real_app_url === "string" ? fm.real_app_url : "";
  const liveUrl = pickLiveUrl(sandboxUrl, stagingUrl, realAppUrl);
  const storyPath = `./${relative(FLOWS_DIR, filePath).split(/[\\/]/).join("/")}`;
  const flowTitle = extractH1Title(parsed.content, flowId);
  if (!flowTitle) {
    console.warn(`  ⚠ ${relative(repoRoot, filePath)}: no H1 title found — using flow_id as fallback`);
  }
  return {
    flowId,
    domain,
    flowTitle: flowTitle || flowId,
    status,
    parentIssue,
    qaStatus,
    engStatus,
    designStatus,
    docsStatus,
    figma,
    liveUrl,
    storyPath,
  };
}

// ---------- header ----------

const HEADER_BODY = `# Flow Index

Master cross-reference table for every user-facing action in <PROJECT_NAME>. One row per sub-flow. Generated from story-doc front-matter — see \`scripts/regenerate-flow-index.sh\`.

> **Don't hand-edit this file.** It's regenerated from \`docs/product/flows/**/*.md\` front-matter. Run \`bash scripts/regenerate-flow-index.sh\` after any story-doc front-matter change.

**Section order:** domains appear in master-inventory order. Matches \`docs/product/master-flow-inventory.md\` exactly.

**Status taxonomy** (derived from 5-discipline progression — \`Story → Eng + Design → QA → Docs\`):

- \`NOT_STARTED\` — no story written, no work
- \`IN_PROGRESS\` — story committed; eng and/or design in flight
- \`BUILT\` — eng + design complete; awaiting QA
- \`QA_SIGNED_OFF\` — QA passed; customer-facing docs pending
- \`SHIPPED\` — all five disciplines complete (story + eng + design + QA + customer-facing doc)
- \`BLOCKED\` — orthogonal flag; any of the above states can also be blocked

**Discipline status emoji:**

- ✓ done / signed off
- 🚧 in progress / built but not signed off
- ⏳ not started
- ❌ blocked
- — n/a

**Columns:**

- **ID** — flow inventory ID (stable foreign key)
- **Flow** — short title from master inventory
- **Status** — overall flow status (see taxonomy above)
- **Story** — link to story doc
- **Parent** — Linear parent issue
- **Eng / Design / QA / Docs** — discipline child issue status
- **Figma** — frame URL (visual artifact for the Design discipline)
- **Live** — sandbox URL (or staging / real-app URL once available)

---
`;

// ---------- main ----------

export type RenderInput = {
  domainOrder: DomainEntry[];
  rows: Row[];
};

export function renderIndex(input: RenderInput, lastReviewed: string): string {
  const { domainOrder, rows } = input;
  const byDomain = new Map<string, Row[]>();
  for (const row of rows) {
    if (!byDomain.has(row.domain)) byDomain.set(row.domain, []);
    byDomain.get(row.domain)!.push(row);
  }
  for (const list of byDomain.values()) {
    list.sort((a, b) => {
      const an = numericSuffix(a.flowId);
      const bn = numericSuffix(b.flowId);
      if (an !== bn) return an - bn;
      return a.flowId.localeCompare(b.flowId);
    });
  }

  const sections: string[] = [];
  const orderedCodes = new Set<string>();
  for (const { code, display } of domainOrder) {
    orderedCodes.add(code);
    const list = byDomain.get(code);
    if (!list || list.length === 0) continue;
    sections.push(`## ${code} — ${display}\n\n${renderTable(list)}\n`);
  }
  const orphanDomains = [...byDomain.keys()].filter((d) => !orderedCodes.has(d)).sort();
  for (const code of orphanDomains) {
    const list = byDomain.get(code)!;
    sections.push(`## ${code} (NOT IN INVENTORY)\n\n${renderTable(list)}\n`);
  }

  const frontMatter = `---\nlast_reviewed: ${lastReviewed}\ngenerated: true\n---\n`;
  return `${frontMatter}${HEADER_BODY}\n${sections.join("\n")}`;
}

function todayISO(): string {
  return new Date().toISOString().slice(0, 10);
}

export function existingLastReviewed(text: string): string | null {
  if (!text) return null;
  const parsed = matter(text);
  const lr = (parsed.data as Record<string, unknown>).last_reviewed;
  if (typeof lr === "string") return lr;
  if (lr instanceof Date) return lr.toISOString().slice(0, 10);
  return null;
}

// Canonical body signature: parses front-matter via gray-matter (so it's
// robust to quoting / whitespace / key-order drift), drops `last_reviewed`,
// and serializes the rest plus the content. Two texts share a signature iff
// they would round-trip to the same logical state ignoring `last_reviewed`.
export function bodySignature(text: string): string {
  if (!text) return "";
  const parsed = matter(text);
  const data: Record<string, unknown> = { ...(parsed.data as Record<string, unknown>) };
  delete data.last_reviewed;
  const sortedKeys = Object.keys(data).sort();
  const dataStr = sortedKeys.map((k) => `${k}=${JSON.stringify(data[k])}`).join("|");
  return `${dataStr}\n---\n${parsed.content}`;
}

// Pure idempotency core, extracted from main() so tests can exercise it
// without filesystem mocking. Returns the text that should be written.
export function decideOutput(args: {
  existingText: string;
  today: string;
  renderWithDate: (date: string) => string;
}): string {
  const { existingText, today, renderWithDate } = args;
  const candidateToday = renderWithDate(today);
  const candidateSig = bodySignature(candidateToday);
  const existingSig = bodySignature(existingText);
  if (candidateSig === existingSig) {
    return existingText;
  }
  const preservedLR = existingLastReviewed(existingText);
  if (preservedLR) {
    const candidateWithPreserved = renderWithDate(preservedLR);
    if (bodySignature(candidateWithPreserved) === existingSig) {
      return candidateWithPreserved;
    }
  }
  return candidateToday;
}

function main(): void {
  const args = new Set(process.argv.slice(2));
  const checkMode = args.has("--check");

  const inventoryText = readFileSync(INVENTORY_PATH, "utf-8");
  const domainOrder = parseDomainOrder(inventoryText);
  if (domainOrder.length === 0) {
    console.error(`✗ Found zero domain headings in ${relative(REPO_ROOT, INVENTORY_PATH)} — refusing to regenerate`);
    process.exit(2);
  }

  const files = listMarkdownRecursive(FLOWS_DIR);
  const rows: Row[] = [];
  for (const file of files) {
    const row = parseRow(file, REPO_ROOT);
    if (row) rows.push(row);
  }
  if (rows.length === 0) {
    console.error(`✗ Found zero parseable story docs under ${relative(REPO_ROOT, FLOWS_DIR)} — refusing to regenerate`);
    process.exit(2);
  }

  // Read existing INDEX.md if present. In --check mode a missing file is a clear failure
  // ("regenerate it"); on the write path it's fine — we'll create it fresh.
  let existingText: string;
  try {
    existingText = readFileSync(INDEX_PATH, "utf-8");
  } catch (err) {
    if ((err as NodeJS.ErrnoException).code === "ENOENT") {
      if (checkMode) {
        console.error(`✗ ${relative(REPO_ROOT, INDEX_PATH)} does not exist. Run \`bash scripts/regenerate-flow-index.sh\` and commit.`);
        process.exit(1);
      }
      existingText = "";
    } else {
      throw err;
    }
  }

  // Idempotent last_reviewed: signature-based body comparison, robust to
  // whitespace/quote/key-order drift in the existing front-matter.
  const finalOutput = decideOutput({
    existingText,
    today: todayISO(),
    renderWithDate: (date) => renderIndex({ domainOrder, rows }, date),
  });

  if (checkMode) {
    if (finalOutput !== existingText) {
      console.error("✗ INDEX.md is out of date. Run `bash scripts/regenerate-flow-index.sh` and commit.");
      process.exit(1);
    }
    console.log("✓ INDEX.md is up to date");
    return;
  }

  if (finalOutput === existingText) {
    console.log("✓ INDEX.md already current — no changes");
    return;
  }
  writeFileSync(INDEX_PATH, finalOutput);
  console.log(`✓ Regenerated ${relative(REPO_ROOT, INDEX_PATH)} (${rows.length} rows across ${domainOrder.length} ordered domains)`);
}

// Run only when executed directly (not when imported by tests).
const invokedFromCli = (() => {
  try {
    return process.argv[1] === fileURLToPath(import.meta.url);
  } catch {
    return false;
  }
})();
if (invokedFromCli) {
  main();
}
