#!/usr/bin/env python3
"""Run a Snowflake query from stdin and print TSV. Used to reproduce every figure
in this audit.

Reads connection settings from the environment, falling back to the
`brite_enterprise_data_platform` profile in ~/.dbt/profiles.yml (the standard
team setup). Nothing here is specific to one workstation.

Environment overrides (each falls back to the dbt profile, then to a default):
    SNOWFLAKE_ACCOUNT
    SNOWFLAKE_USER
    SNOWFLAKE_ROLE                  default: profile value
    SNOWFLAKE_WAREHOUSE             default: profile value
    SNOWFLAKE_DATABASE              default: ANALYTICS
    SNOWFLAKE_SCHEMA                default: STAGING
    SNOWFLAKE_PRIVATE_KEY_PATH      key-pair auth (default: profile value)
    SNOWFLAKE_PRIVATE_KEY_PASSPHRASE  if the key is encrypted
    SNOWFLAKE_PASSWORD              password auth, used when no key path resolves
    DBT_PROFILE                     default: brite_enterprise_data_platform
    DBT_TARGET                      default: the profile's own `target`

Usage:
    python3 queries/sfq.py < queries/q_base.sql

Requires: snowflake-connector-python, cryptography, PyYAML
    python3 -m pip install 'snowflake-connector-python[secure-local-storage]' pyyaml

Statements are separated by a line containing exactly `--SPLIT--`.
"""
import os
import sys


def _load_dbt_profile():
    """Best-effort read of ~/.dbt/profiles.yml. Returns {} if unavailable."""
    path = os.path.expanduser(os.environ.get("DBT_PROFILES_PATH", "~/.dbt/profiles.yml"))
    if not os.path.exists(path):
        return {}
    try:
        import yaml
    except ImportError:
        return {}
    try:
        with open(path) as fh:
            profiles = yaml.safe_load(fh) or {}
    except Exception:
        return {}
    prof = profiles.get(os.environ.get("DBT_PROFILE", "brite_enterprise_data_platform"))
    if not isinstance(prof, dict):
        return {}
    target = os.environ.get("DBT_TARGET") or prof.get("target")
    outputs = prof.get("outputs") or {}
    return outputs.get(target) or {}


def _setting(env_key, profile, profile_key, default=None):
    return os.environ.get(env_key) or profile.get(profile_key) or default


def _private_key_bytes(path, passphrase):
    from cryptography.hazmat.backends import default_backend
    from cryptography.hazmat.primitives import serialization

    with open(os.path.expanduser(path), "rb") as fh:
        key = serialization.load_pem_private_key(
            fh.read(),
            password=passphrase.encode() if passphrase else None,
            backend=default_backend(),
        )
    return key.private_bytes(
        encoding=serialization.Encoding.DER,
        format=serialization.PrivateFormat.PKCS8,
        encryption_algorithm=serialization.NoEncryption(),
    )


def main():
    try:
        import snowflake.connector
    except ImportError:
        sys.exit(
            "snowflake-connector-python is not installed.\n"
            "  python3 -m pip install 'snowflake-connector-python[secure-local-storage]' pyyaml"
        )

    profile = _load_dbt_profile()
    account = _setting("SNOWFLAKE_ACCOUNT", profile, "account")
    user = _setting("SNOWFLAKE_USER", profile, "user")
    if not account or not user:
        sys.exit(
            "Snowflake account/user not resolved.\n"
            "  Set SNOWFLAKE_ACCOUNT and SNOWFLAKE_USER, or configure the\n"
            "  'brite_enterprise_data_platform' profile in ~/.dbt/profiles.yml."
        )

    kwargs = dict(
        account=account,
        user=user,
        role=_setting("SNOWFLAKE_ROLE", profile, "role"),
        warehouse=_setting("SNOWFLAKE_WAREHOUSE", profile, "warehouse"),
        database=_setting("SNOWFLAKE_DATABASE", profile, "database", "ANALYTICS"),
        schema=_setting("SNOWFLAKE_SCHEMA", profile, "schema", "STAGING"),
    )

    key_path = _setting("SNOWFLAKE_PRIVATE_KEY_PATH", profile, "private_key_path")
    password = os.environ.get("SNOWFLAKE_PASSWORD") or profile.get("password")
    if key_path and os.path.exists(os.path.expanduser(key_path)):
        kwargs["private_key"] = _private_key_bytes(
            key_path, os.environ.get("SNOWFLAKE_PRIVATE_KEY_PASSPHRASE")
        )
    elif password:
        kwargs["password"] = password
    else:
        sys.exit(
            "No Snowflake credential resolved.\n"
            "  Set SNOWFLAKE_PRIVATE_KEY_PATH to a key-pair file, or SNOWFLAKE_PASSWORD,\n"
            "  or configure private_key_path in your dbt profile."
        )

    con = snowflake.connector.connect(**{k: v for k, v in kwargs.items() if v})
    try:
        cur = con.cursor()
        for stmt in (s for s in sys.stdin.read().split(";\n--SPLIT--\n") if s.strip()):
            cur.execute(stmt)
            print("\t".join(c[0] for c in cur.description))
            rows = cur.fetchall()
            for row in rows:
                print("\t".join("" if v is None else str(v) for v in row))
            print(f"-- {len(rows)} rows")
    finally:
        con.close()


if __name__ == "__main__":
    main()
