// Canonical FDA-issue title parser.
//
// Provenance: shipped by `flow-architecture` plugin templates (BC-11029).
//
// Used by `scripts/verify-linear-references.mts` (to gate the label-hygiene
// assertions to FDA-shaped issues, excluding handoff workflow false-positives
// like `[Frontend Handoff] Design sandbox mockup …`).
//
// If you add a project-side label-hygiene backfill script (e.g.,
// `backfill-fda-domain-labels.mts`), import from this module so the two
// stay in sync — divergence between consumers would let drift through.

// FDA domain codes for this project. POPULATE this set with your project's
// canonical 3-letter domain codes (matching the codes in
// `docs/product/master-flow-inventory.md`) to enable the label-hygiene gate
// in verify-linear-references.mts.
//
// Empty set = gate disabled (no-op). The verify-linear script gracefully
// handles an empty domain set by skipping the BC-9757-style label-hygiene
// checks; ref-resolution + parent-mismatch checks still run.
//
// Example shape:
//   export const FDA_DOMAINS: ReadonlySet<string> = new Set([
//     "IDN", "LSM", "WIX",  // v1 domains
//     "BWP", "HCP",         // fast-follow domains
//   ]);
export const FDA_DOMAINS: ReadonlySet<string> = new Set<string>([
  // TODO: populate per-project. See comment block above.
]);

// Maps the title-case discipline strings used in Linear issue titles (`[Eng]`,
// `[Docs]`, etc.) to the canonical `type:<x>` label names. Distinct from
// `DISCIPLINE_LABELS` in verify-linear-references.mts which keys on the
// lowercase front-matter discipline string.
export const TITLE_DISCIPLINE_TO_TYPE_LABEL: Record<string, string> = {
  Story: "type:story",
  Eng: "type:eng",
  Design: "type:design",
  QA: "type:qa",
  Docs: "type:docs",
};

// Three legitimate canonical FDA patterns — anything else (e.g., a
// `[Rework: eng]` follow-up, a `[Frontend Handoff]` infra issue, or a
// `[Backend Handoff]` work item) must NOT match, otherwise we'd treat
// non-canonical issues as FDA-shaped:
//
//   ^[Discipline] DOMAIN-NN[:\s]    (child, leading bracket)
//   ^DOMAIN-NN [Discipline]\b       (child, trailing bracket — discipline must be canonical)
//   ^DOMAIN-NN:                     (parent, strict colon after number)
const LEADING_BRACKET_CHILD = /^\[(Story|Eng|Design|QA|Docs)\]\s+([A-Z]+)-(\d{1,3})[:\s]/;
const TRAILING_BRACKET_CHILD = /^([A-Z]+)-(\d{1,3})\s+\[(Story|Eng|Design|QA|Docs)\]/;
const PARENT_WITH_COLON = /^([A-Z]+)-(\d{1,3}):/;

export type ParsedTitle = {
  /** Lowercase domain code (e.g., "appt", "quo"). */
  domain: string;
  /** Title-case discipline (e.g., "Eng") for children, null for parents. */
  discipline: string | null;
};

export function parseTitle(title: string): ParsedTitle | null {
  let m = title.match(LEADING_BRACKET_CHILD);
  if (m) {
    return FDA_DOMAINS.has(m[2])
      ? { domain: m[2].toLowerCase(), discipline: m[1] }
      : null;
  }
  m = title.match(TRAILING_BRACKET_CHILD);
  if (m) {
    return FDA_DOMAINS.has(m[1])
      ? { domain: m[1].toLowerCase(), discipline: m[3] }
      : null;
  }
  m = title.match(PARENT_WITH_COLON);
  if (m) {
    return FDA_DOMAINS.has(m[1])
      ? { domain: m[1].toLowerCase(), discipline: null }
      : null;
  }
  return null;
}
