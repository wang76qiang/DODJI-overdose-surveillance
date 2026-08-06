"""
run_gbd2019_vs_2021_robustness.py

Cross-version robustness: compare DODJI computed from GBD 2019 vs GBD 2021.

Inputs:
  - GBD 2021: E:/药物滥用/大文章撰写分析/原始数据/IHME-GBD_2021_DATA-1f619821-1.csv
              (fallback to E:/药物滥用/数据16/数据16/IHME-GBD_2021_DATA-1a47cb99-*.csv)
  - GBD 2019: user-supplied IHME-GBD_2019_DATA-*.csv file(s)
  - GDP per capita: results_v17/mechanism_variables_47countries.csv

Outputs:
  - results_v17/gbd2019_vs_2021_robustness_summary.csv
  - results_v17/gbd2019_vs_2021_country_ranks.csv
  - results_v17/gbd2019_vs_2021_regime_comparison.csv

How to obtain GBD 2019 data:
  1. Go to https://vizhub.healthdata.org/gbd-results/
  2. Click "Download results"
  3. Set:
       - GBD version: GBD 2019
       - Location: Select all countries (or the 47 DODJI countries)
       - Cause: Drug use disorders
       - Measure: Deaths
       - Metric: Rate
       - Age: Age-standardized
       - Sex: Both
       - Year: 1990-2019
  4. Download CSV and place in e.g. E:/药物滥用/GBD_2019/
  5. Update GBD_2019_FILE or GBD_2019_DIR below.
"""

from pathlib import Path
import os
import pandas as pd
import numpy as np
from scipy import stats
import statsmodels.api as sm

# ---------------------------------------------------------------------------
# Configurable paths (override via environment variables)
# ---------------------------------------------------------------------------
RESULTS_DIR = Path(__file__).resolve().parent / "results_v17"

# GBD 2021: primary source used in the manuscript
GBD_2021_FILE = Path(os.environ.get(
    "DODJI_GBD2021_FILE",
    "E:/药物滥用/大文章撰写分析/原始数据/IHME-GBD_2021_DATA-1f619821-1.csv",
))
# Fallback if the primary file is missing
GBD_2021_DIR = Path(os.environ.get(
    "DODJI_GBD2021_DIR",
    "E:/药物滥用/数据16/数据16",
))

# GBD 2019: user must download from IHME and set this path
GBD_2019_FILE = Path(os.environ.get(
    "DODJI_GBD2019_FILE",
    "E:/药物滥用/GBD_2019/IHME-GBD_2019_DATA-*.csv",  # glob if multiple parts
))
GBD_2019_DIR = Path(os.environ.get("DODJI_GBD2019_DIR", "E:/药物滥用/GBD_2019"))

# DODJI country list and GDP
DODJI_CSV = RESULTS_DIR / "reclassification_table_v17.csv"
MECH_CSV = RESULTS_DIR / "mechanism_variables_47countries.csv"

# Country name mapping: DODJI -> GBD official names
DODJI_TO_GBD = {
    "Albania": "Republic of Albania",
    "Argentina": "Argentine Republic",
    "Australia": "Australia",
    "Austria": "Republic of Austria",
    "Belarus": "Republic of Belarus",
    "Belgium": "Kingdom of Belgium",
    "Bosnia and Herzegovina": "Bosnia and Herzegovina",
    "Brazil": "Federative Republic of Brazil",
    "Bulgaria": "Republic of Bulgaria",
    "Canada": "Canada",
    "Chile": "Republic of Chile",
    "Colombia": "Republic of Colombia",
    "Costa Rica": "Republic of Costa Rica",
    "Croatia": "Republic of Croatia",
    "Cyprus": "Republic of Cyprus",
    "Czechia": "Czech Republic",
    "Denmark": "Kingdom of Denmark",
    "Dominican Republic": "Dominican Republic",
    "Ecuador": "Republic of Ecuador",
    "Estonia": "Republic of Estonia",
    "Finland": "Republic of Finland",
    "France": "French Republic",
    "Germany": "Federal Republic of Germany",
    "Greece": "Hellenic Republic",
    "Guatemala": "Republic of Guatemala",
    "Hungary": "Hungary",
    "Iceland": "Republic of Iceland",
    "Ireland": "Ireland",
    "Israel": "State of Israel",
    "Italy": "Republic of Italy",
    "Latvia": "Republic of Latvia",
    "Lithuania": "Republic of Lithuania",
    "Luxembourg": "Grand Duchy of Luxembourg",
    "Malta": "Republic of Malta",
    "Mexico": "United Mexican States",
    "Monaco": "Principality of Monaco",
    "Montenegro": "Montenegro",
    "Netherlands": "Kingdom of the Netherlands",
    "New Zealand": "New Zealand",
    "North Macedonia": "North Macedonia",
    "Norway": "Kingdom of Norway",
    "Panama": "Republic of Panama",
    "Peru": "Republic of Peru",
    "Poland": "Republic of Poland",
    "Portugal": "Portuguese Republic",
    "Romania": "Romania",
    "Russian Federation": "Russian Federation",
    "San Marino": "Republic of San Marino",
    "Serbia": "Republic of Serbia",
    "Slovakia": "Slovak Republic",
    "Slovenia": "Republic of Slovenia",
    "Spain": "Kingdom of Spain",
    "Sweden": "Kingdom of Sweden",
    "Switzerland": "Swiss Confederation",
    "Turkey": "Republic of Turkey",
    "Ukraine": "Ukraine",
    "United Kingdom": "United Kingdom of Great Britain and Northern Ireland",
    "United States of America": "United States of America",
    "Uruguay": "Eastern Republic of Uruguay",
    "Andorra": "Principality of Andorra",
    "Republic of Moldova": "Republic of Moldova",
    "South Korea": "Republic of Korea",
    "Japan": "Japan",
}
GBD_TO_DODJI = {v: k for k, v in DODJI_TO_GBD.items()}


