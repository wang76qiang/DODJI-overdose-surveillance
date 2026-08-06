"""
run_gbd2021_ageband_robustness.py

Internal GBD 2021 robustness using age-band-specific age-standardised rates.
The files in E:/药物滥用/数据16/数据16 contain 44 European DODJI countries
(Europe-only subset), so this check is reported as a European sensitivity analysis.

Inputs:
  - <DODJI_AGE_BAND_DIR>/15-49岁标化.csv
  - <DODJI_AGE_BAND_DIR>/15-64标化数据.csv
  - <DODJI_AGE_BAND_DIR>/65+标化数据.csv
  - results_v17/reclassification_table_v17.csv
  - results_v17/mechanism_variables_47countries.csv
  The input directory defaults to E:/药物滥用/数据16/数据16 and can be overridden
  via the DODJI_AGE_BAND_DIR environment variable.

Outputs:
  - results_v17/gbd2021_ageband_robustness_summary.csv
  - results_v17/gbd2021_ageband_country_scores.csv
"""

from pathlib import Path
import os
import pandas as pd
import numpy as np
from scipy import stats
import statsmodels.api as sm

# Paths: configurable via environment variable
DATA_DIR = Path(os.environ.get("DODJI_AGE_BAND_DIR", "E:/药物滥用/数据16/数据16"))
RESULTS_DIR = Path(__file__).resolve().parent / "results_v17"

DODJI_CSV = RESULTS_DIR / "reclassification_table_v17.csv"
MECH_CSV = RESULTS_DIR / "mechanism_variables_47countries.csv"

AGEBAND_FILES = {
    "15-49 years": DATA_DIR / "15-49岁标化.csv",
    "15-64 years": DATA_DIR / "15-64标化数据.csv",
    "65+ years": DATA_DIR / "65+标化数据.csv",
}

# Short country names in age-band files -> DODJI country names
SHORT_TO_DODJI = {
    "Albania": "Albania",
    "Andorra": "Andorra",
    "Argentina": "Argentina",
    "Australia": "Australia",
    "Austria": "Austria",
    "Belarus": "Belarus",
    "Belgium": "Belgium",
    "Bosnia and Herzegovina": "Bosnia and Herzegovina",
    "Brazil": "Brazil",
    "Bulgaria": "Bulgaria",
    "Canada": "Canada",
    "Chile": "Chile",
    "Colombia": "Colombia",
    "Costa Rica": "Costa Rica",
    "Croatia": "Croatia",
    "Cyprus": "Cyprus",
    "Czechia": "Czechia",
    "Denmark": "Denmark",
    "Dominican Republic": "Dominican Republic",
    "Ecuador": "Ecuador",
    "Estonia": "Estonia",
    "Finland": "Finland",
    "France": "France",
    "Germany": "Germany",
    "Greece": "Greece",
    "Guatemala": "Guatemala",
    "Hungary": "Hungary",
    "Iceland": "Iceland",
    "Ireland": "Ireland",
    "Israel": "Israel",
    "Italy": "Italy",
    "Japan": "Japan",
    "Latvia": "Latvia",
    "Lithuania": "Lithuania",
    "Luxembourg": "Luxembourg",
    "Malta": "Malta",
    "Mexico": "Mexico",
    "Monaco": "Monaco",
    "Montenegro": "Montenegro",
    "Netherlands": "Netherlands",
    "New Zealand": "New Zealand",
    "North Macedonia": "North Macedonia",
    "Norway": "Norway",
    "Panama": "Panama",
    "Peru": "Peru",
    "Poland": "Poland",
    "Portugal": "Portugal",
    "Republic of Korea": "South Korea",
    "Republic of Moldova": "Republic of Moldova",
    "Romania": "Romania",
    "Russian Federation": "Russian Federation",
    "San Marino": "San Marino",
    "Serbia": "Serbia",
    "Slovakia": "Slovakia",
    "Slovenia": "Slovenia",
    "Spain": "Spain",
    "Sweden": "Sweden",
    "Switzerland": "Switzerland",
    "Turkey": "Turkey",
    "Ukraine": "Ukraine",
    "United Kingdom": "United Kingdom",
    "United States of America": "United States of America",
    "Uruguay": "Uruguay",
}


def load_ageband(path):
    """Load an age-band file and map short country names to DODJI names."""
    df = pd.read_csv(path, encoding="utf-8", low_memory=False)
    # Map to DODJI names
    df["country"] = df["location_name"].map(SHORT_TO_DODJI)
    df = df.dropna(subset=["country"]).copy()
    return df


def compute_dodji_components(gbd_df, cause="Drug use disorders", age="Age-standardized", metric="Rate"):
    """Compute relative uncertainty for each country-year."""
    sub = gbd_df[
        (gbd_df["cause_name"] == cause) &
        (gbd_df["age_name"] == age) &
        (gbd_df["metric_name"] == metric) &
        (gbd_df["sex_name"] == "Both")
    ].copy()
    if sub.empty:
        return None
    sub = sub[["country", "year", "val", "upper", "lower"]].copy()
    sub.columns = ["country", "year", "rate", "upper", "lower"]
    sub["rel_uncertainty"] = (sub["upper"] - sub["lower"]) / sub["rate"].replace(0, np.nan)
    sub["rel_uncertainty"] = sub["rel_uncertainty"].replace([np.inf, -np.inf], np.nan)
    return sub


