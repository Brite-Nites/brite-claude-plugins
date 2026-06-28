---
role: booking-agent
device: desktop (call-center headset)
linear_label: persona/booking-agent
last_reviewed: 2026-06-28
---
# Booking Agent (inbound-call intake, Front-office tier)

> The first human a customer reaches — takes the inbound call, captures the job, and hands a clean
> booked job with a firm service window to the dispatcher's queue.

## At a glance

|  |  |
|---|---|
| **Who** | A call-center front-office agent who books inbound service requests for one or more branches. |
| **Where** | The intake form, the customer-lookup panel, the live availability calendar. |
| **Device** | Desktop, headset on, often two calls deep. |
| **Cadence** | Steady call volume with sharp spikes after storms and on Monday mornings. |
| **Judged on** | Every call ends in a correctly-captured job with a window the branch can actually hit. |
| **Mental unit** | *The call in front of me and the job it becomes* — the customer, the problem, the soonest honest window. |
| **The failure they can't absorb** | Promising a window the branch can't staff — a booking that sets the customer up for a no-show. |

## Day in the life

A normal shift is back-to-back inbound calls: pull up the customer, capture the problem, quote the
soonest honest window, and book it. A storm day is triage — the queue floods, and the agent's job is
to book accurately under pressure without over-promising windows the branch can't reach.

## How they think

They think in **calls and the jobs they become**, not the dispatch board downstream. The question in
their head is *"can I capture this job correctly and give a window we can actually hit?"* Their
instinct: never promise what dispatch can't deliver — an over-promised window is their failure, not
dispatch's.

## What they care about

- A live, honest view of branch availability before quoting a window.
- Fast customer lookup so repeat callers aren't re-keyed.
- A booking that hands off clean — no missing address or contact.

## What they hate (current pain)

- Quoting a window blind because availability isn't visible at booking time.
- Re-keying a repeat customer's details on every call.

## What they see — and what they don't

| They **see** | They **don't** see |
|---|---|
| The intake form, customer history, the availability calendar | The dispatcher rebalancing the board, or how the job is assigned |
| That a job was booked with a window | Which technician ultimately runs it |

## Tools they use today

- The legacy phone system + a separate booking spreadsheet.
- A read-only export of branch availability (stale by the time they quote).

## Hand-offs

- **To the [Dispatcher](dispatcher.md):** a booked job with customer, address, and firm window lands
  on the dispatcher's unassigned queue.

## Touchpoints in fixture-ops

- **Journeys:** [booking](../journeys/booking.md)
- **Primary flow domains:** BOOK
- **Pages they live on:** `/book`, `/book/lookup`

## Out of scope

- Assigning the job to a technician — owned by the [Dispatcher](dispatcher.md) / `DISP`.

## Open questions

- Should agents see real-time tech availability, or only branch-level capacity, when quoting windows?

## In their words

> "I'd rather give an honest Thursday than a Tuesday we'll miss."

> "If I can't see whether we can staff it, I'm just guessing at the window."
