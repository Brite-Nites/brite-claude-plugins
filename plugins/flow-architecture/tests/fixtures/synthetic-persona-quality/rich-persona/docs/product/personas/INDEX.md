---
last_reviewed: 2026-06-28
---
# Personas

Operational profiles of the people this synthetic field-service ops tool serves. Each persona is one
page, written from that person's perspective. (Fixture for `run-persona-subsystem-vslice.sh` / Lane A
persona-exists floor calibration — a **rich** pair that passes the P1–P5 depth bar and whose
hand-offs resolve against the sibling docs in this directory.)

| Persona | Device | Status | File |
|---|---|---|---|
| Dispatcher | Desktop (desk) + Mobile (floor) | Reviewed | `dispatcher.md` |
| Booking Agent | Desktop (headset) | Reviewed | `booking-agent.md` |

## How to add a persona

1. Copy the canonical template (`docs/templates/persona.md`) and fill every `<…>`.
2. Save as `docs/product/personas/<slug>.md`.
3. Add a row to the table above with status `Drafted` or `Reviewed`.
4. Run `bash scripts/verify-docs.sh`.
