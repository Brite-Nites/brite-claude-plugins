"""Unit tests for the IcyPeas query builders (BC-13013).

`icypeas_client.py` built its `/find-companies` query from keyword + location
only, silently dropping the ICP's `size_band`. IcyPeas bills per record RETURNED
and the client pages the whole result set, so an unnarrowed industry keyword was
both a credit-burn event and a quality problem — the corporate-campuses ICP wants
1,000+ employee enterprises, and the committed keywords return ~665K US companies
across five terms (measured 2026-06-09 on the free count surface).

These exercise the pure builders only — no network, no credentials. That is why
`requests`/`dotenv` are imported lazily inside `search()`: the CI python-units job
installs pytest and nothing else, so the module must import on a stdlib-only
interpreter.

Run with `pytest plugins/marketing/tests/test_icypeas_client_contracts.py`.
"""

from __future__ import annotations

import importlib.util
import sys
from pathlib import Path

import pytest

ROOT = Path(__file__).resolve().parents[1]
CLIENT_PATH = ROOT / "scripts" / "tam-map" / "icypeas_client.py"


def _load_client():
    """Load icypeas_client.py by path — scripts/tam-map is not a package."""
    spec = importlib.util.spec_from_file_location("icypeas_client", CLIENT_PATH)
    module = importlib.util.module_from_spec(spec)
    sys.modules["icypeas_client"] = module
    spec.loader.exec_module(module)
    return module


client = _load_client()


# ── build_headcount ───────────────────────────────────────────────────


def test_both_bounds_map_to_inclusive_operators():
    """IcyPeas numeric filters key on comparison operators, not min/max.

    min/max is the `headcountGrowth` shape; using it for `headcount` would be
    accepted-but-unfiltered. Inclusive operators because size_band bounds are
    inclusive — "1,000+ employees" means >= 1000.
    """
    assert client.build_headcount(
        {"size_band": {"employee_min": 1000, "employee_max": 5000}}
    ) == {">=": 1000, "<=": 5000}


def test_lower_bound_alone_still_narrows():
    """The corporate-campuses case: a floor with no ceiling must still filter."""
    assert client.build_headcount({"size_band": {"employee_min": 1000}}) == {">=": 1000}


def test_upper_bound_alone_still_narrows():
    assert client.build_headcount({"size_band": {"employee_max": 50}}) == {"<=": 50}


def test_zero_is_a_real_bound_not_a_missing_one():
    """0 is falsy — a truthiness check here would silently drop the filter."""
    assert client.build_headcount({"size_band": {"employee_min": 0}}) == {">=": 0}


@pytest.mark.parametrize(
    "icp",
    [
        {},
        {"size_band": {}},
        {"size_band": None},
        {"size_band": {"revenue_min": 1_000_000}},  # revenue bounds are not headcount
        {"size_band": {"employee_min": None}},
        {"size_band": {"employee_min": "1000"}},  # strings are not numeric bounds
        {"size_band": {"employee_min": True}},  # bool subclasses int — must not pass
    ],
)
def test_no_usable_band_yields_empty(icp):
    assert client.build_headcount(icp) == {}


def test_float_bounds_are_accepted():
    assert client.build_headcount({"size_band": {"employee_min": 10.5}}) == {">=": 10.5}


def test_inverted_band_is_kept_and_warned(capsys):
    """An inverted band matches nothing — that is safe, but must not be silent.

    Dropping the filter would restore the unbounded pull it exists to prevent, so
    the filter is kept and the operator is told why the result is empty.
    """
    result = client.build_headcount(
        {"size_band": {"employee_min": 5000, "employee_max": 1000}}
    )
    assert result == {">=": 5000, "<=": 1000}
    assert "inverted" in capsys.readouterr().err


# ── build_query ───────────────────────────────────────────────────────


def test_query_carries_keyword_location_and_headcount():
    query = client.build_query(
        {
            "geo": {"regions": ["US"]},
            "size_band": {"employee_min": 1000},
        },
        "Technology",
    )
    assert query == {
        "keyword": {"include": ["Technology"]},
        "location": {"include": ["US"]},
        "headcount": {">=": 1000},
    }


def test_headcount_key_is_omitted_entirely_when_absent():
    """Absent, not empty — an empty object is a different request shape."""
    query = client.build_query({"geo": {"regions": ["US"]}}, "Technology")
    assert "headcount" not in query


def test_industry_term_maps_to_keyword_never_industry():
    """query.industry is a controlled taxonomy — free-text there returns total 0
    with success:true, i.e. silently unfiltered (BC-12163)."""
    query = client.build_query({}, "Aerospace & Defense")
    assert query["keyword"] == {"include": ["Aerospace & Defense"]}
    assert "industry" not in query


def test_location_omitted_when_icp_declares_no_regions():
    assert "location" not in client.build_query({"geo": {"regions": []}}, "Healthcare")
    assert "location" not in client.build_query({}, "Healthcare")


def test_builder_does_not_mutate_the_icp():
    icp = {"geo": {"regions": ["US"]}, "size_band": {"employee_min": 1000}}
    before = repr(icp)
    client.build_query(icp, "Technology")
    assert repr(icp) == before


def test_module_imports_without_requests_installed():
    """Guards the lazy-import contract: if `requests` moves back to module scope,
    the CI python-units job (pytest only) fails at collection."""
    source = CLIENT_PATH.read_text(encoding="utf-8")
    module_level = source.split("def search(", 1)[0]
    assert "\nimport requests" not in module_level
    assert "\nfrom dotenv import" not in module_level
