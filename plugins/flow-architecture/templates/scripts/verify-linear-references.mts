#!/usr/bin/env tsx
// Verify the Linear references baked into story-doc front-matter
// (`parent_issue` + `children.{story,engineering,design,qa,docs}`) actually
// resolve to real issues with the right parent-child wiring and discipline
// labels. The 7th `verify-docs.sh` check.
//
// Provenance: shipped by `flow-architecture` plugin templates (BC-11029).
//
// CLI behavior:
//   --no-linear            → exit 0; print skip sentinel for verify-docs.sh
//   LINEAR_API_KEY unset   → exit 0; print skip sentinel
//   PHASE_4_DONE=1|true    → count drift becomes FAIL instead of WARN
//
// The CLI walks every doc under docs/product/flows, calls Linear's GraphQL
// API once (paginated), and prints a human-readable report. Exit code 1 on
// any FAIL finding; 0 otherwise.

import { readFileSync, readdirSync } from "node:fs";
import { join, relative, dirname } from "node:path";
import { fileURLToPath } from "node:url";
import matter from "gray-matter";
import {
  parseTitle,
  TITLE_DISCIPLINE_TO_TYPE_LABEL,
} from "./lib/fda-title.mts";
import { PROJECT_ID, paginate } from "./lib/linear-graphql.mts";

// Expected FDA-scoped issue count for this project's full retrofit close-out.
// Substituted at scaffold time (BC-11029) from .flow/config.json or set to 0.
// A value of 0 disables the count gate (no-op); set to your project's expected
// count once your FDA scope is known (parents + children with `type:*` labels).
//
// Example for a 40-parent / 200-child project: EXPECTED_FDA_ISSUE_COUNT = 240.
export const EXPECTED_FDA_ISSUE_COUNT = <EXPECTED_FDA_ISSUE_COUNT>;

// ---------- types ----------

// Single source of truth: the runtime tuple drives the Discipline union.
// Adding a discipline requires updating one place; the type follows.
export const DISCIPLINES = [
  "story",
  "engineering",
  "design",
  "qa",
  "docs",
] as const;
export type Discipline = (typeof DISCIPLINES)[number];

// Linear label string per discipline. The front-matter key is the canonical
// English word, the label is the team's shorthand.
export const DISCIPLINE_LABELS: Record<Discipline, string> = {
  story: "type:story",
  engineering: "type:eng",
  design: "type:design",
  qa: "type:qa",
  docs: "type:docs",
};

export type ExtractedRef = {
  filePath: string;
  flowId: string;
  parentIssue: string | null;
  children: Partial<Record<Discipline, string>>;
};

export type LinearIssue = {
  identifier: string;
  title: string;
  parentIdentifier: string | null;
  labels: string[];
};

export type ReportFinding =
  | {
      kind: "ref-miss";
      filePath: string;
      flowId: string;
      field: string;
      ref: string;
    }
  | {
      kind: "parent-mismatch";
      filePath: string;
      flowId: string;
      child: Discipline;
      childRef: string;
      docParent: string;
      linearParent: string | null;
    }
  | {
      kind: "label-missing";
      filePath: string;
      flowId: string;
      child: Discipline;
      childRef: string;
      expectedLabel: string;
    }
  | { kind: "count-drift"; expected: number; actual: number }
  // BC-9757 — three label-hygiene gates. They fire on FDA-shaped issues
  // (title starts with a canonical `DOMAIN-NN` or `[Discipline] DOMAIN-NN`
  // prefix); non-FDA `type:*`-labeled issues are correctly skipped.
  | {
      kind: "fda-issue-missing-domain-label";
      identifier: string;
      title: string;
      expectedLabel: string;
    }
  | {
      kind: "fda-parent-missing-type-parent-label";
      identifier: string;
      title: string;
    }
  | {
      kind: "fda-child-missing-type-label";
      identifier: string;
      title: string;
      expectedLabel: string;
    };

// Type alias for the subset of findings produced by `evaluateLabelHygiene`,
// shared between the function signature and the per-issue accumulator.
export type LabelHygieneFinding = Extract<
  ReportFinding,
  | { kind: "fda-issue-missing-domain-label" }
  | { kind: "fda-parent-missing-type-parent-label" }
  | { kind: "fda-child-missing-type-label" }
>;

