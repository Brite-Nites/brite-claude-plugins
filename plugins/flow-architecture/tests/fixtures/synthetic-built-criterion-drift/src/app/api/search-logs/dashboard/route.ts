// Synthetic fixture for BC-10730 — API endpoint present without a UI consumer.
// Stub Next.js App Router route handler. The operator-consumable criterion
// (flow-inventory-codebase-scan § 6.1) requires a user-facing entry point
// in addition to this file before the sub-flow classifies as ✓ BUILT.

export async function GET() {
  return Response.json({ ok: true });
}
