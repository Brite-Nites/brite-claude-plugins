---
last_reviewed: 2026-06-28
---
# Personas

Operational profiles of the people this synthetic field-service ops tool serves. Each persona is one
page, written from that person's perspective. (Consumed by `run-persona-subsystem-vslice.sh` §6,
which asserts this **rich** pair carries all five FLOOR depth-spine sections + the two At-a-glance
load-bearing rows and that the hand-offs resolve against the sibling docs here — the contrast case to
the `thin-stub/` fixture, which lacks them. Also the calibration set for the BC-12573 persona-exists
gate's deterministic required-sections floor.)

| Persona | Device | Status | File |
|---|---|---|---|
| Dispatcher | Desktop (desk) + Mobile (floor) | Reviewed | `dispatcher.md` |
| Booking Agent | Desktop (headset) | Reviewed | `booking-agent.md` |

## How to add a persona

1. Copy the canonical template (`docs/templates/persona.md`) and fill every `<…>`.
2. Save as `docs/product/personas/<slug>.md`.
3. Add a row to the table above with status `Drafted` or `Reviewed`.
4. Run `bash scripts/verify-docs.sh`.