def find_gbd_2021_file():
    """Return the first available GBD 2021 CSV."""
    if GBD_2021_FILE.exists():
        return GBD_2021_FILE
    # Fallback: use first IHME-GBD_2021_DATA csv in data16 folder
    if GBD_2021_DIR.exists():
        candidates = sorted(GBD_2021_DIR.glob("IHME-GBD_2021_DATA-*.csv"))
        if candidates:
            return candidates[0]
    raise FileNotFoundError("No GBD 2021 CSV found. Please check GBD_2021_FILE/GBD_2021_DIR.")


def find_gbd_2019_files():
    """Return list of GBD 2019 CSV files."""
    if GBD_2019_FILE.exists():
        return [GBD_2019_FILE]
    if GBD_2019_DIR.exists():
        candidates = sorted(GBD_2019_DIR.glob("IHME-GBD_2019_DATA-*.csv"))
        if candidates:
            return candidates
    return []


def load_gbd_csv(path):
    """Load a GBD CSV and restrict to DODJI countries."""
    print(f"Loading {path} ...")
    df = pd.read_csv(path, low_memory=False)
    # Keep only DODJI countries (by official GBD name)
    df = df[df["location_name"].isin(DODJI_TO_GBD.values())].copy()
    df["country"] = df["location_name"].map(GBD_TO_DODJI)
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

    # Load GDP per capita
    mech = pd.read_csv(MECH_CSV)
    gdp_per_capita = mech.set_index("country")["wb_gdp_per_capita"]

    # GBD 2021
    gbd2021_file = find_gbd_2021_file()
    gbd2021 = load_gbd_csv(gbd2021_file)
    comp2021 = compute_dodji_components(gbd2021)
    dodji2021 = compute_dodji_score(comp2021, gdp_per_capita)

    # GBD 2019
    gbd2019_files = find_gbd_2019_files()
    if not gbd2019_files:
        print("\n" + "=" * 70)
        print("ERROR: GBD 2019 data not found.")
        print("=" * 70)
        print(f"Expected file(s) at: {GBD_2019_FILE}")
        print(f"Or directory:        {GBD_2019_DIR}")
        print("\nPlease download GBD 2019 from:")
        print("  https://vizhub.healthdata.org/gbd-results/")
        print("\nRecommended download settings:")
        print("  - GBD version: GBD 2019")
        print("  - Location: all countries (or the 47 DODJI countries)")
        print("  - Cause: Drug use disorders")
        print("  - Measure: Deaths")
        print("  - Metric: Rate")
        print("  - Age: Age-standardized")
        print("  - Sex: Both")
        print("  - Year: 1990-2019")
        print("\nThen update GBD_2019_FILE / GBD_2019_DIR in this script and rerun.")
        print("=" * 70)
        return

    gbd2019_parts = [load_gbd_csv(f) for f in gbd2019_files]
    gbd2019 = pd.concat(gbd2019_parts, ignore_index=True)
    comp2019 = compute_dodji_components(gbd2019)
    dodji2019 = compute_dodji_score(comp2019, gdp_per_capita)

    # Cross-version comparison
    summary = robustness_summary(dodji2021, dodji2019, "GBD 2021 vs GBD 2019 DODJI")
    summary_df = pd.DataFrame([summary])
    summary_df.to_csv(RESULTS_DIR / "gbd2019_vs_2021_robustness_summary.csv", index=False)
    print("\nCross-version robustness summary:")
    print(summary_df.to_string(index=False))

    # Country-level rank comparison
    ranks = pd.DataFrame({
        "dodji_2021": dodji2021,
        "dodji_2019": dodji2019,
    }).dropna()
    ranks["rank_2021"] = ranks["dodji_2021"].rank(method="min")
    ranks["rank_2019"] = ranks["dodji_2019"].rank(method="min")
    ranks["rank_change"] = ranks["rank_2021"] - ranks["rank_2019"]
    ranks["regime_2021"] = classify_regime(ranks["dodji_2021"])
    ranks["regime_2019"] = classify_regime(ranks["dodji_2019"])
    ranks = ranks.sort_values("rank_2021")
    ranks.to_csv(RESULTS_DIR / "gbd2019_vs_2021_country_ranks.csv")

    # Regime stability table
    regime_table = pd.crosstab(ranks["regime_2021"], ranks["regime_2019"])
    regime_table.to_csv(RESULTS_DIR / "gbd2019_vs_2021_regime_comparison.csv")

    print("\nFiles written:")
    print(f"  {RESULTS_DIR / 'gbd2019_vs_2021_robustness_summary.csv'}")
    print(f"  {RESULTS_DIR / 'gbd2019_vs_2021_country_ranks.csv'}")
    print(f"  {RESULTS_DIR / 'gbd2019_vs_2021_regime_comparison.csv'}")


if __name__ == "__main__":
    main()
