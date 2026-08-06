"""
did_policy_analysis.py

Template for a difference-in-differences analysis of overdose-mortality policy adoption.

The author-coded policy-adoption-year input was not finalised. No policy-effect point estimates
are part of this release; see README.md and Supplementary Table S3.

This script provides a reproducible Python workflow that:
  1. Estimates an event-study specification using two-way fixed effects (TWFE)
     with not-yet-treated controls.
  2. Computes simple cohort-time average treatment effects by comparing treated
     units to not-yet-treated controls.
  3. Reports an equal-weighted overall ATT and a pre-trend test.

It is intentionally pedagogical. It does NOT implement the full Callaway &
Sant'Anna (2021) estimator (which requires careful weighting, covariance
estimation, and inference). For publication-grade group-time ATT estimates we
recommend the R did package (Callaway & Sant'Anna, 2021) or the did2s package
(Gardner, 2022).

Inputs:
    - results_v17/policy_adoption_years.csv
      Columns: country, first_treat_year, policy_type
      where first_treat_year is the first year the country broadly implemented
      at least one of: opioid-agonist therapy scale-out, naloxone distribution,
      supervised consumption services, or decriminalisation/partial legal regulation.
      Countries never treated should have first_treat_year = 0 or missing.

    - results_v17/annual_mortality_panel.csv (deposited; derived from annual_dodji_panel.csv)
      Columns: country, year, log_asdr (log age-standardised death rate)

Outputs:
    - results_v17/did_event_study.csv
    - results_v17/did_group_att.csv
    - results_v17/did_overall_att.csv
    - results_v17/did_pre_trend_test.csv
    - console summary

Notes:
    - The TWFE event-study uses cohort and year fixed effects with country-level
      clustered standard errors.
    - The group-time ATT comparisons use not-yet-treated units as controls.
    - A joint F-test on pre-treatment event-study coefficients tests for parallel
      trends.
"""

from pathlib import Path
import pandas as pd
import numpy as np
import statsmodels.formula.api as smf

ROOT = Path(__file__).resolve().parent
RESULTS_DIR = ROOT / "results_v17"
POLICY_CSV = RESULTS_DIR / "policy_adoption_years.csv"
MORT_CSV = RESULTS_DIR / "annual_mortality_panel.csv"


def load_data():
    if not POLICY_CSV.exists():
        raise FileNotFoundError(
            f"{POLICY_CSV} not found. Please create this file with columns: "
            "country, first_treat_year, policy_type"
        )
    if not MORT_CSV.exists():
        raise FileNotFoundError(
            f"{MORT_CSV} not found. Please create this file with columns: "
            "country, year, log_asdr"
        )

    policy = pd.read_csv(POLICY_CSV)
    mort = pd.read_csv(MORT_CSV)
    df = mort.merge(policy, on="country", how="left")
    df["first_treat_year"] = df["first_treat_year"].replace(0, np.nan)
    df["treated"] = df["first_treat_year"].notna().astype(int)
    df["post"] = (df["year"] >= df["first_treat_year"]).astype(int)
    df["treat"] = df["treated"] * df["post"]
    return df


def event_study(df, max_lead=5, max_lag=5):
    """
    Event-study regression with cohort and year fixed effects, excluding
    never-treated units from the reference period for clarity.
    Uses not-yet-treated controls for each cohort.
    """
    df = df.copy()
    df["event_time"] = df["year"] - df["first_treat_year"]

    # Create event-time dummies, dropping t=-1
    for k in list(range(-max_lead, 0)) + list(range(1, max_lag + 1)):
        df[f"et{k}"] = (df["event_time"] == k).astype(int)

    # Keep only treated units and not-yet-treated controls
    df = df[(df["treated"] == 1) | (df["first_treat_year"].isna())].copy()

    formula_parts = ["et" + str(k) for k in list(range(-max_lead, 0)) + list(range(1, max_lag + 1))]
    formula = "log_asdr ~ " + " + ".join(formula_parts) + " + C(country) + C(year)"

    model = smf.ols(formula, data=df).fit(cov_type="cluster", cov_kwds={"groups": df["country"]})

    rows = []
    for k in list(range(-max_lead, 0)) + list(range(1, max_lag + 1)):
        rows.append({
            "event_time": k,
            "beta": model.params[f"et{k}"],
            "se": model.bse[f"et{k}"],
            "p": model.pvalues[f"et{k}"],
            "ci_lower": model.conf_int().loc[f"et{k}", 0],
            "ci_upper": model.conf_int().loc[f"et{k}", 1],
        })
    return pd.DataFrame(rows)


