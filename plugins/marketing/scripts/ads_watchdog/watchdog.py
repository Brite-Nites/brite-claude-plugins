"""The watchdog's decisions. No I/O here: platforms come in as adapters, alerts go out
through `notify`.

An adapter offers exactly four methods, and only one of them writes:

    accounts() -> list[Account]
    daily_stats(account, start, end) -> list[DayStats]   # spend and leads per local day
    settings(account) -> dict                            # see audit()
    pause(account) -> list[str]                          # names of campaigns it paused

There is no budget, bid or ad method to call, so the watchdog cannot change them.
"""

from __future__ import annotations

import math
from dataclasses import dataclass
from datetime import date, datetime, timedelta
from zoneinfo import ZoneInfo


@dataclass(frozen=True)
class Account:
    platform: str  # "google" or "meta"
    id: str
    name: str
    timezone: str  # the account's own reporting timezone; its "today" starts there

    @property
    def key(self) -> str:
        return f"{self.platform}:{self.id}"


@dataclass(frozen=True)
class DayStats:
    day: date
    spend: float
    leads: float


def _money(x: float) -> str:
    return f"{x:,.2f}"


def _breach(account: Account, days: list[DayStats], config: dict, local: datetime) -> str | None:
    """Why this account must be paused now, or None if its spend is inside the expected range."""
    weekly = config["weekly_ceiling"] * config["shares"][account.key]
    week = sum(d.spend for d in days)
    if week > weekly:
        return f"over its share: spent {_money(week)} this week; its share is {_money(weekly)}"
    today = sum(d.spend for d in days if d.day == local.date())
    elapsed = (local.hour * 60 + local.minute) / 1440
    expected = weekly / 7 * max(elapsed, config["pace_floor"])
    low, high = expected / config["pace_tolerance"], expected * config["pace_tolerance"]
    if today > high:
        return (
            f"ahead of pace: spent {_money(today)} today by {local:%H:%M}; "
            f"expected {_money(low)}–{_money(high)}"
        )
    return None


# Settings that must be off. An adapter reports each as the list of things that have it on
# (campaigns, ads, recommendation types); an empty list is the agreed state. A setting a
# platform does not have is left out of its report and not checked.
MUST_BE_OFF = {
    "auto_apply": "auto-apply recommendations on",
    "auto_ad_edits": "automatic ad edits on",
    "search_partners": "search partners on",
    "ai_max": "AI Max on",
    "broad_match": "broad match on",
    "non_presence": 'location targeting not set to "Presence"',
}


def _drift(settings: dict, config: dict) -> list[str]:
    found = [f"{label}: {', '.join(settings[key])}" for key, label in MUST_BE_OFF.items() if settings.get(key)]
    if "negative_lists" in settings:
        missing = [c for c, lists in settings["negative_lists"].items() if config["partner_exclusion_list"] not in lists]
        if missing:
            found.append(f"partner brand exclusions missing: {', '.join(missing)}")
    if "spending_limit" in settings:
        if not settings["spending_limit"]:
            found.append("no account spending limit set")
        outsiders = [u for u in settings["limit_holders"] if u not in config["brite_admins"]]
        if outsiders:
            found.append(f"spending limit can be changed by someone who is not a Brite admin: {', '.join(outsiders)}")
    return found


def _poisson_cdf(k: int, lam: float) -> float:
    """P(X <= k) for X ~ Poisson(lam), summed in log space so a large lam cannot underflow."""
    if lam <= 0:
        return 1.0
    return sum(math.exp(i * math.log(lam) - lam - math.lgamma(i + 1)) for i in range(k + 1))


def _lead_shortfall(days: list[DayStats], config: dict) -> str | None:
    """Alert when leads fall improbably far below the expected range — not on "zero leads".

    The range comes from spend and the expected cost per lead. Even at the dearest cost we
    accept, seeing this few leads must be less likely than `lead_alert_probability` before
    we say anything, so a quiet stretch on low spend stays quiet.
    """
    spend, leads = sum(d.spend for d in days), sum(d.leads for d in days)
    cheapest, dearest = config["expected_cost_per_lead"]
    low, high = spend / dearest, spend / cheapest
    if _poisson_cdf(int(leads), low) < config["lead_alert_probability"]:
        return f"{leads:g} leads on {_money(spend)} spend in the last 7 days; expected {low:.1f}–{high:.1f}"
    return None


def audit(adapters: list, config: dict, notify, now: datetime) -> list[str]:
    """Check every account against the agreed settings and its expected lead range.

    Always posts, so a day with no post means the watchdog itself is down.
    """
    findings, checked = [], 0
    for adapter in adapters:
        for account in adapter.accounts():
            checked += 1
            found = _drift(adapter.settings(account), config)
            if account.key not in config["shares"]:
                found.append("not in the watchdog config, so its pace is not watched")
            today = now.astimezone(ZoneInfo(account.timezone)).date()
            shortfall = _lead_shortfall(adapter.daily_stats(account, today - timedelta(days=7), today - timedelta(days=1)), config)
            if shortfall:
                found.append(shortfall)
            findings += [f"{account.name} ({account.key}): {f}" for f in found]
    notify(f"Ads settings audit {now:%Y-%m-%d}: {checked} accounts checked, {len(findings)} findings." + "".join(f"\n{f}" for f in findings))
    return findings


def emergency_stop(adapters: list, notify) -> list[str]:
    """Pause every account on every platform, mapped or not. Alerts when anything was running."""
    lines, newly = [], False
    for adapter in adapters:
        for account in adapter.accounts():
            paused = adapter.pause(account)
            newly = newly or bool(paused)
            lines.append(f"{account.name} ({account.key}): " + (f"paused {', '.join(paused)}" if paused else "already paused"))
    if newly:
        notify("Ads EMERGENCY STOP: every account on every platform is paused.\n" + "\n".join(lines))
    return lines


def hourly(adapters: list, config: dict, notify, now: datetime) -> list[str]:
    """Pause every account whose spend breaks pace or its share. One alert per run.

    While the emergency stop is on, every run pauses everything instead, so an account
    someone re-enables is stopped again within the hour.
    """
    if config["emergency_stop"]:
        return emergency_stop(adapters, notify)
    alerts = []
    for adapter in adapters:
        for account in adapter.accounts():
            if account.key not in config["shares"]:
                continue  # not in the config: the daily audit names it
            local = now.astimezone(ZoneInfo(account.timezone))
            monday = local.date() - timedelta(days=local.weekday())  # the share is per Monday-to-Sunday week
            reason = _breach(account, adapter.daily_stats(account, monday, local.date()), config, local)
            if reason:
                paused = adapter.pause(account)
                if paused:  # empty means it was already paused: nothing new to say
                    alerts.append(f"Paused {account.name} ({account.key}): {reason}. Campaigns: {', '.join(paused)}")
    if alerts:
        notify("Ads watchdog\n" + "\n".join(alerts))
    return alerts
