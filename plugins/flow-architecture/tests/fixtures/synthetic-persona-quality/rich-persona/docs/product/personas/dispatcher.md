---
role: dispatcher
device: desktop (dispatch desk) + mobile (PWA, on the floor)
linear_label: persona/dispatcher
last_reviewed: 2026-06-28
---
# Dispatcher (service-route owner, Ops tier)

> The person who owns the day's service board — assigns jobs to technicians, rebalances when a
> truck breaks down, and trusts the routing engine to fan dispatches out to the right phones.

## At a glance

|  |  |
|---|---|
| **Who** | A service-ops dispatcher who runs the live board for one branch — 8–12 technicians a day. |
| **Where** | The dispatch board, the unassigned-jobs queue, the per-tech timeline; phone-first when away from the desk. |
| **Device** | Desktop at the dispatch desk; mobile (PWA) walking the yard at shift start. |
| **Cadence** | Steady weekday flow with a hard 6–8am assignment crunch and weather-driven re-route spikes. |
| **Judged on** | Every booked job reaches a qualified tech on time, and no job silently falls off the board. |
| **Mental unit** | *The jobs on today's board and the techs they're assigned to* — "who's unassigned," "who's running behind," "did the tech actually get the dispatch" — not the routing queue or the push-notification adapter. |
| **The failure they can't absorb** | A job that drops off the board unassigned and is discovered after the customer's window closes — a missed SLA the branch eats and the customer remembers. |

## Day in the life

A normal Tuesday: the dispatcher arrives at 6am to a queue of overnight-booked jobs and a roster of
techs clocking in. They drag jobs onto tech timelines by skill and geography, watch the first
dispatches land on tech phones, and spend the morning absorbing churn — a no-show customer, a parts
delay, a tech who calls in sick at 7:40. The board is never "done"; it is continuously rebalanced.

A bad Tuesday: a storm reroutes half the city. Two trucks are down, a priority commercial account
needs same-day service, and the dispatcher is reassigning from the mobile PWA in the yard. The
load-bearing moment is the part they don't watch — they reassign a job and trust the dispatch
actually reached the new tech's phone; if it didn't, the job is silently stranded.

## How they think

They think in **jobs and the techs who run them**, not routing internals. The question in their head
is *"is every job on today's board assigned to someone who can actually reach it, and did that person
get told?"* They hold the branch's geography and each tech's skill set in their head, and they triage
by customer-window urgency. Their instinct after years on the desk: distrust any assignment they
can't confirm landed — a dispatch that "should have sent" is the one that strands a job.

## What they care about

- One board for the whole branch, not a tab per technician.
- Assignment that respects skill + certification, not just who's nearest.
- Confirmation that a dispatch reached the tech's phone — not just that it was "sent."
- A job that can never silently leave the board unassigned.

## What they hate (current pain)

- Reassigning a job and having no signal whether the tech actually received it.
- Hunting across separate tech calendars to find an open slot during the morning crunch.
- Finding out at noon that a 9am job was never picked up because the dispatch silently failed.

## What they see — and what they don't

| They **see** | They **don't** see |
|---|---|
| The live board, the unassigned queue, each tech's timeline and current job | The routing engine scoring candidate techs, or the dispatch queue draining |
| That a job moved to a tech and the tech's status flipped to en-route | Whether the push-notification adapter actually delivered to the phone |
| A job flagged red when its customer window is at risk | The escalation rule that decides an unconfirmed dispatch needs a fallback |

## Tools they use today

- The legacy whiteboard + spreadsheet board (the thing being replaced).
- Phone + text — confirming with techs that they got the job.
- The branch's separate per-tech calendar exports.

## Hand-offs

- **From the [Booking agent](booking-agent.md):** a booked job with customer, address, and window
  arrives on the unassigned queue; the dispatcher assigns it to a tech.
- **To the technician (as the recipient):** the dispatcher's assignment becomes the tech's dispatched
  job on their phone; the tech runs it and reports completion back to the board.
- **From engineering (as trusted means):** the routing engine, the dispatch queue, and the
  push-notification adapter are the mechanisms that deliver the dispatcher's assignments — narrated
  through their trust, never as actors they manage.

## Touchpoints in fixture-ops

- **Journeys:** [dispatch-board](../journeys/dispatch-board.md), [routing](../journeys/routing.md)
- **Primary flow domains:** DISP, ROUTE, NOTIFY
- **Pages they live on:** `/board`, `/board/unassigned`, `/board/tech/*`

## Out of scope

- Booking the job in the first place — owned by the [Booking agent](booking-agent.md) / `BOOK`.
- Writing the routing-engine scoring logic — that's engineering, the dispatcher's trusted means.

## Open questions

- Does the dispatcher role split into a desk-dispatcher vs a floor-supervisor tier at larger branches,
  or stay one role with two devices?

## In their words

> "I don't care that the dispatch was sent — I care that the tech has it on their phone."

> "If a job falls off my board, I find out from an angry customer, not from the system. That can't happen."

> "At 6am I'm not thinking about routing scores. I'm thinking about who's unassigned and who's already behind."
