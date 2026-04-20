---
preset: list-building
vertical: municipalities
entity: brite-labs
when: RFP mentions smart city OR downtown master plan OR public placemaking bond
situation_mining_row: Municipalities — RFP mentions "smart city" or downtown master plan (SKILL.md §3 Brite-adaptation, Active tier row 1)
---

# list-building | Municipalities | Brite Labs

## Hook (vertical-specific recency waterfall)

Anchor on the most recent public signal: RFP publish date, council vote date, or press release on {DOWNTOWN_INITIATIVE}. Template: "Saw {CITY}'s {DOWNTOWN_INITIATIVE} land on {DATE_SIGNAL}." Favor an RFP or bond-vote date over generic "recently" phrasing. {CITY_PLANNER_NAME} anchors the greeting-merged first sentence.

## Step 1 skeleton

**Subject:** `{Quick thought|Quick note|Thought} on {CITY}`

**Body:**

Hey {FIRST_NAME_INLINE}, {saw|noticed|caught} {CITY}'s {DOWNTOWN_INITIATIVE} land on {DATE_SIGNAL} and {wanted to|figured I'd} reach out.<br><br>{We worked with|Brite Labs partnered with} {PEER_CITY} on {PROOF_POINT}, and the {result|outcome} was {measurable|concrete}: {PEER_METRIC} in {PEER_TIMEFRAME}.<br><br>{Would|Curious if} a {short|quick} audit of {CITY}'s current downtown lighting {be useful|make sense} as you {scope|shape} the next phase?<br>{Best|Cheers},<br>{SENDER_FIRST_NAME}

**wait_in_days:** 1

## Step 2 bump

**Subject:** `Re: {Quick thought|Quick note|Thought} on {CITY}`

**Body:**

{Circling back|Following up}, {FIRST_NAME_INLINE}. The {audit|walkthrough} offer stands, and we can {scope it|shape it} around whatever phase of {DOWNTOWN_INITIATIVE} is most {active|load-bearing} for your team right now.<br>{Best|Cheers},<br>{SENDER_FIRST_NAME}

**wait_in_days:** 3

## Vertical anti-slop

- Don't pitch "outdoor lighting" — pitch placemaking + downtown experience.
- Don't cite Nites seasonal case studies — cite Labs permanent installations (festivals, streetscape, public placemaking).
- Avoid "smart city" as a buzzword in the body; use "downtown experience" or "integrated public space" (smart-city language is fine in the `when:` trigger field since it's a keyword match on RFPs).
- No generic municipal pain points (parking, budget cuts, "tight budgets"); lead with the specific bond, RFP, or master-plan signal.
- Don't reference installers or property management — Supply-excluded per handbook canon.
- Don't use urgency tactics — municipal procurement runs on its own clock; urgency reads as vendor-desperate and gets filtered by clerks before the planner sees it.
