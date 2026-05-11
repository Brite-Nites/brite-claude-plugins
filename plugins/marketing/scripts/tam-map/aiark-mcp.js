#!/usr/bin/env node
// Source: Revgrowth1/tam-map@9f5c72e74b (MIT)
// Ported: 2026-04-24
// License: MIT — see plugins/marketing/references/tam/UPSTREAM.md
// Upstream path: scripts/aiark-mcp.js
// Local deviations: BC-7011 (2026-05-11) — see § Local deviations in UPSTREAM.md

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
 * Caveat: the `account` sub-schema (firmographic filter field names) is not
 * fully published. Unknown sub-fields are typically server-side ignored, not
 * 400'd; if a future doc release renames them, re-map here.
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
  { name: "aiark", version: "0.2.0" },
  { capabilities: { tools: {} } }
);

server.setRequestHandler(ListToolsRequestSchema, async () => ({
  tools: [
    {
      name: "aiark_search",
      description: "Search for companies by firmographic filters (industry, geo, size). Hits POST /companies; size is capped at 100.",
      inputSchema: {
        type: "object",
        properties: {
          industries: { type: "array", items: { type: "string" } },
          regions: { type: "array", items: { type: "string" } },
          employee_min: { type: "number" },
          employee_max: { type: "number" },
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
      const data = await aiarkPost("/companies", {
        account: {
          industries: args.industries || [],
          regions: args.regions || [],
          employee_min: args.employee_min,
          employee_max: args.employee_max,
        },
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