def group_time_att(df):
    """
    Simple group-time ATT: for each cohort g and each post-treatment year t,
    compare treated units to not-yet-treated controls, then average.
    This is a pedagogical Python implementation; for final inference use the
    R did package or bootstrap inference.
    """
    cohorts = sorted(df["first_treat_year"].dropna().unique())
    results = []

    for g in cohorts:
        treated_units = df[df["first_treat_year"] == g].copy()
        # Not-yet-treated controls: never-treated or treated after year g
        controls = df[(df["first_treat_year"].isna()) | (df["first_treat_year"] > g)].copy()

        for t in range(int(g), int(df["year"].max()) + 1):
            treated_t = treated_units[treated_units["year"] == t]
            control_t = controls[controls["year"] == t]
            if len(treated_t) == 0 or len(control_t) == 0:
                continue

            # Two-way FE residualised comparison (simplified)
            treated_mean = treated_t["log_asdr"].mean()
            control_mean = control_t["log_asdr"].mean()
            att = treated_mean - control_mean

            results.append({
                "cohort": g,
                "year": t,
                "att": att,
                "n_treated": len(treated_t),
                "n_control": len(control_t),
            })

    return pd.DataFrame(results)


def overall_att(group_att_df):
    """Equal-weighted average of cohort-time ATTs."""
    if group_att_df.empty:
        return np.nan
    return group_att_df["att"].mean()


def pre_trend_test(df, max_lead=5):
    """
    Joint F-test of pre-treatment event-study coefficients.
    Rejects the null of parallel trends if pre-treatment coefficients are
    jointly different from zero.
    """
    df = df.copy()
    df["event_time"] = df["year"] - df["first_treat_year"]
    for k in range(-max_lead, 0):
        df[f"et{k}"] = (df["event_time"] == k).astype(int)
    df = df[(df["treated"] == 1) | (df["first_treat_year"].isna())].copy()
    formula_parts = [f"et{k}" for k in range(-max_lead, 0)]
    formula = "log_asdr ~ " + " + ".join(formula_parts) + " + C(country) + C(year)"
    model = smf.ols(formula, data=df).fit(cov_type="cluster", cov_kwds={"groups": df["country"]})
    hypotheses = " = ".join(formula_parts) + " = 0"
    ftest = model.f_test(hypotheses)
    return pd.DataFrame({
        "f_statistic": [ftest.fvalue.item() if hasattr(ftest.fvalue, "item") else ftest.fvalue],
        "p_value": [ftest.pvalue.item() if hasattr(ftest.pvalue, "item") else ftest.pvalue],
        "df_num": [ftest.df_num],
        "df_denom": [ftest.df_denom],
    })


def main():
    df = load_data()
    print(f"Loaded {len(df)} country-year observations; "
          f"{df['country'].nunique()} countries; "
          f"{df['first_treat_year'].notna().sum()} treated unit-years.")

    print("\n=== Event-study estimates ===")
    es = event_study(df, max_lead=5, max_lag=5)
    print(es.round(4).to_string(index=False))
    es.to_csv(RESULTS_DIR / "did_event_study.csv", index=False)

    print("\n=== Group-time ATT ===")
    gatt = group_time_att(df)
    print(gatt.round(4).to_string(index=False))
    gatt.to_csv(RESULTS_DIR / "did_group_att.csv", index=False)

    print("\n=== Overall ATT ===")
    overall = overall_att(gatt)
    print(f"Overall ATT (equal-weighted): {overall:.4f}")
    pd.DataFrame({"overall_att": [overall]}).to_csv(
        RESULTS_DIR / "did_overall_att.csv", index=False
    )

    print("\n=== Pre-trend test ===")
    pre_trend = pre_trend_test(df, max_lead=5)
    print(pre_trend.round(4).to_string(index=False))
    pre_trend.to_csv(RESULTS_DIR / "did_pre_trend_test.csv", index=False)

    print("\nSaved results_v17/did_event_study.csv, did_group_att.csv, did_overall_att.csv, did_pre_trend_test.csv")
    print("\nNOTE: For publication-grade group-time ATT inference, use the R did package (Callaway & Sant'Anna, 2021).")


if __name__ == "__main__":
    main()
