// Fixture test for the deflation case — its presence is what tips a fresh scan
// from IN_PROGRESS to BUILT (files + tests present).

import { withAuditLog } from "./audit-log";

test("withAuditLog returns a frozen, append-only entry", () => {
  const e = withAuditLog({ actor: "u1", action: "update", recordId: "r1", at: "2026-01-01T00:00:00Z" });
  expect(Object.isFrozen(e)).toBe(true);
  expect(e.action).toBe("update");
});
