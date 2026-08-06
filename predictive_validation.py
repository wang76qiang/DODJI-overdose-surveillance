"""
predictive_validation.py

Framework for P1a: test whether DODJI predicts future surveillance deterioration
or mortality changes.

Required inputs:
    - Annual country-level GBD overdose mortality estimates (or WHO Mortality Database)
      for years before and after the DODJI reference year.
    - results_v17/reclassification_table_v17.csv with primary DODJI scores.

Output:
    results_v17/predictive_validation.csv
"""

from pathlib import Path
import pandas as pd
import numpy as np
from scipy import stats
import statsmodels.api as sm
import statsmodels.formula.api as smf

ROOT = Path(__file__).resolve().parent
RESULTS_DIR = ROOT / "results_v17"
INPUT_CSV = RESULTS_DIR / "reclassification_table_v17.csv"
OUTPUT_CSV = RESULTS_DIR / "predictive_validation.csv"


def load_annual_panel():
    """Load annual overdose mortality / surveillance panel. Placeholder."""
    path = RESULTS_DIR / "annual_overdose_panel_2010_2021.csv"
    if not path.exists():
        raise FileNotFoundError(
            f"{path} not found. Build an annual country-year panel from GBD / WHO."
        )
    return pd.read_csv(path)


def rank_deterioration(df, country_col="country", year_col="year", value_col="mortality_rate", baseline_year=2019, horizon_year=2021):
    """Compute change in mortality rank between baseline and horizon."""
    baseline = df[df[year_col] == baseline_year][[country_col, value_col]].rename(
        columns={value_col: "baseline_rate"}
    )
    horizon = df[df[year_col] == horizon_year][[country_col, value_col]].rename(
        columns={value_col: "horizon_rate"}
    )
    merged = baseline.merge(horizon, on=country_col)
    merged["baseline_rank"] = merged["baseline_rate"].rank(ascending=False)
    merged["horizon_rank"] = merged["horizon_rate"].rank(ascending=False)
    merged["rank_worsening"] = merged["horizon_rank"] - merged["baseline_rank"]
    return merged


def mortality_acceleration(df, country_col="country", year_col="year", value_col="mortality_rate", start=2010, end=2019):
    """Estimate pre-DODJI mortality trend per country (slope)."""
    slopes = []
    for country, g in df.groupby(country_col):
        sub = g[(g[year_col] >= start) & (g[year_col] <= end)].dropna(subset=[value_col])
        if len(sub) >= 3:
            slope, intercept, r, p, se = stats.linregress(sub[year_col], sub[value_col])
            slopes.append({country_col: country, "mortality_slope_pre2019": slope, "slope_p": p})
    return pd.DataFrame(slopes)


def main():
    primary = pd.read_csv(INPUT_CSV)
    primary = primary[["country", "dodji_score", "typology"]].rename(
        columns={"dodji_score": "dodji"}
    )

    try:
        panel = load_annual_panel()
    except FileNotFoundError as e:
        print(e)
        print("\nPredictive validation is currently in framework-only mode.")
        print("To run it, create results_v17/annual_overdose_panel_2010_2021.csv")
        print("with columns: country, year, mortality_rate, gbd_upper_ui, gbd_lower_ui, who_rate")
        return

    # Outcome 1: rank deterioration 2019 -> 2021
    rank_change = rank_deterioration(panel, baseline_year=2019, horizon_year=2021)
    rank_change = rank_change.merge(primary, on="country")

    # Outcome 2: pre-2019 mortality acceleration
    accel = mortality_acceleration(panel, start=2010, end=2019)
    accel = accel.merge(primary, on="country")

    # Models
    results = []

    # Rank worsening ~ DODJI
    X = sm.add_constant(rank_change["dodji"])
    y = rank_change["rank_worsening"]
    model1 = sm.OLS(y, X, missing="drop").fit()
    results.append({
        "outcome": "rank_worsening_2019_2021",
        "predictor": "dodji",
        "n": int(model1.nobs),
        "beta": round(model1.params["dodji"], 3),
        "se": round(model1.bse["dodji"], 3),
        "p": round(model1.pvalues["dodji"], 4),
        "r2": round(model1.rsquared, 3),
    })

    # Mortality slope ~ DODJI
    X2 = sm.add_constant(accel["dodji"])
    y2 = accel["mortality_slope_pre2019"]
    model2 = sm.OLS(y2, X2, missing="drop").fit()
    results.append({
        "outcome": "mortality_slope_2010_2019",
        "predictor": "dodji",
        "n": int(model2.nobs),
        "beta": round(model2.params["dodji"], 3),
        "se": round(model2.bse["dodji"], 3),
        "p": round(model2.pvalues["dodji"], 4),
        "r2": round(model2.rsquared, 3),
    })

    out = pd.DataFrame(results)
    out.to_csv(OUTPUT_CSV, index=False)
    print(f"Saved {OUTPUT_CSV}")
    print(out)


if __name__ == "__main__":
    main()
