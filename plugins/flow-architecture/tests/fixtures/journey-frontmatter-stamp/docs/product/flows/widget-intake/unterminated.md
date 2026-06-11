---
flow_id: WGT-7
personas: [leaky-persona]
status: NOT_STARTED

# Unterminated front-matter

The opening `---` above is never closed, so this is not a valid front-matter
block — the doc must be skipped whole: neither `WGT-7` nor `leaky-persona`
may appear in the builder output (the §5 leak grep pins both sentinels).
