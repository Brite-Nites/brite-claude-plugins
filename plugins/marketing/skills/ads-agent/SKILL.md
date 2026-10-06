---
name: ads-agent
description: Runs Brite's own Google Ads agent for one day in propose mode. Reads the results snapshot from the warehouse and current campaign settings from Google Ads, plans budget moves inside hard limits, writes the plan to the warehouse change log, and posts a Slack summary. Changes nothing in any ad account. Use in the daily session with the Head of GTM to see what the agent would do. Triggers "ads agent", "run the ads agent", "propose ad changes", "paid ads daily plan". Approval and act mode arrive with BC-28216; the watchdog is a separate run (BC-28219).
user-invocable: true
disable-model-invocation: true
allowed-tools: Bash, Read
metadata:
  version: 0.1.0
  category: Paid Ads
---

# Ads agent (propose mode, Google)

One bounded run (BC-28215, spec BC-28205): results snapshot in, change plan out.
Propose mode never writes to Google Ads. It writes the plan to the change log
(`ANALYTICS.OPERATIONS.ADS_AGENT_CHANGE_LOG`) and posts the day's changes to Slack.
A re-run on the same day plans nothing new and posts nothing.

## What the run does

1. Reads the results snapshot from the warehouse. Results never come from the ad APIs.
2. Reads current settings (daily budget, "limited by budget", shared budget) for the
   accounts in the snapshot from Google Ads.
3. Judges campaigns with at least `min_conversions` conversions. Plans one budget move:
   from the worst cost per conversion to the best campaign that is limited by budget.
   Total daily budget stays the same. Shared budgets are never moved.
4. Runs each change through the limit checks (`max_move`, `no_total_raise`,
   `weekly_ceiling`). A change that fails a check is logged as `held`, not `proposed`.
5. Logs new rows (keyed, so a re-run adds none) and posts one Slack message. A day with
   nothing to change logs one `no_change` row with the reason.

## Before the first run

1. Put the secrets in their own Bitwarden Secrets Manager project (ADR-044). The run reads:
   `GOOGLE_ADS_DEVELOPER_TOKEN`, `GOOGLE_ADS_CLIENT_ID`, `GOOGLE_ADS_CLIENT_SECRET`,
   `GOOGLE_ADS_REFRESH_TOKEN`, `GOOGLE_ADS_LOGIN_CUSTOMER_ID`,
   `ADS_AGENT_SNOWFLAKE_ACCOUNT`, `ADS_AGENT_SNOWFLAKE_USER`,
   `ADS_AGENT_SNOWFLAKE_PRIVATE_KEY`, `ADS_AGENT_SNOWFLAKE_ROLE`,
   `ADS_AGENT_SNOWFLAKE_WAREHOUSE`, `ADS_AGENT_SLACK_WEBHOOK_URL`.
2. Install the runtime libraries: `google-ads`, `snowflake-connector-python`, `cryptography`.
3. Write the rule settings to a JSON file outside this repo (this repo is public):
   `weekly_ceiling` (dollars a week), `max_move_pct` (0.25 = 25%), `min_conversions`.

## Daily flow

1. Preview. This writes nothing anywhere:

   ```bash
   cd "${CLAUDE_PLUGIN_ROOT}/scripts" && bws run --project-id <ads-agent project> -- \
     python3 -m ads_agent propose --rules <rules file> --emit
   ```

2. Show the Head of GTM each change: campaign, old budget → new budget, reason, and the
   checks. Name any `held` change and the check it failed.
3. Run it for real, which logs the plan and posts to Slack:

   ```bash
   cd "${CLAUDE_PLUGIN_ROOT}/scripts" && bws run --project-id <ads-agent project> -- \
     python3 -m ads_agent propose --rules <rules file>
   ```

4. Stop there. Do not change any setting in Google Ads by hand or by API from this skill.

## Rules

- Never commit account ids, budgets, ceilings, results or change-log rows to this repo.
- Exit code 2 names the missing secret or rule setting. Fix it; do not work around it.
- Tests: `plugins/marketing/tests/test_ads_agent_run.py` (fakes in `scripts/ads_agent/fakes.py`).