export type Report = {
  fail: ReportFinding[];
  warn: ReportFinding[];
  ok: number;
};

// ---------- helpers (exported for tests) ----------

const ISSUE_ID_PATTERN = /^[A-Z]+-\d+$/;

export function isResolvableRef(
  ref: string | null | undefined,
): ref is string {
  if (!ref) return false;
  const trimmed = ref.trim();
  if (!trimmed || trimmed === "TBD") return false;
  return ISSUE_ID_PATTERN.test(trimmed);
}

// FDA scope = issues carrying a `type:*` discipline label, plus their unique
// parents (which carry `domain:<x>` instead of `type:*`). Excludes non-FDA
// issues in the same Linear project (infra, bugs, etc.).
export function computeFdaIssueCount(issues: LinearIssue[]): number {
  const fdaLabelSet = new Set<string>(Object.values(DISCIPLINE_LABELS));
  const labeledChildren = issues.filter((i) =>
    i.labels.some((l) => fdaLabelSet.has(l)),
  );
  const parentIds = new Set<string>();
  for (const child of labeledChildren) {
    if (child.parentIdentifier !== null) {
      parentIds.add(child.parentIdentifier);
    }
  }
  return labeledChildren.length + parentIds.size;
}

// Pure count-gate decision. Returns null when actual matches expected OR when
// the expected count is 0 (gate disabled); else a count-drift finding for the
// caller to route into fail or warn based on the PHASE_4_DONE policy.
export function evaluateCountGate(args: {
  fdaIssueCount: number;
  expectedCount: number;
}): { kind: "count-drift"; expected: number; actual: number } | null {
  if (args.expectedCount === 0) return null; // gate disabled
  if (args.fdaIssueCount === args.expectedCount) return null;
  return {
    kind: "count-drift",
    expected: args.expectedCount,
    actual: args.fdaIssueCount,
  };
}

// Internal helper to list every story doc under FLOWS_DIR. Skips index files.
export function listMarkdownRecursive(dir: string): string[] {
  const results: string[] = [];
  for (const entry of readdirSync(dir, { withFileTypes: true })) {
    const full = join(dir, entry.name);
    if (entry.isDirectory()) {
      results.push(...listMarkdownRecursive(full));
    } else if (
      entry.name.endsWith(".md") &&
      entry.name !== "INDEX.md" &&
      entry.name !== "INDEX-archive.md" &&
      entry.name !== "README.md"
    ) {
      results.push(full);
    }
  }
  return results;
}

export function extractReferences(filePath: string): ExtractedRef | null {
  const text = readFileSync(filePath, "utf-8");
  const parsed = matter(text);
  const fm = parsed.data as Record<string, unknown>;
  if (fm.flow_index === "skip") return null;

  const flowId = typeof fm.flow_id === "string" ? fm.flow_id : null;
  if (!flowId) return null;

  const parentIssue =
    typeof fm.parent_issue === "string" ? fm.parent_issue.trim() : null;
  const childrenRaw = fm.children;
  const children: Partial<Record<Discipline, string>> = {};
  if (childrenRaw && typeof childrenRaw === "object") {
    const c = childrenRaw as Record<string, unknown>;
    for (const d of DISCIPLINES) {
      const value = c[d];
      if (typeof value === "string" && value.trim()) {
        children[d] = value.trim();
      }
    }
  }
  return { filePath, flowId, parentIssue, children };
}