def compute_dodji_score(components, gdp_per_capita):
    """Cross-sectional DODJI = studentised residual of mean rel_uncertainty on log GDP."""
    avg = components.groupby("country").agg(
        rel_uncertainty=("rel_uncertainty", "mean"),
        rate=("rate", "mean")
    ).reset_index()

    # Standardise relative uncertainty
    avg["rel_unc_std"] = (avg["rel_uncertainty"] - avg["rel_uncertainty"].mean()) / avg["rel_uncertainty"].std()

    # GDP residualise
    gdp = pd.DataFrame({"country": gdp_per_capita.index, "gdp": gdp_per_capita.values})
    avg = avg.merge(gdp, on="country")
    avg["log_gdp"] = np.log(avg["gdp"])
    X = sm.add_constant(avg["log_gdp"])
    model = sm.OLS(avg["rel_unc_std"], X, missing="drop").fit()
    resid = avg["rel_unc_std"] - model.predict(X)
    h = X.values @ np.linalg.inv(X.T.values @ X.values) @ X.T.values
    h_diag = np.diag(h)
    mse = np.sum(model.resid ** 2) / model.df_resid
    se_resid = np.sqrt(mse * (1 - h_diag))
    avg["dodji"] = resid / se_resid
    return avg.set_index("country")["dodji"]


def classify_regime(dodji):
    """Classify DODJI into four regimes by quartiles."""
    q = np.nanquantile(dodji, [0.25, 0.5, 0.75])
    regimes = pd.Series(index=dodji.index, dtype=object)
    regimes[dodji <= q[0]] = "Medical-system-driven"
    regimes[(dodji > q[0]) & (dodji <= q[1])] = "Low-burden / protected"
    regimes[(dodji > q[1]) & (dodji <= q[2])] = "Data-quality-limited"
    regimes[dodji > q[2]] = "Insufficient exposure data"
    return regimes


def robustness_summary(primary, alternative, label):
    merged = pd.DataFrame({"primary": primary, "alt": alternative}).dropna()
    if len(merged) < 3:
        return {
            "check": label,
            "n": len(merged),
            "spearman_rho": np.nan,
            "spearman_p": np.nan,
            "regime_stability": np.nan,
            "priority_I_jaccard": np.nan,
        }
    rho, pval = stats.spearmanr(merged["primary"], merged["alt"])
    regime_primary = classify_regime(merged["primary"])
    regime_alt = classify_regime(merged["alt"])
    stability = np.mean(regime_primary == regime_alt)
    priority_primary = set(merged.nsmallest(10, "primary").index)
    priority_alt = set(merged.nsmallest(10, "alt").index)
    jaccard = len(priority_primary & priority_alt) / len(priority_primary | priority_alt)
    return {
        "check": label,
        "n": len(merged),
        "spearman_rho": round(rho, 3),
        "spearman_p": round(pval, 4),
        "regime_stability": round(stability, 3),
        "priority_I_jaccard": round(jaccard, 3),
    }


def main():
    RESULTS_DIR.mkdir(parents=True, exist_ok=True)

    # Load primary DODJI and GDP
    dodji = pd.read_csv(DODJI_CSV)
    primary_dodji = dodji.set_index("country")["dodji_score"]

    mech = pd.read_csv(MECH_CSV)
    gdp_per_capita = mech.set_index("country")["wb_gdp_per_capita"]

    # Compute age-band DODJIs
    ageband_scores = {}
    for label, path in AGEBAND_FILES.items():
        print(f"Processing {label} ...")
        df = load_ageband(path)
        comp = compute_dodji_components(df)
        if comp is None or comp.empty:
            print(f"  Warning: no data for {label}")
            continue
        scores = compute_dodji_score(comp, gdp_per_capita)
        ageband_scores[label] = scores
        print(f"  Countries: {len(scores)}")

    # Robustness checks against primary DODJI (same-country intersection)
    checks = []
    for label, scores in ageband_scores.items():
        checks.append(robustness_summary(primary_dodji, scores, f"Primary vs {label} age-standardised"))

    summary_df = pd.DataFrame(checks)
    summary_df.to_csv(RESULTS_DIR / "gbd2021_ageband_robustness_summary.csv", index=False)
    print("\nAge-band robustness summary:")
    print(summary_df.to_string(index=False))

    # Country-level scores across age bands
    scores_df = pd.DataFrame(ageband_scores)
    scores_df["primary_dodji"] = primary_dodji
    scores_df = scores_df.dropna(how="all", subset=ageband_scores.keys())
    scores_df = scores_df.sort_values("primary_dodji")
    scores_df.to_csv(RESULTS_DIR / "gbd2021_ageband_country_scores.csv")

    print("\nFiles written:")
    print(f"  {RESULTS_DIR / 'gbd2021_ageband_robustness_summary.csv'}")
    print(f"  {RESULTS_DIR / 'gbd2021_ageband_country_scores.csv'}")


if __name__ == "__main__":
    main()
