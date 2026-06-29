// Fixture test for the agreeing-clean case — presence tips the scan to BUILT.

import { InviteTeammate } from "./invite-teammate";

test("InviteTeammate builds an invite payload", () => {
  expect(InviteTeammate({ email: "a@b.co" })).toEqual({ kind: "invite", to: "a@b.co" });
});