export function buildReport(args: {
  refs: ExtractedRef[];
  issues: LinearIssue[];
  phase4Done: boolean;
}): Report {
  const { refs, issues, phase4Done } = args;
  const issueByIdentifier = new Map(
    issues.map((issue) => [issue.identifier, issue] as const),
  );

  const fail: ReportFinding[] = [];
  const warn: ReportFinding[] = [];
  let ok = 0;

  for (const ref of refs) {
    if (isResolvableRef(ref.parentIssue)) {
      if (!issueByIdentifier.has(ref.parentIssue)) {
        fail.push({
          kind: "ref-miss",
          filePath: ref.filePath,
          flowId: ref.flowId,
          field: "parent_issue",
          ref: ref.parentIssue,
        });
      } else {
        ok++;
      }
    }

    for (const discipline of DISCIPLINES) {
      const childRef = ref.children[discipline];
      if (!isResolvableRef(childRef)) continue;
      const childIssue = issueByIdentifier.get(childRef);

      if (!childIssue) {
        fail.push({
          kind: "ref-miss",
          filePath: ref.filePath,
          flowId: ref.flowId,
          field: `children.${discipline}`,
          ref: childRef,
        });
        continue;
      }

      let childHadFail = false;

      // Parent-mismatch check: only meaningful when the doc claims a parent.
      if (
        isResolvableRef(ref.parentIssue) &&
        childIssue.parentIdentifier !== ref.parentIssue
      ) {
        fail.push({
          kind: "parent-mismatch",
          filePath: ref.filePath,
          flowId: ref.flowId,
          child: discipline,
          childRef,
          docParent: ref.parentIssue,
          linearParent: childIssue.parentIdentifier,
        });
        childHadFail = true;
      }

      const expectedLabel = DISCIPLINE_LABELS[discipline];
      if (!childIssue.labels.includes(expectedLabel)) {
        warn.push({
          kind: "label-missing",
          filePath: ref.filePath,
          flowId: ref.flowId,
          child: discipline,
          childRef,
          expectedLabel,
        });
      }

      if (!childHadFail) ok++;
    }
  }

  // Aggregate count gate. Counts FDA-scoped issues only (children carrying a
  // `type:*` label + their parents) — non-FDA project issues are ignored.
  // Disabled when EXPECTED_FDA_ISSUE_COUNT is 0.
  const countFinding = evaluateCountGate({
    fdaIssueCount: computeFdaIssueCount(issues),
    expectedCount: EXPECTED_FDA_ISSUE_COUNT,
  });
  if (countFinding) {
    if (phase4Done) {
      fail.push(countFinding);
    } else {
      warn.push(countFinding);
    }
  }

  // Label-hygiene gates. Walk every issue in the project; if its title parses
  // as a canonical FDA pattern, assert the canonical label pair. Non-FDA-titled
  // issues are skipped.
  for (const issue of issues) {
    fail.push(...evaluateLabelHygiene(issue));
  }

  return { fail, warn, ok };
}

/**
 * Per-issue label-hygiene check. Returns FAIL findings when an FDA-shaped
 * issue lacks any of its canonical labels:
 *
 * - Any FDA-shaped issue missing `domain:<x>` matching its title prefix.
 * - An FDA-shaped parent issue missing `type:parent`.
 * - An FDA-shaped child issue missing the `type:<discipline>` label that
 *   matches its title's `[Story|Eng|Design|QA|Docs]` tag.
 *
 * Returns [] for any issue whose title does not match a canonical FDA pattern.
 */
export function evaluateLabelHygiene(
  issue: LinearIssue,
): LabelHygieneFinding[] {
  const parsed = parseTitle(issue.title);
  if (!parsed) return [];
  const findings: LabelHygieneFinding[] = [];
  const expectedDomainLabel = `domain:${parsed.domain}`;
  if (!issue.labels.includes(expectedDomainLabel)) {
    findings.push({
      kind: "fda-issue-missing-domain-label",
      identifier: issue.identifier,
      title: issue.title,
      expectedLabel: expectedDomainLabel,
    });
  }
  if (parsed.discipline === null) {
    if (!issue.labels.includes("type:parent")) {
      findings.push({
        kind: "fda-parent-missing-type-parent-label",
        identifier: issue.identifier,
        title: issue.title,
      });
    }
  } else {
    const expectedTypeLabel =
      TITLE_DISCIPLINE_TO_TYPE_LABEL[parsed.discipline];
    if (!expectedTypeLabel) {
      throw new Error(
        `Unmapped discipline '${parsed.discipline}' on ${issue.identifier} (${issue.title}) — TITLE_DISCIPLINE_TO_TYPE_LABEL needs updating`,
      );
    }
    if (!issue.labels.includes(expectedTypeLabel)) {
      findings.push({
        kind: "fda-child-missing-type-label",
        identifier: issue.identifier,
        title: issue.title,
        expectedLabel: expectedTypeLabel,
      });
    }
  }
  return findings;
}

export function formatReport(report: Report): string {
  const lines: string[] = [];
  lines.push(
    `    refs verified: ${report.ok} ok · ${report.fail.length} fail · ${report.warn.length} warn`,
  );
  for (const f of report.fail) {
    lines.push(`    FAIL ${formatFinding(f)}`);
  }
  for (const w of report.warn) {
    lines.push(`    WARN ${formatFinding(w)}`);
  }
  return lines.join("\n");
}

