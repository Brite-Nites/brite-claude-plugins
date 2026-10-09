---
name: ads-agent
description: Runs Brite's own ads agent for one day on Google Ads or Meta. Propose mode reads the results snapshots from the warehouse and current settings from the ad platform, plans budget moves and ad turn-offs inside hard limits, logs the plan to the warehouse change log, and posts a Slack summary without changing any ad account. Approve logs the Head of GTM's approval of one planned change. Act mode applies the plan through the platform's API inside ADR-0033's hard limits, approved changes only and one a day in weeks 1-2. A run freezes itself, writing nothing, when yesterday's lead counts on the platform and in BriteBase disagree. On Meta it also flags targeting that breaks the Housing rules, runs the 50/50 site vs instant-form test, and retires ads Meta stopped showing. Use in the daily session with the Head of GTM. Triggers "ads agent", "run the ads agent", "propose ad changes", "approve ad change", "apply ad changes", "paid ads daily plan", "Meta ads agent". The watchdog is a separate run (BC-28219).
user-invocable: true
disable-model-invocation: true
allowed-tools: Bash, Read
metadata:
  version: 0.5.0
  category: Paid Ads
---

# Ads agent (Google and Meta)

One bounded run (BC-28215 propose, BC-28216 approve and act, BC-28218 Meta; spec
BC-28205): results snapshots in, change plan out. The rule is ADR-0033 in brite-gtm: the
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
4. Plans at most one budget move: from the worst cost per conversion to the best campaign
   (on Meta, ad set) that is limited by budget. Total daily budget stays the same. Shared
   budgets and brand campaigns are never moved.
5. Plans ad turn-offs:
   - An ad with zero leads turns off once it has spent `kill_multiple` (3) times
     `target_cpl`, never before.
   - Ads in one ad group (on Meta, one ad set) are compared on cost per lead only once
     each has spent `compare_multiple` (5) times `target_cpl`. The worst of those turns off.
6. On Meta, also plans the rules in "Meta's own rules" below.
7. Runs each change through the limit checks (`max_move`, `no_total_raise`,
   `weekly_ceiling`, `brand_untouched`, and on Meta `housing_safe` and
   `approved_creative`). A change that fails a check is `held`.
8. Logs new rows and posts one Slack message. A re-run on the same day logs and posts
   nothing new.

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

1. **Housing-safe targeting.** The agent never writes targeting. Any active ad set whose
   targeting breaks Meta's Housing rules gets a `held` targeting row naming each break: a
   radius under 15 miles (or none), ZIP codes, an age or gender limit, or a lookalike
   audience. An audience whose type cannot be read counts as a lookalike. A person fixes
   the targeting by hand in Ads Manager. Until then, the agent also holds any change that
   would add spend to that ad set; a cut or a turn-off still goes ahead.
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
   - Booked appointments come from the snapshot's `booked_appointments` column. That column
     does not exist yet, so for now the path test proposes no budget move and the notes
     say why.
4. **Optimising for booked appointments.** Once an ad set optimised for leads has
   `min_conversions` booked appointments in the snapshot, the plan proposes switching it to
   optimise for booked appointments. Act never applies this switch without the Head of
   GTM's approval, even after weeks 1-2. It needs the same missing column.
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

## Act mode: the hard limits

Act mode re-checks every limit just before each write, whatever the plan said. It never:

1. raises total budget: it writes the cut first, and writes the raise only after its own
   cut is applied and only if the pair's net is zero or less;
2. moves any budget more than `max_move_pct` (25%) in one run;
3. creates or deletes a campaign without approval;
4. touches a brand campaign or its ads;
5. writes anything while `emergency_stop` is true;
6. writes a rule setting. The agent only reads the rules file, so it cannot clear the stop;
7. on Meta, writes targeting, adds spend to an ad set that breaks the Housing rules, turns
   on an ad from outside the approved library, or switches an optimisation goal without
   approval.

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
2. Install the runtime libraries: `google-ads`, `snowflake-connector-python`, `cryptography`.
   Meta needs none. The machine also needs the IANA time zone data. macOS and most Linux
   have it; elsewhere install `tzdata`.
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

   `weeks_1_2` and `emergency_stop` must be JSON `true` or `false`. `timezone` must be an
   exact IANA name. Anything else stops the run.
4. Label every brand campaign `brand`: a label in Google Ads, an ad label in Meta.
5. On Meta, confirm with the Head of GTM which events mean a booked appointment: Meta's
   Schedule event on the site pixel, and conversion leads on the instant form.

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
- Never commit account ids, page ids, pixel ids, budgets, ceilings, results or change-log
  rows to this repo.
- Exit code 2 names the missing secret, the bad rule setting, or the key that matched
  nothing. Fix it; do not work around it.
- Tests: `plugins/marketing/tests/test_ads_agent_run.py` (Google) and
  `plugins/marketing/tests/test_ads_agent_meta.py` (Meta), with fakes in
  `scripts/ads_agent/fakes.py`.
