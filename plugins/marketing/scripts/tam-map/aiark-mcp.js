#!/usr/bin/env node
// Source: Revgrowth1/tam-map@9f5c72e74b (MIT)
// Ported: 2026-04-24
// License: MIT — see plugins/marketing/references/tam/UPSTREAM.md
// Upstream path: scripts/aiark-mcp.js
// Local deviations: BC-7011 (2026-05-11), BC-7157 (2026-05-31) — see § Local deviations in UPSTREAM.md

/**
 * AI Ark MCP wrapper.
 *
 * Exposes AI Ark's HTTP API as MCP tools so Claude Code can call it
 * directly from the /tam-map skill.
 *
 * Verified against docs.ai-ark.com on 2026-05-11 (BC-7011):
 *   Base URL  https://api.ai-ark.com/api/developer-portal/v1
 *   Auth      X-TOKEN: <key>  (no prefix)
 *   Endpoint  POST /companies — serves both firmographic search and
 *             lookalike search (the latter via the `lookalikeDomains` body
 *             field, ≤5 entries). There is no separate /similarity endpoint.
 *   Body keys {account, lookalikeDomains, lists, page, size}; `size` is
 *             clamped to 0..100 per docs.
 *   Rate     5 rps / 300 rpm / 18 000 rph
 *
 * Sources: docs.ai-ark.com/reference/company-search-1,
 *          docs.ai-ark.com/docs/authentication,
 *          help.ai-ark.com/en/articles/112-how-does-the-api-work
 *
 * account sub-schema (BC-7157, verified 2026-05-31 against the OpenAPI export
 * at docs.ai-ark.com/reference/company-search-1.md): every AccountFilter field
 * is an all/any → include/exclude tree, not a bare list. `industries` takes a
 * {mode, content} object (mode ∈ WORD|SMART|STRICT); the geo field is named
 * `location` (plain string[] of country/region names, e.g. "United States");
 * headcount is `employeeSize` ({type:"RANGE", range:[{start,end}]}). Pre-BC-7157
 * the wrapper passed bare string[]/scalars, which the Spring backend rejected as
 * 400 "request not readable" (body deserialization — wrong JSON container type).
 * Unknown sub-fields ARE still silently ignored (return the unfiltered default).
 *
 * Tools:
 *   aiark_search      — firmographic company search via POST /companies
 *   aiark_similarity  — lookalike expansion via POST /companies + lookalikeDomains
 *
 * Not exposed:
 *   aiark_enrich — AI Ark has no domain-keyed enrich endpoint as of
 *   2026-05-11. The closest documented surface is Reverse People Lookup
 *   (email→person, not domain→company). The wrapper's pre-BC-7011 stub
 *   POSTed to a guessed /enrich path and returned nginx 404 in production.
 *   Removed in BC-7011; re-add if upstream ships a real endpoint.
 */
import { Server } from "@modelcontextprotocol/sdk/server/index.js";
import { StdioServerTransport } from "@modelcontextprotocol/sdk/server/stdio.js";
import {
  CallToolRequestSchema,
  ListToolsRequestSchema,
} from "@modelcontextprotocol/sdk/types.js";

const AIARK_API_KEY = process.env.AIARK_API_KEY;
const BASE_URL = "https://api.ai-ark.com/api/developer-portal/v1";
const MAX_SIZE = 100; // per docs.ai-ark.com — `size` is 0..100

if (!AIARK_API_KEY) {
  console.error("AIARK_API_KEY not set");
  process.exit(1);
}

function clampSize(n) {
  const v = typeof n === "number" ? n : 100;
  return Math.max(0, Math.min(MAX_SIZE, v));
}

async function aiarkPost(endpoint, body) {
  const r = await fetch(`${BASE_URL}${endpoint}`, {
    method: "POST",
    headers: {
      "X-TOKEN": AIARK_API_KEY,
      "Content-Type": "application/json",
    },
    body: JSON.stringify(body),
  });
  if (!r.ok) throw new Error(`AI Ark ${r.status}: ${await r.text()}`);
  return await r.json();
}

const server = new Server(
  { name: "aiark", version: "0.3.0" },
  { capabilities: { tools: {} } }
);

server.setRequestHandler(ListToolsRequestSchema, async () => ({
  tools: [
    {
      name: "aiark_search",
      description: "Search for companies by firmographic filters (industry, geo, headcount). Hits POST /companies; size is capped at 100. All filters are optional; with none, returns an unfiltered page.",
      inputSchema: {
        type: "object",
        properties: {
          industries: {
            type: "array",
            items: { type: "string" },
            description: 'Industry names to match (any-of), e.g. ["software development"]. Sent WORD-mode via account.industries.any.include.',
          },
          regions: {
            type: "array",
            items: { type: "string" },
            description: 'Location names to match (any-of), e.g. ["United States", "Texas"]. Mapped to the API\'s account.location.any.include filter.',
          },
          employee_min: { type: "number", description: "Minimum headcount. Lower bound of account.employeeSize RANGE (supply min and/or max — half-open ranges are accepted)." },
          employee_max: { type: "number", description: "Maximum headcount. Upper bound of account.employeeSize RANGE (supply min and/or max — half-open ranges are accepted)." },
          limit: { type: "number", default: 100, maximum: 100 },
        },
      },
    },
    {
      name: "aiark_similarity",
      description: "Find lookalike companies from a seed list of up to 5 domains. Hits POST /companies with the lookalikeDomains body field.",
      inputSchema: {
        type: "object",
        properties: {
          seed_domains: { type: "array", items: { type: "string" }, maxItems: 5 },
          limit: { type: "number", default: 100, maximum: 100 },
        },
        required: ["seed_domains"],
      },
    },
  ],
}));

server.setRequestHandler(CallToolRequestSchema, async (req) => {
  const { name, arguments: args } = req.params;
  try {
    if (name === "aiark_search") {
      // Build the AccountFilter tree (BC-7157). Each field is an
      // all/any → include/exclude object; sending bare string[]/scalars (the
      // pre-BC-7157 shape) 400s with "request not readable". Only populate the
      // sub-fields the caller actually filtered on — an empty account {} is a
      // valid unfiltered search.
      const account = {};
      if (Array.isArray(args.industries) && args.industries.length > 0) {
        account.industries = {
          any: { include: { mode: "WORD", content: args.industries } },
        };
      }
      if (Array.isArray(args.regions) && args.regions.length > 0) {
        account.location = { any: { include: args.regions } };
      }
      const hasMin = typeof args.employee_min === "number";
      const hasMax = typeof args.employee_max === "number";
      if (hasMin || hasMax) {
        const band = {};
        if (hasMin) band.start = args.employee_min;
        if (hasMax) band.end = args.employee_max;
        account.employeeSize = { type: "RANGE", range: [band] };
      }
      const data = await aiarkPost("/companies", {
        account,
        page: 0,
        size: clampSize(args.limit ?? 100),
      });
      return { content: [{ type: "text", text: JSON.stringify(data, null, 2) }] };
    }
    if (name === "aiark_similarity") {
      const data = await aiarkPost("/companies", {
        lookalikeDomains: args.seed_domains,
        page: 0,
        size: clampSize(args.limit ?? 100),
      });
      return { content: [{ type: "text", text: JSON.stringify(data, null, 2) }] };
    }
    throw new Error(`Unknown tool: ${name}`);
  } catch (e) {
    return { content: [{ type: "text", text: `Error: ${e.message}` }], isError: true };
  }
});

const transport = new StdioServerTransport();
await server.connect(transport);
