---
name: ads-agent
description: Runs Brite's own Google Ads agent for one day. Propose mode reads the results snapshots from the warehouse and current settings from Google Ads, plans budget moves and ad turn-offs inside hard limits, writes the plan to the warehouse change log, and posts a Slack summary without changing any ad account. Approve logs the Head of GTM's approval of one planned change. Act mode applies the plan through the Google Ads API inside the hard limits of ADR-0033, approved changes only and one a day in weeks 1-2. A run freezes itself, planning and writing nothing, when yesterday's lead counts on the platform and in BriteBase disagree. Use in the daily session with the Head of GTM. Triggers "ads agent", "run the ads agent", "propose ad changes", "approve ad change", "apply ad changes", "paid ads daily plan". The watchdog is a separate run (BC-28219).
user-invocable: true
disable-model-invocation: true
allowed-tools: Bash, Read
metadata:
  version: 0.4.0
  category: Paid Ads
---

# Ads agent (Google)

One bounded run (BC-28215 propose, BC-28216 approve and act; spec BC-28205): results
snapshots in, change plan out. The rule is ADR-0033 in brite-gtm: the agent may move money
inside the ceiling a person set, and never sets money.

Every plan row, approval and apply result is a row in the change log
(`ANALYTICS.OPERATIONS.ADS_AGENT_CHANGE_LOG`). A row is never edited. An approval or a
result is a new row whose key starts with the plan row's key.

## What a run does

1. Checks yesterday's lead counts (see "Data freeze" below). If the run is frozen, it
   stops here.
2. Reads the results snapshots (campaign and ad level) from the warehouse. Results never
   come from the ad APIs. A conversion in the snapshot is a lead.
3. Reads current settings from Google Ads: daily budgets, "limited by budget", shared
   budgets, brand campaigns (label `brand`), and each ad's status.
4. Plans at most one budget move: from the worst cost per conversion to the best campaign
   that is limited by budget. Total daily budget stays the same. Shared budgets and brand
   campaigns are never moved.
5. Plans ad turn-offs:
   - An ad with zero leads turns off once it has spent `kill_multiple` (3) times
     `target_cpl`, never before.
   - Ads in one ad group are compared on cost per lead only once each has spent
     `compare_multiple` (5) times `target_cpl`. The worst of those turns off.
6. Runs each change through the limit checks (`max_move`, `no_total_raise`,
   `weekly_ceiling`, `brand_untouched`). A change that fails a check is `held`.
7. Logs new rows and posts one Slack message. A re-run on the same day logs and posts
   nothing new.

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
is `<cut key>:pair`. Approving either key approves both halves.

## Act mode: the hard limits

Act mode re-checks every limit just before each write, whatever the plan said. It never:

1. raises total budget: it writes the cut first, and writes the raise only after its own
   cut is applied and only if the pair's net is zero or less;
2. moves any budget more than `max_move_pct` (25%) in one run;
3. creates or deletes a campaign without approval;
4. touches a brand campaign or its ads;
5. writes anything while `emergency_stop` is true;
6. writes a rule setting. The agent only reads the rules file, so it cannot clear the stop.

It also refuses a raise that is not half of a planned move, a shared budget, a setting
already changed today, and a setting whose current value is not the planned old value.
Act plans once a day. A re-run only retries what is not yet applied, so nothing is written
twice.

While `weeks_1_2` is true, act writes approved changes only, at most one change per
platform per day. A budget move is one change.

## Before the first run

1. Put the secrets in their own Bitwarden Secrets Manager project (ADR-044). The run reads:
   `GOOGLE_ADS_DEVELOPER_TOKEN`, `GOOGLE_ADS_CLIENT_ID`, `GOOGLE_ADS_CLIENT_SECRET`,
   `GOOGLE_ADS_REFRESH_TOKEN`, `GOOGLE_ADS_LOGIN_CUSTOMER_ID`,
   `ADS_AGENT_SNOWFLAKE_ACCOUNT`, `ADS_AGENT_SNOWFLAKE_USER`,
   `ADS_AGENT_SNOWFLAKE_PRIVATE_KEY`, `ADS_AGENT_SNOWFLAKE_ROLE`,
   `ADS_AGENT_SNOWFLAKE_WAREHOUSE`, `ADS_AGENT_SLACK_WEBHOOK_URL`.
2. Install the runtime libraries: `google-ads`, `snowflake-connector-python`, `cryptography`.
   The machine also needs the IANA time zone data. macOS and most Linux have it; elsewhere
   install `tzdata`.
3. Write the rule settings to a JSON file outside this repo (this repo is public). Only a
   person edits this file:
   - `weekly_ceiling`: dollars a week.
   - `max_move_pct`: 0.25 means 25%.
   - `min_conversions`: conversions a campaign needs before it is judged.
   - `weeks_1_2`: `true` for the first two weeks.
   - `emergency_stop`: `false` unless the Head of GTM has pulled the stop.
   - `target_cpl`: target cost per lead, in dollars.
   - `kill_multiple`: 3.
   - `compare_multiple`: 5.
   - `timezone`: an IANA time zone name, such as `America/Denver`. The run date is today's
     date there, not in UTC, so an evening approval finds that day's plan.
   - `max_lead_count_gap`: 0.20 means 20%. Writes freeze when yesterday's platform and
     BriteBase lead counts differ by more than this.

   `weeks_1_2` and `emergency_stop` must be JSON `true` or `false`. `timezone` must be an
   exact IANA name. Anything else stops the run.
4. Label every brand campaign `brand` in Google Ads.

## Daily flow, weeks 1-2

1. Preview the plan. This writes nothing anywhere:

   ```bash
   cd "${CLAUDE_PLUGIN_ROOT}/scripts" && bws run --project-id <ads-agent project> -- \
     python3 -m ads_agent propose --rules <rules file> --emit
   ```

2. Log the plan and post it to Slack:

   ```bash
   cd "${CLAUDE_PLUGIN_ROOT}/scripts" && bws run --project-id <ads-agent project> -- \
     python3 -m ads_agent propose --rules <rules file>
   ```

   If the output shows `frozen`, stop the daily flow. Tell the Head of GTM the reason, and
   do not approve or act. The freeze lifts on a run that finds yesterday's lead counts in
   agreement.

3. Show the Head of GTM each change: campaign or ad, old → new, reason, checks and key.
   Name any `held` change and the check it failed.
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
     python3 -m ads_agent act --rules <rules file> --emit
   cd "${CLAUDE_PLUGIN_ROOT}/scripts" && bws run --project-id <ads-agent project> -- \
     python3 -m ads_agent act --rules <rules file>
   ```

6. Read the results back to the Head of GTM: each `applied` row, and each `apply_failed`
   row with its reason.

## From about week 3

1. Have a person set `weeks_1_2` to `false` in the rules file.
2. Run `act` once a day. It plans, logs, and applies every proposed change that passed
   every check. Campaign creates and deletes still wait for approval.

## Rules

- Never approve a change the Head of GTM did not name in this session.
- Never edit the rules file from this skill. Never change a setting in Google Ads by hand.
- Never work around a freeze, for example by raising `max_lead_count_gap` to get a plan.
- Never commit account ids, budgets, ceilings, results or change-log rows to this repo.
- Exit code 2 names the missing secret, the bad rule setting, or the key that matched
  nothing. Fix it; do not work around it.
- Tests: `plugins/marketing/tests/test_ads_agent_run.py` (fakes in `scripts/ads_agent/fakes.py`).