function formatFinding(f: ReportFinding): string {
  switch (f.kind) {
    case "ref-miss":
      return `${f.flowId} (${f.filePath}): ${f.field} → ${f.ref} not found in Linear project`;
    case "parent-mismatch":
      return `${f.flowId} (${f.filePath}): children.${f.child}=${f.childRef} parent is ${f.linearParent ?? "(none)"} on Linear, but doc says ${f.docParent}`;
    case "label-missing":
      return `${f.flowId} (${f.filePath}): children.${f.child}=${f.childRef} missing label ${f.expectedLabel}`;
    case "count-drift":
      return `FDA-scoped issue count is ${f.actual}; expected ${f.expected} for retrofit close-out (parents + children with type:* labels)`;
    case "fda-issue-missing-domain-label":
      return `${f.identifier} (${f.title.slice(0, 60)}…): missing canonical label ${f.expectedLabel}`;
    case "fda-parent-missing-type-parent-label":
      return `${f.identifier} (${f.title.slice(0, 60)}…): parent missing canonical label type:parent`;
    case "fda-child-missing-type-label":
      return `${f.identifier} (${f.title.slice(0, 60)}…): child missing canonical label ${f.expectedLabel}`;
    default: {
      const _exhaustive: never = f;
      return _exhaustive;
    }
  }
}

// ---------- Linear API ----------

type GraphQLIssueNode = {
  identifier: string;
  title: string;
  parent: { identifier: string } | null;
  labels: { nodes: Array<{ name: string }> };
};

const ISSUES_QUERY = /* GraphQL */ `
  query Issues($projectId: ID!, $cursor: String) {
    issues(
      filter: { project: { id: { eq: $projectId } } }
      first: 250
      after: $cursor
    ) {
      nodes {
        identifier
        title
        parent {
          identifier
        }
        labels {
          nodes {
            name
          }
        }
      }
      pageInfo {
        hasNextPage
        endCursor
      }
    }
  }
`;

export async function fetchLinearIssues(
  apiKey: string,
  projectId: string = PROJECT_ID,
): Promise<LinearIssue[]> {
  const nodes = await paginate<
    GraphQLIssueNode,
    { projectId: string },
    "issues"
  >(apiKey, ISSUES_QUERY, { projectId }, "issues");
  return nodes.map((node) => ({
    identifier: node.identifier,
    title: node.title,
    parentIdentifier: node.parent?.identifier ?? null,
    labels: node.labels.nodes.map((l) => l.name),
  }));
}

// ---------- CLI ----------

const REPO_ROOT = join(dirname(fileURLToPath(import.meta.url)), "..");
const FLOWS_DIR = join(REPO_ROOT, "docs/product/flows");

function envFlagTrue(value: string | undefined): boolean {
  if (!value) return false;
  const v = value.trim().toLowerCase();
  return v === "1" || v === "true" || v === "yes";
}

async function main(): Promise<void> {
  const noLinear = process.argv.slice(2).includes("--no-linear");
  const apiKey = process.env.LINEAR_API_KEY;
  const phase4Done = envFlagTrue(process.env.PHASE_4_DONE);

  if (noLinear || !apiKey) {
    const reason = noLinear ? "--no-linear passed" : "LINEAR_API_KEY unset";
    console.log(`    skipped: ${reason}`);
    process.exit(0);
  }

  const files = listMarkdownRecursive(FLOWS_DIR);
  const refs: ExtractedRef[] = [];
  for (const file of files) {
    const ref = extractReferences(file);
    if (ref) {
      ref.filePath = relative(REPO_ROOT, file);
      refs.push(ref);
    }
  }

  if (refs.length === 0) {
    console.log("    no resolvable story-doc references found");
    process.exit(0);
  }

  const issues = await fetchLinearIssues(apiKey);
  const report = buildReport({ refs, issues, phase4Done });

  console.log(formatReport(report));

  if (report.fail.length > 0) {
    process.exit(1);
  }
  process.exit(0);
}

if (process.argv[1] === fileURLToPath(import.meta.url)) {
  main().catch((err) => {
    console.error(`    FAIL ${err instanceof Error ? err.message : String(err)}`);
    process.exit(1);
  });
}
