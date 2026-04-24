#!/usr/bin/env node
// Source: Revgrowth1/tam-map@9f5c72e74b (MIT)
// Ported: 2026-04-24
// License: MIT — see plugins/marketing/references/tam/UPSTREAM.md
// Upstream path: scripts/discolike-mcp.js
// Changes: verbatim port, no functional edits

/**
 * Discolike MCP wrapper.
 *
 * Exposes Discolike's /discover endpoint as MCP tools.
 *
 * Docs: https://api.discolike.com/v1/docs/api/endpoints/discover/
 * Wire: GET https://api.discolike.com/v1/discover with header `x-discolike-key`
 *
 * Tools:
 *   discolike_search    — NL ICP search (uses icp_text + filters)
 *   discolike_lookalike — lookalike expansion (uses domain[] param, up to 10)
 */
import { Server } from "@modelcontextprotocol/sdk/server/index.js";
import { StdioServerTransport } from "@modelcontextprotocol/sdk/server/stdio.js";
import {
  CallToolRequestSchema,
  ListToolsRequestSchema,
} from "@modelcontextprotocol/sdk/types.js";

const DISCOLIKE_API_KEY = process.env.DISCOLIKE_API_KEY;
const BASE_URL = "https://api.discolike.com/v1/discover";

if (!DISCOLIKE_API_KEY) {
  console.error("DISCOLIKE_API_KEY not set");
  process.exit(1);
}

async function discolikeGet(params) {
  const qs = new URLSearchParams();
  for (const [k, v] of Object.entries(params)) {
    if (v === undefined || v === null) continue;
    if (Array.isArray(v)) {
      for (const item of v) qs.append(k, item);
    } else {
      qs.append(k, String(v));
    }
  }
  const url = `${BASE_URL}?${qs.toString()}`;
  const r = await fetch(url, {
    method: "GET",
    headers: { "x-discolike-key": DISCOLIKE_API_KEY },
  });
  if (!r.ok) throw new Error(`Discolike ${r.status}: ${await r.text()}`);
  return await r.json();
}

const server = new Server(
  { name: "discolike", version: "0.1.0" },
  { capabilities: { tools: {} } }
);

server.setRequestHandler(ListToolsRequestSchema, async () => ({
  tools: [
    {
      name: "discolike_search",
      description: "Search across 65M+ business domains using a natural-language ICP description.",
      inputSchema: {
        type: "object",
        properties: {
          icp_text: { type: "string", description: "NL description of target companies" },
          country: { type: "array", items: { type: "string" }, description: "ISO country codes (e.g. ['US','GB'])" },
          category: { type: "array", items: { type: "string" }, description: "Industry filters (e.g. 'TECHNOLOGY')" },
          employee_range: { type: "string", description: "Format 'min,max' (e.g. '10,500')" },
          min_digital_footprint: { type: "number", description: "Score threshold 0-800" },
          max_records: { type: "number", default: 100, description: "5-10000" },
          offset: { type: "number", default: 0 },
          phrase_match: { type: "array", items: { type: "string" }, description: "Exact text fragments to match (up to 20)" },
        },
        required: ["icp_text"],
      },
    },
    {
      name: "discolike_lookalike",
      description: "Find lookalike domains from a seed list (up to 10 domains).",
      inputSchema: {
        type: "object",
        properties: {
          domain: { type: "array", items: { type: "string" }, description: "Seed domains for lookalike matching (max 10)" },
          country: { type: "array", items: { type: "string" } },
          max_records: { type: "number", default: 100 },
          offset: { type: "number", default: 0 },
        },
        required: ["domain"],
      },
    },
  ],
}));

server.setRequestHandler(CallToolRequestSchema, async (req) => {
  const { name, arguments: args } = req.params;
  try {
    if (name === "discolike_search") {
      const data = await discolikeGet(args);
      return { content: [{ type: "text", text: JSON.stringify(data, null, 2) }] };
    }
    if (name === "discolike_lookalike") {
      const data = await discolikeGet(args);
      return { content: [{ type: "text", text: JSON.stringify(data, null, 2) }] };
    }
    throw new Error(`Unknown tool: ${name}`);
  } catch (e) {
    return { content: [{ type: "text", text: `Error: ${e.message}` }], isError: true };
  }
});

const transport = new StdioServerTransport();
await server.connect(transport);
