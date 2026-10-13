"""Ads watchdog (BC-28219): an hourly pace check and a daily settings audit over every ad
account on Google and Meta, Brite's and the vendors'. It can only pause.

Its own package on purpose: it watches the ads agent, so it shares none of the agent's code.
Run it with `python -m ads_watchdog --help` from `plugins/marketing/scripts/`.
"""
