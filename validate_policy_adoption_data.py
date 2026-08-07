"""Validate policy-adoption provenance, scope, and event-study support."""

from __future__ import annotations

import json
from pathlib import Path

import pandas as pd


ROOT = Path(__file__).resolve().parent
RESULTS = ROOT / "results_v17"


def main() -> None:
    policy = pd.read_csv(RESULTS / "policy_adoption_years.csv")
    sources = pd.read_csv(RESULTS / "policy_adoption_sources.csv")
    panel = pd.read_csv(RESULTS / "annual_mortality_panel.csv")

    required = {
        "country", "first_treat_year", "policy_type", "analysis_included",
        "source_id", "source_url", "verification_status",
    }
    missing = required - set(policy.columns)
    assert not missing, f"Missing columns: {sorted(missing)}"
    assert len(policy) == 63
    assert policy["country"].is_unique
    assert set(policy["country"]) == set(panel["country"])
    assert set(policy["analysis_included"].unique()) <= {0, 1}

    included = policy.loc[policy["analysis_included"].eq(1)].copy()
    excluded = policy.loc[policy["analysis_included"].eq(0)].copy()
    assert len(included) == 30
    assert len(excluded) == 33
    assert included["first_treat_year"].notna().all()
    assert excluded["first_treat_year"].isna().all()
    assert included["source_id"].isin(sources["source_id"]).all()
    assert included["source_url"].str.startswith("https://").all()
    assert excluded["verification_status"].eq(
        "scope_excluded_not_assumed_never_treated"
    ).all()

    medication_columns = [
        "methadone_year", "high_dose_buprenorphine_year",
        "buprenorphine_naloxone_year", "slow_release_oral_morphine_year",
    ]
    calculated = included[medication_columns].min(axis=1, skipna=True)
    assert calculated.eq(included["first_treat_year"]).all()
    assert included["first_treat_year"].between(1900, 2018).all()

    panel_start = int(panel["year"].min())
    panel_end = int(panel["year"].max())
    included["timing_group"] = "in_panel"
    included.loc[included["first_treat_year"] < panel_start, "timing_group"] = "pre_panel"
    included.loc[included["first_treat_year"] == panel_start, "timing_group"] = "panel_start"
    included["full_window_observed"] = included["first_treat_year"].between(
        panel_start + 5, panel_end - 5
    )
    cohorts = sorted(int(x) for x in included["first_treat_year"].unique())

    audit = {
        "status": "passed",
        "dataset_version": "1.1.0",
        "panel_countries": int(policy.shape[0]),
        "analysis_included": int(included.shape[0]),
        "scope_excluded": int(excluded.shape[0]),
        "panel_years": [panel_start, panel_end],
        "adoption_year_range": [
            int(included["first_treat_year"].min()),
            int(included["first_treat_year"].max()),
        ],
        "timing_groups": {
            key: int(value) for key, value in included["timing_group"].value_counts().items()
        },
        "unique_adoption_cohorts": cohorts,
        "countries_with_full_plus_minus_5_observation_window": sorted(
            included.loc[included["full_window_observed"], "country"].tolist()
        ),
        "identification_warning": (
            "All 30 analysis-scope countries eventually adopted standard OAT. "
            "There are no verified never-treated controls; identification can use only "
            "not-yet-treated comparisons, and support becomes sparse for late cohorts. "
            "Do not interpret the legacy pedagogical TWFE output as a causal estimate."
        ),
    }
    (RESULTS / "policy_adoption_validation.json").write_text(
        json.dumps(audit, indent=2), encoding="utf-8"
    )
    print(json.dumps(audit, indent=2))


if __name__ == "__main__":
    main()
