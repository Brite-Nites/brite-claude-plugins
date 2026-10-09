---
name: ads-agent
description: Runs Brite's own ads agent for one day on Google Ads or Meta. Propose mode plans budget moves and ad turn-offs inside hard limits from the warehouse results and the platform's current settings, logs the plan, and posts a Slack summary without changing any ad account. Approve logs the Head of GTM's approval of one planned change. Act mode applies the plan through the platform's API inside ADR-0033's hard limits, approved changes only and one a day in weeks 1-2. A run freezes when yesterday's platform and BriteBase lead counts disagree. It enforces the season rules: the step-up gate, capacity pauses, the taper and the territory freeze. On Meta it also flags targeting that breaks the Housing rules, runs the 50/50 site vs instant-form test, and retires ads Meta stopped showing. Use in the daily session with the Head of GTM. Triggers "ads agent", "run the ads agent", "propose ad changes", "approve ad change", "apply ad changes", "paid ads daily plan", "Meta ads agent". The watchdog is a separate run (BC-28219).
user-invocable: true
disable-model-invocation: true
allowed-tools: Bash, Read
metadata:
  version: 0.8.0
  category: Paid Ads
---

# Ads agent (Google and Meta)

One bounded run (BC-28215 propose, BC-28216 approve and act, BC-28218 Meta, BC-28220
season rules, BC-28579 capacity for the instant-form ad set; spec BC-28205): results
snapshots in, change plan out. The rule is ADR-0033 in brite-gtm: the
agent may move money inside the ceiling a person set, and never sets money.

Each run is for one platform, chosen with `--platform google_ads` or `--platform meta_ads`.
Each platform has its own rules file, because each has its own weekly ceiling.

Every plan row, approval and apply result is a row in the change log
(`ANALYTICS.OPERATIONS.ADS_AGENT_CHANGE_LOG`). A row is never edited. An approval or a
result is a new row whose key starts with the plan row's key.

## What a run does

1. Checks yesterday's lead counts (see "Data freeze" below). If the run is frozen, it
   stops here.
2. Reads the results snapshots (campaign and ad level) from the warehouse. Results never
   come from the ad APIs. A conversion in the snapshot is a lead.
3. Reads current settings from the platform:
   - Google: each campaign's daily budget, "limited by budget", shared budgets, brand
     campaigns (label `brand`), and each ad's status.
   - Meta: each active ad set's daily budget, optimisation goal, destination and
     targeting; brand campaigns (ad label `brand`); each ad's status and age. A budget sits
     on the ad set. One held by the campaign, or a lifetime budget, is never moved.
4. Reads the season rules' inputs (see "The season rules" below): Operations' capacity
   sheet, the budget changes the agent applied since `season_start`, and booked
   appointments per territory and week from
   `ANALYTICS.MARTS.MART_ADS_AGENT_TERRITORY_WEEKLY`.
5. Plans at most one budget move: from the worst cost per conversion to the best campaign
   (on Meta, ad set) that is limited by budget. Total daily budget stays the same. Shared
   budgets and brand campaigns are never moved. From `taper_start` it plans the taper
   instead.
6. Plans ad turn-offs:
   - An ad with zero leads turns off once it has spent `kill_multiple` (3) times
     `target_cpl`, never before.
   - Ads in one ad group (on Meta, one ad set) are compared on cost per lead only once
     each has spent `compare_multiple` (5) times `target_cpl`. The worst of those turns off.
7. Plans a pause for each campaign (on Meta, ad set) in a territory that is full. On Meta,
   it also plans removing a full territory's locations from the instant-form ad set
   (season rule 6).
8. On Meta, also plans the rules in "Meta's own rules" below.
9. Runs each change through the limit checks (`max_move`, `no_total_raise`,
   `weekly_ceiling`, `brand_untouched`, `step_up_gate`, `capacity_open`,
   `territory_freeze`, and on Meta `housing_safe`, `approved_creative` and
   `location_removal`). A change that fails a check is `held`.
10. Logs new rows and posts one Slack message. A re-run on the same day logs and posts
    nothing new. A capacity alert, if any, is a second message, once a day.

The output's `notes` list says why each rule planned nothing, and names any data the run
could not read. On Meta, `paths` lists the ad sets on each path.

## Data freeze

If the lead feed breaks, the snapshot shows no leads, and the kill rule would turn off
good ads. So before planning, each run reads yesterday's row for its platform from
`ANALYTICS.MARTS.MART_ADS_AGENT_LEAD_RECONCILIATION`. Yesterday is the day before the run
date in the rules' `timezone`.

