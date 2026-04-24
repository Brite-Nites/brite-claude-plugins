#!/usr/bin/env node
// Source: Revgrowth1/tam-map@9f5c72e74b (MIT)
// Ported: 2026-04-24
// License: MIT — see plugins/marketing/references/tam/UPSTREAM.md
// Upstream path: scripts/aiark-mcp.js
// Changes: verbatim port, no functional edits

/**
 * AI Ark MCP wrapper.
 *
 * Exposes AI Ark's HTTP API as MCP tools so Claude Code can call it
 * directly from the /tam-map skill.
 *
 * !! VERIFY BEFORE USING !!
 * AI Ark's public docs hub lists these product surfaces (Company Search API,
 * People Search API, Reverse People Lookup), but the full endpoint schema
 * lives behind docs.ai-ark.com/reference and wasn't fetchable at write time.
 * The exact paths/fields below are conventional guesses. Before shipping:
 *   1. Open docs.ai-ark.com/reference
 *   2. Update BASE_URL, endpoint paths, and field names
 *   3. Confirm auth is Authorization: Bearer (vs X-API-KEY)
 *
 * Tools:
 *   aiark_search      — firmographic company search
 *   aiark_similarity  — similarity search from a seed list of domains
 *   aiark_enrich      — single-company enrichment
 */
import { Server } from "@modelcontextprotocol/sdk/server/index.js";
import { StdioServerTransport } from "@modelcontextprotocol/sdk/server/stdio.js";
import {
  CallToolRequestSchema,
  ListToolsRequestSchema,
} from "@modelcontextprotocol/sdk/types.js";

const AIARK_API_KEY = process.env.AIARK_API_KEY;
const BASE_URL = "https://api.ai-ark.com/v1";

if (!AIARK_API_KEY) {
  console.error("AIARK_API_KEY not set");
  process.exit(1);
}

async function aiarkPost(endpoint, body) {
  const r = await fetch(`${BASE_URL}${endpoint}`, {
    method: "POST",
    headers: {
      "Authorization": `Bearer ${AIARK_API_KEY}`,
      "Content-Type": "application/json",
    },
    body: JSON.stringify(body),
  });
  if (!r.ok) throw new Error(`AI Ark ${r.status}: ${await r.text()}`);
  return await r.json();
}

const server = new Server(
  { name: "aiark", version: "0.1.0" },
  { capabilities: { tools: {} } }
);

server.setRequestHandler(ListToolsRequestSchema, async () => ({
  tools: [
    {
      name: "aiark_search",
      description: "Search for companies by firmographic filters (industry, geo, size).",
      inputSchema: {
        type: "object",
        properties: {
          industries: { type: "array", items: { type: "string" } },
          regions: { type: "array", items: { type: "string" } },
          employee_min: { type: "number" },
          employee_max: { type: "number" },
          limit: { type: "number", default: 100 },
        },
      },
    },
    {
      name: "aiark_similarity",
      description: "Find lookalike companies from a seed list of domains.",
      inputSchema: {
        type: "object",
        properties: {
          seed_domains: { type: "array", items: { type: "string" } },
          limit: { type: "number", default: 100 },
        },
        required: ["seed_domains"],
      },
    },
    {
      name: "aiark_enrich",
      description: "Enrich a single company by domain.",
      inputSchema: {
        type: "object",
        properties: { domain: { type: "string" } },
        required: ["domain"],
      },
    },
  ],
}));

server.setRequestHandler(CallToolRequestSchema, async (req) => {
  const { name, arguments: args } = req.params;
  try {
    if (name === "aiark_search") {
      const data = await aiarkPost("/search", {
        filters: {
          industries: args.industries || [],
          geo: { regions: args.regions || [] },
          size_band: { employee_min: args.employee_min, employee_max: args.employee_max },
        },
        limit: args.limit || 100,
      });
      return { content: [{ type: "text", text: JSON.stringify(data, null, 2) }] };
    }
    if (name === "aiark_similarity") {
      const data = await aiarkPost("/similarity", {
        seed_domains: args.seed_domains,
        limit: args.limit || 100,
      });
      return { content: [{ type: "text", text: JSON.stringify(data, null, 2) }] };
    }
    if (name === "aiark_enrich") {
      const data = await aiarkPost("/enrich", { domain: args.domain });
      return { content: [{ type: "text", text: JSON.stringify(data, null, 2) }] };
    }
    throw new Error(`Unknown tool: ${name}`);
  } catch (e) {
    return { content: [{ type: "text", text: `Error: ${e.message}` }], isError: true };
  }
});

const transport = new StdioServerTransport();
await server.connect(transport);
