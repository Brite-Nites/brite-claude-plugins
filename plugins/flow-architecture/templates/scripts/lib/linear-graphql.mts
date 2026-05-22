// Shared Linear GraphQL fetch helpers.
//
// Provenance: shipped by `flow-architecture` plugin templates (BC-11029).
//
// Used by:
// - `scripts/verify-linear-references.mts` (read-only — counts + label-hygiene gate)
// - (optional) a project-side label backfill script (read + mutate)
//
// Both scripts hit the same endpoint with the same auth pattern. Sharing the
// helper keeps error handling and truncation consistent.
//
// Security note: this module never logs `apiKey` and never echoes the
// Authorization header. The only place the key crosses a boundary is the
// `fetch` call inside `gql()`. Linear personal API keys are passed raw (no
// `Bearer ` prefix) per the Linear API docs.

// Linear project this repo's FDA scope lives in — sourced from
// `.flow/config.json` `linear_project_id` at scaffold time (BC-11029).
export const PROJECT_ID = "<LINEAR_PROJECT_ID>";

export const LINEAR_GRAPHQL_ENDPOINT = "https://api.linear.app/graphql";

// Shape of a Linear GraphQL connection (the `{ nodes, pageInfo }` envelope
// every paginated query returns). Re-used by `paginate()` and exported in
// case callers want to type a one-off `gql<>` call against the same shape.
export type Connection<TNode> = {
  nodes: TNode[];
  pageInfo: { hasNextPage: boolean; endCursor: string | null };
};

// Default safety cap on `paginate()` iterations. 50 × 250 nodes = 12,500
// records per call. Raise via the `maxPages` param if a query ever needs more.
export const DEFAULT_PAGINATE_MAX_PAGES = 50;

// Generic GraphQL POST. Throws on HTTP error, GraphQL `errors[]`, or missing
// `data`. Returns the typed `data` payload directly so callers can chain into
// their query shape.
export async function gql<T>(
  apiKey: string,
  query: string,
  variables: Record<string, unknown>,
): Promise<T> {
  // Fail fast on empty apiKey — every caller's main() already checks
  // process.env.LINEAR_API_KEY, but a bypass would surface as a confusing
  // 401 from Linear instead of an actionable error.
  if (!apiKey) {
    throw new Error("gql() called with empty apiKey");
  }
  const res = await fetch(LINEAR_GRAPHQL_ENDPOINT, {
    method: "POST",
    headers: {
      "Content-Type": "application/json",
      // Linear personal API keys are passed raw — see top-of-file security note.
      Authorization: apiKey,
    },
    body: JSON.stringify({ query, variables }),
  });
  if (!res.ok) {
    // Redact then truncate the response body. Redaction is defense-in-depth
    // for the unlikely case that Linear ever mirrors request headers into
    // an error response; truncation caps memory/log size. (apiKey is
    // guaranteed non-empty by the entry check above.)
    const raw = await res.text().catch(() => "<no body>");
    const redacted = raw.replaceAll(apiKey, "<REDACTED>");
    const truncated =
      redacted.length > 500
        ? `${redacted.slice(0, 500)}…(truncated, ${redacted.length - 500} chars elided)`
        : redacted;
    throw new Error(`Linear API HTTP ${res.status}: ${truncated}`);
  }
  const json = (await res.json()) as {
    data?: T;
    errors?: Array<{ message: string }>;
  };
  if (json.errors?.length) {
    throw new Error(
      `Linear GraphQL: ${json.errors.map((e) => e.message).join("; ")}`,
    );
  }
  if (!json.data) throw new Error("Linear API returned no data");
  return json.data;
}

// Cursor-paginated walk through a Linear GraphQL connection. The
// `connectionKey` parameter is the name of the connection field on the
// query's `data` payload — e.g., for `query { issues { nodes pageInfo } }`
// pass `"issues"`.
export async function paginate<
  TNode,
  TVars extends Record<string, unknown>,
  K extends string,
>(
  apiKey: string,
  query: string,
  baseVars: TVars,
  connectionKey: K,
  maxPages: number = DEFAULT_PAGINATE_MAX_PAGES,
): Promise<TNode[]> {
  const out: TNode[] = [];
  let cursor: string | null = null;
  for (let page = 0; page < maxPages; page++) {
    const data = await gql<Record<K, Connection<TNode>>>(apiKey, query, {
      ...baseVars,
      cursor,
    });
    if (!(connectionKey in data)) {
      throw new Error(
        `paginate: response missing '${connectionKey}' field — verify the GraphQL query selects this connection`,
      );
    }
    const connection = data[connectionKey];
    if (!connection) {
      throw new Error(
        `paginate: response '${connectionKey}' field is null — connection unexpectedly empty`,
      );
    }
    out.push(...connection.nodes);
    if (!connection.pageInfo.hasNextPage) return out;
    cursor = connection.pageInfo.endCursor;
  }
  throw new Error(
    `paginate hit the ${maxPages}-page safety cap — Linear may be misbehaving`,
  );
}