The run is frozen when:

- the row is missing (the feed is broken);
- the platform's and BriteBase's lead counts differ by more than `max_lead_count_gap`;
- the gap is unknown while either count is above zero;
- both counts are zero but the platform spent money ("spend with no leads").

Both counts zero with no spend is not frozen.

A frozen run plans, approves and applies nothing. It logs one `frozen` row with the reason
and both counts, and posts one Slack alert. A re-run the same day posts nothing new.
`approve` refuses while the platform is frozen. The watchdog is a separate run and still
pauses during a freeze.

A budget move is two rows, a cut and a raise, and counts as one change. The raise row's key
is `<cut key>:pair`. Approving either key approves both halves. A move never crosses
platforms: a cut on one platform never pays for a raise on the other.

## Meta's own rules

1. **Housing-safe targeting.** Any active ad set whose targeting breaks Meta's Housing
   rules gets a `held` targeting row naming each break: a radius under 15 miles (or
   none), ZIP codes, an age or gender limit, or a lookalike audience. An audience whose
   type cannot be read counts as a lookalike. A person fixes the targeting by hand in Ads
   Manager. Until then, the agent also holds any change that would add spend to that ad
   set; a cut or a turn-off still goes ahead. The agent writes targeting only to remove a
   full territory's locations from the instant-form ad set, with approval (season rule 6).
