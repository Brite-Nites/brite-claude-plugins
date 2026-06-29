// Fixture impl for the BC-12909 deflation case. Filename intentionally carries
// NO ACL-02 token — mirrors brite-roster, where the shipped audit-log hook lived
// at src/audit/audit-log.ts while the story doc (ACL-02) was stamped NOT_STARTED.
// A deterministic flow_id->path map finds nothing here; a semantic scan recovers
// the build.

export interface AuditEntry {
  actor: string;
  action: string;
  recordId: string;
  at: string;
}

export function withAuditLog(entry: AuditEntry): AuditEntry {
  // Immutable write — append-only; callers never mutate a persisted entry.
  return Object.freeze({ ...entry });
}
