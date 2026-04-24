---
preset: risk-reversal
vertical: municipalities
entity: brite-labs
when: Large budget RFP OR multi-year master plan OR committee-heavy procurement (T4 warranted)
situation_mining_row: Municipalities - RFP mentions "smart city" or downtown master plan + capital bond (SKILL.md §3 Brite-adaptation, Active tier row 1; T4 variant)
---

# risk-reversal | Municipalities | Brite Labs

## Hook (vertical-specific recency waterfall)

Anchor on the procurement-weight signal: RFP publish date, bond authorization date, or master-plan council adoption. Template: "Saw {CITY}'s {RFP_NAME} post on {DATE_SIGNAL}." Tone shift from T2 list-building: less playful, more respectful of the committee process and multi-year scope. {CITY_PLANNER_NAME} anchors the greeting-merged first sentence. The hook should read as if written by someone who understands that the RFP represents months of staff work and bond-authorized capital.

## Step 1 skeleton

**Subject:** `{Phase-gate terms|Scoped pilot|Phase guarantee}`

**Body:**

Hey {FIRST_NAME_INLINE}, {saw|noticed} {CITY}'s {RFP_NAME} {post|publish} on {DATE_SIGNAL}, and given the {scope|scale} of what {your team|the committee} is taking on, wanted to reach out directly.<br><br>{Given the|Because of the} multi-year shape of {RFP_NAME}, Brite Labs {offers|structures} a phase-gate guarantee on projects like this: if phase 1 doesn't deliver {PHASE_1_OUTCOME} by {PHASE_1_MILESTONE}, phase 2 isn't billed. On {LABS_CASE_STUDY} we {hit|exceeded} that bar and the {city|partner} moved to phase 2 {on schedule|ahead of schedule}.<br><br>{Would|Open to} a {guaranteed pilot|scoped pilot} conversation with {your team|the selection committee}? {No full-bid commitment|Not a bid response}, just a scoping call to see whether the phase-gate structure fits {RFP_NAME}'s {cadence|timeline}.<br>{Best|Cheers},<br>{SENDER_FIRST_NAME}

**wait_in_days:** 1

## Step 2 bump

**Subject:** `Re: {Phase-gate terms|Scoped pilot|Phase guarantee}`

**Body:**

{Following up|Circling back}, {FIRST_NAME_INLINE}. Risk-reversal structures like the phase-gate take longer to evaluate than a standard pitch, which is fair. To be specific about what's guaranteed: {PHASE_1_OUTCOME} measured by {MEASUREMENT_METHOD}, with phase 2 scope and pricing contingent on that outcome being met. That specificity is the point, and it's the reason the structure holds up under committee review.<br>{Best|Cheers},<br>{SENDER_FIRST_NAME}

**wait_in_days:** 3

## Vertical anti-slop

- Don't over-promise performance metrics beyond Labs' documented case studies - the guarantee is credible only if Labs can defend the specific outcome with real data.
- Avoid guarantee language that would require municipal legal review (e.g. "refund in full", "zero-cost until delivered"). Use outcome-based framing: "phase 2 not billed until phase 1 delivers X."
- Don't use urgency tactics - municipal procurement runs on its own clock, and urgency reads as vendor-desperate.
- Don't cite Nites seasonal case studies - cite Labs permanent or experiential installations (streetscapes, festivals, placemaking). Residential comparisons undercut the commercial T4 tone.
- Don't reference installers or property management - Supply-excluded per handbook canon.
- Don't mention competitors by name - T4 is about Labs' own commitment, not a head-to-head pitch.
- Avoid "placemaking" as a buzzword in the body (fine in the `when:` trigger field); use concrete outcome specifics like "pedestrian dwell time" or "downtown evening foot traffic" as the measurable levers.
