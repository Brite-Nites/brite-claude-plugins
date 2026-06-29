// Fixture impl for the BC-12909 agreeing-clean case. File path carries the flow's
// domain + intent; a fresh scan finds impl + test → BUILT, agreeing with the
// doc's declared BUILT (no drift, no warn).

export function InviteTeammate(props: { email: string }) {
  return { kind: "invite", to: props.email };
}