2. **Two paths.** Each ad set is on the site path (destination: website, one ad set per
   territory) or the instant-form path (destination: a lead form on the ad, one ad set
   across Brite's Meta territories). The path comes from the destination, not the name.
3. **The 50/50 path test.** `meta_path_test_start` is the date the test began.
   - Until two weeks after that date, the day's budget move stays inside one path, so the
     50/50 split holds.
   - From two weeks after that date, the day's budget move is the path test's move
     instead: one linked move toward the path with the lower cost per booked appointment.
     It repeats each day, capped by `max_move_pct`, until a person sets
     `meta_path_test_start` to `null`. Normal moves then resume.
   - Booked appointments, calls counted, come from the ad results snapshot's
     `booked_appointments` column, summed per ad set.
   - The path test proposes no budget move until both paths have at least one booked
     appointment, or while any ad set's count is null. The notes say why.
4. **Optimising for booked appointments.** Once an ad set optimised for leads has
   `min_conversions` booked appointments in the snapshot, the plan proposes switching it to
   optimise for booked appointments. Act never applies this switch without the Head of
   GTM's approval, even after weeks 1-2. It reads the same column.
5. **Approved ads only.** The agent turns an ad on only if its row exists in
   `ANALYTICS.OPERATIONS.ADS_CREATIVE_INPUTS` and, when its photo was AI-edited, the row
   names `approved_by`.
6. **Retire quiet ads.** An active ad at least `retire_after_days` (7) days old that spent
   `retire_spend_floor` or less in the snapshot is turned off. This only lowers spend.
7. **Limited by budget.** Meta has no such status, so the run works it out. An ad set
   counts as limited by budget only when yesterday's spend reached
   `meta_budget_limited_spend_pct` (0.95) of its daily budget. For a budget held by the
   campaign, the campaign's spend is used. Spend is read from Meta's insights API. Missing
   spend, or a failed read, means not limited, and the notes say so.

## The season rules

These hold on both platforms (BC-28220). Every value is a key in the rules file, so the
Head of GTM changes it without a deploy.

A campaign's territory comes from the results snapshots; on Meta, an ad set has its
campaign's territory. Each territory's next open install date comes from Operations'
capacity sheet ("Operations Health 2025-2026").

1. **The step-up gate.** A territory's launch budget is its daily budget on
   `season_start`. A move may lift a territory past its launch budget only when each of
   the last `step_up_weeks` full weeks (Monday to Sunday) cost `step_up_cost_per_booked`
   or less per booked appointment, calls counted.
   - Inside its launch budget, a territory's money moves as before: between two campaigns
     in the territory, or back up to the launch budget after a cut.
   - The run works out the launch budget as today's budget less every budget change the
     agent applied since `season_start`. A budget a person changes by hand counts as launch
     budget. Before `season_start`, the launch budget is today's budget.
   - Booked appointments per territory and week come from
     `ANALYTICS.MARTS.MART_ADS_AGENT_TERRITORY_WEEKLY`. A week's cost is the platform's
     spend in the territory divided by one of the mart's four counts. Two rule keys choose
     which count:
     - `gate_clients`: `"new"` counts new clients only; `"any"` counts any client.
     - `gate_channels`: `"paid"` counts bookings credited to this platform's paid ads;
       `"all"` counts bookings from any channel.
     - Left out, they default to `"new"` and `"paid"`: the `booked_paid_new` count.
   - A week with no row, a null count or spend, or none of the chosen bookings fails the
     gate. With no rows at all, every move that would lift a territory past its launch
     budget is held, and the notes say so.
   - An ad set that serves several territories (the instant form) has the territory
     `multi`. The gate treats `multi` as one more territory, judged on its own rows.
2. **The capacity pause.** When a territory's next open install date is after
   `capacity_pause_date`, the plan pauses each campaign (on Meta, ad set) in it. A pause
   only lowers spend, so it goes ahead during the freeze and the taper, and even on a
   stale row. In weeks 1-2 it needs approval like any change. The agent never turns a
   campaign back on: a person does.
3. **Capacity before a raise.** No raise goes into a territory whose capacity row is
   missing, older than `capacity_max_age_hours`, or past `capacity_pause_date`. A missing
   or stale row, or a sheet the run cannot read, also posts one Slack alert a day for both
   platforms together. `multi` has no row; rule 6 says how it is judged.
4. **The taper.** From `taper_start`, each day's plan cuts every budget the agent may move
   by `taper_daily_pct` of that day's budget, and plans no budget move. Brand campaigns and
   shared budgets are left alone. `taper_daily_pct` has no default: from `taper_start`, a
   run without it stops with exit code 2.
5. **The territory freeze.** From `territory_freeze_date`, a move's cut and raise must be
   in the same territory.
6. **The instant-form ad set (`multi`) and capacity (BC-28579).** `multi` has no row in
   the capacity sheet. The rule key `multi_territories` maps each territory the
   instant-form ad set covers, spelled as the sheet spells it, to that territory's Meta
   location keys in the ad set's targeting. A person keeps it in step with the targeting.
   - **Freshness.** If any listed territory's row is missing or older than
     `capacity_max_age_hours`, no raise goes into `multi`. The day's capacity alert names
     those territories, in one message, and says `multi` is held too. It never names
     `multi` itself.
   - **A full territory.** If any listed territory's next open install date is after
     `capacity_pause_date`, no raise goes into `multi`. On Meta the plan also proposes one
     change: the instant-form ad set's locations without that territory's. Leads from a
     full territory go to the BriteBase waitlist, so the ad stops reaching it (Holden,
     2026-10-06). The change always waits for the Head of GTM's approval, even after weeks
     1-2. Act writes it through the Meta adapter, which re-reads the targeting and writes
     back only the locations. The change is `held` when the targeting it would leave
     breaks the Housing rules, when it would leave no location, or when a listed key is
     not in the targeting (out of step). Act checks again before the write, so a territory
     with room again keeps its locations. The agent never adds a location back.
   - **Otherwise** a raise into `multi` follows every other limit, as before.
   - **No key.** With `multi_territories` missing, `null` or `{}`, no raise goes into
     `multi`, and the notes say why. No alert is sent for it.
   - A site ad set's capacity check reads only its own territory's row, as before.

The gate, the capacity check and the freeze hold both halves of a move together. Act
checks them again just before each write.

## Act mode: the hard limits

Act mode re-checks every limit just before each write, whatever the plan said. It never:

1. raises total budget: it writes the cut first, and writes the raise only after its own
   cut is applied and only if the pair's net is zero or less;
2. moves any budget more than `max_move_pct` (25%) in one run;
3. creates or deletes a campaign without approval;
4. touches a brand campaign or its ads;
5. writes anything while `emergency_stop` is true;
6. writes a rule setting. The agent only reads the rules file, so it cannot clear the stop;
7. on Meta, writes targeting (beyond removing a full territory's locations from the
   instant-form ad set, with approval), adds spend to an ad set that breaks the Housing
   rules, turns on an ad from outside the approved library, or switches an optimisation
   goal without approval;
8. breaks a season rule: a move past a launch budget without the step-up gate, a raise
   into a territory whose capacity is full or not current, or a move between territories
   after `territory_freeze_date`. It writes a campaign's or ad set's status only to pause
   it for capacity.

It also refuses a raise that is not half of a planned move, a shared budget, a setting
already changed today, and a setting whose current value is not the planned old value.
Act plans once a day. A re-run only retries what is not yet applied, so nothing is written
twice.

While `weeks_1_2` is true, act writes approved changes only, at most one change per
platform per day. A budget move is one change.

## Before the first run

1. Put the secrets in their own Bitwarden Secrets Manager project (ADR-044). The run reads:
   - Google: `GOOGLE_ADS_DEVELOPER_TOKEN`, `GOOGLE_ADS_CLIENT_ID`,
     `GOOGLE_ADS_CLIENT_SECRET`, `GOOGLE_ADS_REFRESH_TOKEN`, `GOOGLE_ADS_LOGIN_CUSTOMER_ID`.
   - Meta: `META_ADS_SYSTEM_USER_TOKEN`, and optionally `META_GRAPH_API_VERSION`
     (default `v24.0`).
   - Both: `ADS_AGENT_SNOWFLAKE_ACCOUNT`, `ADS_AGENT_SNOWFLAKE_USER`,
     `ADS_AGENT_SNOWFLAKE_PRIVATE_KEY`, `ADS_AGENT_SNOWFLAKE_ROLE`,
     `ADS_AGENT_SNOWFLAKE_WAREHOUSE`, `ADS_AGENT_SLACK_WEBHOOK_URL`.
   - The capacity sheet: `ADS_AGENT_CAPACITY_SHEET_ID`, `ADS_AGENT_CAPACITY_RANGE` (the
     tab or range to read), `ADS_AGENT_CAPACITY_SERVICE_ACCOUNT_JSON` (a Google service
     account's key).
2. Install the runtime libraries: `google-ads`, `snowflake-connector-python`, `cryptography`,
   `google-auth`. Meta needs none. The machine also needs the IANA time zone data. macOS
   and most Linux have it; elsewhere install `tzdata`.
3. Write each platform's rule settings to a JSON file outside this repo (this repo is
   public). Only a person edits these files:
   - `weekly_ceiling`: dollars a week on this platform.
   - `max_move_pct`: 0.25 means 25%.
   - `min_conversions`: conversions a campaign or ad set needs before it is judged.
   - `weeks_1_2`: `true` for the first two weeks.
   - `emergency_stop`: `false` unless the Head of GTM has pulled the stop.
   - `target_cpl`: target cost per lead, in dollars.
   - `kill_multiple`: 3.
   - `compare_multiple`: 5.
   - `timezone`: an IANA time zone name, such as `America/Denver`. The run date is today's
     date there, not in UTC, so an evening approval finds that day's plan.
   - `max_lead_count_gap`: 0.20 means 20%. Writes freeze when yesterday's platform and
     BriteBase lead counts differ by more than this.
   - Meta only: `meta_path_test_start` (`YYYY-MM-DD`, or `null` for no path test),
     `retire_after_days` (7), `retire_spend_floor` (dollars),
     `meta_budget_limited_spend_pct` (0.95).
   - The season rules, on both platforms. Dates are `YYYY-MM-DD`:
     - `season_start`: the date the season launched.
     - `step_up_cost_per_booked`: dollars per booked appointment, calls counted.
     - `step_up_weeks`: 2.
     - `capacity_pause_date`: the last install date that still counts as room.
     - `capacity_max_age_hours`: 48.
     - `territory_freeze_date`: the first day no money moves between territories.
     - `taper_start`: the first day of the taper.
     - `taper_daily_pct`: 0.10 means 10% a day. It may be missing or `null` until
       `taper_start`, and not after.
     - `gate_clients`: `"new"` or `"any"`. Optional; the default is `"new"`.
     - `gate_channels`: `"paid"` or `"all"`. Optional; the default is `"paid"`.
     - `multi_territories`: each territory the instant-form ad set covers, spelled as in
       the capacity sheet, mapped to that territory's Meta location keys in the ad set's
       targeting (season rule 6). Copy the territories and their cities from brite-gtm's
       instant-form location list (`docs/campaigns/residential-paid-ads/meta-launch/`),
       and each city's key from the ad set in Ads Manager. Optional, but without it no
       raise goes into `multi`. The shape, with placeholders:

       ```json
       "multi_territories": {
         "<territory>": ["<Meta location key>", "<Meta location key>"],
         "<another territory>": ["<Meta location key>"]
       }
       ```

   `weeks_1_2` and `emergency_stop` must be JSON `true` or `false`. `timezone` must be an
   exact IANA name. `step_up_weeks` must be a whole number. `gate_clients` and
   `gate_channels`, when set, must be one of their two values, not `null`.
   `multi_territories`, when set, names each territory once (not `multi`), and each
   location key once, as text. Anything else stops the run.
4. Label every brand campaign `brand`: a label in Google Ads, an ad label in Meta.
5. On Meta, confirm with the Head of GTM which events mean a booked appointment: Meta's
   Schedule event on the site pixel, and conversion leads on the instant form.
6. Share the capacity sheet with the service account as a viewer. Confirm with the sheet's
   owner that the range's first row names the columns `Territory`, `Next Open Install
   Date` and `Last Updated`, and that each territory is spelled as in the warehouse.

## Daily flow, weeks 1-2

Run these steps for one platform at a time. `<platform>` is `google_ads` or `meta_ads`.

1. Preview the plan. This writes nothing anywhere:

   ```bash
   cd "${CLAUDE_PLUGIN_ROOT}/scripts" && bws run --project-id <ads-agent project> -- \
     python3 -m ads_agent propose --platform <platform> --rules <rules file> --emit
   ```

2. Log the plan and post it to Slack:

   ```bash
   cd "${CLAUDE_PLUGIN_ROOT}/scripts" && bws run --project-id <ads-agent project> -- \
     python3 -m ads_agent propose --platform <platform> --rules <rules file>
   ```

   If `frozen` in the output is not null, stop the daily flow. Tell the Head of GTM its
   `reason`, and do not approve or act. The freeze lifts on the first run that passes the
   lead count check.

   If a capacity alert was posted, tell the Head of GTM which territories' rows in the
   capacity sheet need updating. Raises into them stay held until the rows are current.

   If the plan proposes removing a territory's locations from the instant-form ad set,
   name the territory and each location to the Head of GTM. Once it is applied, ask a
   person to take that territory off `multi_territories`. Until then, each day's plan
   holds an out-of-step row and no raise goes into `multi`.

3. Show the Head of GTM each change: campaign, ad set or ad, old → new, reason, checks and
   key. Name any `held` change and the check it failed. Read out the `notes`.
4. Ask the Head of GTM which one change to approve. Approve only the key they name:

   ```bash
   cd "${CLAUDE_PLUGIN_ROOT}/scripts" && bws run --project-id <ads-agent project> -- \
     python3 -m ads_agent approve <key> --by "<Head of GTM's name>" --rules <rules file>
   ```

   The approval must fall on the plan's run date in the rules' `timezone`. After local
   midnight the key matches nothing: run `propose` again for the new day.

5. Preview what act would write, then run it:

   ```bash
   cd "${CLAUDE_PLUGIN_ROOT}/scripts" && bws run --project-id <ads-agent project> -- \
     python3 -m ads_agent act --platform <platform> --rules <rules file> --emit
   cd "${CLAUDE_PLUGIN_ROOT}/scripts" && bws run --project-id <ads-agent project> -- \
     python3 -m ads_agent act --platform <platform> --rules <rules file>
   ```

6. Read the results back to the Head of GTM: each `applied` row, and each `apply_failed`
   row with its reason.

## From about week 3

1. Have a person set `weeks_1_2` to `false` in the rules file.
2. Run `act` once a day for each platform. It plans, logs, and applies every proposed
   change that passed every check. Campaign creates and deletes, and Meta's switch to
   booked appointments, still wait for approval.

## Rules

- Never approve a change the Head of GTM did not name in this session.
- Never edit a rules file from this skill. Never change a setting in an ad account by hand.
- Never work around a freeze, for example by raising `max_lead_count_gap` to get a plan.
- Never work around a season rule, for example by moving `season_start` or raising
  `capacity_max_age_hours` to get a move through. Only the Head of GTM changes those values.
  Never take a territory off `multi_territories` while its locations are still in the
  instant-form ad set's targeting.
- Never commit account ids, page ids, pixel ids, budgets, ceilings, results or change-log
  rows to this repo.
- Exit code 2 names the missing secret, the bad rule setting, or the key that matched
  nothing. Fix it; do not work around it.
- Tests: `plugins/marketing/tests/test_ads_agent_run.py` (Google),
  `plugins/marketing/tests/test_ads_agent_meta.py` (Meta) and
  `plugins/marketing/tests/test_ads_agent_season.py` (the season rules), with fakes in
  `scripts/ads_agent/fakes.py`.
