"""
run_gbd_who_analyses.py

Use the GBD 2021 and WHO Mortality Database files in
E:/药物滥用/大文章撰写分析/原始数据 to complete:
  1. GBD robustness checks (P0b): cause composition, age metric, uncertainty metric
  2. Cross-source robustness: WHO-only vs GBD-based DODJI
  3. Predictive validation (P1a): annual DODJI trajectories predicting mortality changes

Outputs:
  - results_v17/gbd_robustness_summary.csv
  - results_v17/who_gbd_cross_source_summary.csv
  - results_v17/predictive_validation_results.csv
  - results_v17/annual_dodji_panel.csv
"""

from pathlib import Path
import os
import pandas as pd
import numpy as np
from scipy import stats
import statsmodels.api as sm

# Paths: configurable via environment variables
DATA_DIR = Path(os.environ.get("DODJI_DATA_DIR", "E:/药物滥用/大文章撰写分析/原始数据"))
DODJI_DIR = Path(__file__).resolve().parent / "results_v17"
OUTPUT_DIR = DODJI_DIR

DODJI_CSV = DODJI_DIR / "reclassification_table_v17.csv"
GBD_FILE = DATA_DIR / os.environ.get("DODJI_GBD2021_FILENAME", "IHME-GBD_2021_DATA-1f619821-1.csv")
WHO_FILE = DATA_DIR / os.environ.get(
    "DODJI_WHO_FILENAME",
    "WHOMortalityDatabase_Trends_years_many_countries_by_age_sex-Drug use disorders_23rd 十二月 2025 21_22.csv",
)

# DODJI country name -> GBD country name mapping
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

# Reverse mapping
GBD_TO_DODJI = {v: k for k, v in DODJI_TO_GBD.items()}

# WHO country name -> DODJI name mapping
WHO_TO_DODJI = {
    "United Kingdom of Great Britain and Northern Ireland": "United Kingdom",
}


def load_gbd():
    """Load GBD 2021 data and filter to DODJI countries."""
    print(f"Loading GBD data from {GBD_FILE}...")
    gbd = pd.read_csv(GBD_FILE)
    gbd = gbd[gbd["location_name"].isin(DODJI_TO_GBD.values())].copy()
    gbd["country"] = gbd["location_name"].map(GBD_TO_DODJI)
    return gbd


def load_who():
    """Load WHO Mortality Database and filter to all-ages, all-sexes."""
    print(f"Loading WHO data from {WHO_FILE}...")
    cols_13 = [
        "Region Code", "Region Name", "Country Code", "Country Name", "Year",
        "Sex", "Age group code", "Age Group", "Number", "Percentage",
        "ASDR", "Death rate", "Trailing"
    ]
    who = pd.read_csv(WHO_FILE, skiprows=6, header=None, names=cols_13)
    who = who.drop(columns=["Trailing"])
    who = who[who["Country Name"] != "Country Name"].copy()
    who["Year"] = pd.to_numeric(who["Year"], errors="coerce")
    who = who[(who["Sex"] == "All") & (who["Age Group"] == "[All]")].copy()
    # Map all WHO country names; only some need renaming
    who["country"] = who["Country Name"].map(lambda x: WHO_TO_DODJI.get(x, x))
    who["ASDR"] = pd.to_numeric(who["ASDR"], errors="coerce")
    who["Death rate"] = pd.to_numeric(who["Death rate"], errors="coerce")
    who["Number"] = pd.to_numeric(who["Number"], errors="coerce")
    who = who.rename(columns={"Year": "year"})
    return who


def compute_dodji_components(gbd_df, cause="Drug use disorders", age="Age-standardized", metric="Rate"):
    """
    Compute DODJI components for each country-year.
    Returns DataFrame with country, year, rate, upper, lower, rel_uncertainty, who_gbd_divergence.
    """
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
    sub["rel_uncertainty"] = (sub["upper"] - sub["lower"]) / sub["rate"]
    # Replace inf/nan with large value
    sub["rel_uncertainty"] = sub["rel_uncertainty"].replace([np.inf, -np.inf], np.nan)
    return sub


def compute_dodji_score(components, gdp_per_capita=None):
    """
    Compute cross-sectional DODJI from components averaged over years.
    If gdp_per_capita provided, residualise on log GDP.
    Returns country -> DODJI dict.
    """
    # Average over years
    avg = components.groupby("country").agg({
        "rel_uncertainty": "mean",
        "rate": "mean"
    }).reset_index()

    # For WHO-GBD divergence, we need WHO data; here we use only GBD components
    # So compute a partial score: standardised rel_uncertainty
    avg["rel_unc_std"] = (avg["rel_uncertainty"] - avg["rel_uncertainty"].mean()) / avg["rel_uncertainty"].std()
    avg["score"] = avg["rel_unc_std"]

    if gdp_per_capita is not None:
        gdp = pd.DataFrame({"country": gdp_per_capita.index, "gdp": gdp_per_capita.values})
        avg = avg.merge(gdp, on="country")
        log_gdp = np.log(avg["gdp"])
        X = sm.add_constant(log_gdp)
        model = sm.OLS(avg["score"], X, missing="drop").fit()
        resid = avg["score"] - model.predict(X)
        # Studentise manually
        h = X.values @ np.linalg.inv(X.T.values @ X.values) @ X.T.values
        h_diag = np.diag(h)
        mse = np.sum(model.resid ** 2) / model.df_resid
        se_resid = np.sqrt(mse * (1 - h_diag))
        avg["dodji"] = resid / se_resid
    else:
        avg["dodji"] = avg["score"]

    return avg.set_index("country")["dodji"]


def compute_full_dodji(gbd_components, who_components, gdp_per_capita):
    """
    Compute full DODJI using GBD uncertainty and WHO-GBD divergence.
    Need annual WHO rates matched to GBD rates.
    """
    # For each country-year, compute divergence
    merged = gbd_components.merge(who_components[["country", "year", "ASDR"]], on=["country", "year"], how="inner")
    merged["who_gbd_divergence"] = np.abs(merged["rate"] - merged["ASDR"])

    # Average over years
    avg = merged.groupby("country").agg({
        "rel_uncertainty": "mean",
        "who_gbd_divergence": "mean"
    }).reset_index()

    # Standardise components
    avg["rel_unc_std"] = (avg["rel_uncertainty"] - avg["rel_uncertainty"].mean()) / avg["rel_uncertainty"].std()
    avg["div_std"] = (avg["who_gbd_divergence"] - avg["who_gbd_divergence"].mean()) / avg["who_gbd_divergence"].std()
    avg["score"] = avg["rel_unc_std"] + avg["div_std"]

    # GDP residualise
    gdp = pd.DataFrame({"country": gdp_per_capita.index, "gdp": gdp_per_capita.values})
    avg = avg.merge(gdp, on="country")
    log_gdp = np.log(avg["gdp"])
    X = sm.add_constant(log_gdp)
    model = sm.OLS(avg["score"], X, missing="drop").fit()
    resid = avg["score"] - model.predict(X)
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
    """Compare primary DODJI with alternative."""
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
    # Load DODJI table and GDP per capita from mechanism variables
    dodji = pd.read_csv(DODJI_CSV)
    mech = pd.read_csv(DODJI_DIR / "mechanism_variables_47countries.csv")
    gdp_per_capita = mech.set_index("country")["wb_gdp_per_capita"]

    primary_dodji = dodji.set_index("country")["dodji_score"]

    # Load GBD and WHO
    gbd = load_gbd()
    who = load_who()

    # Build components
    gbd_all_drug = compute_dodji_components(gbd, cause="Drug use disorders", age="Age-standardized", metric="Rate")
    gbd_opioid = compute_dodji_components(gbd, cause="Opioid use disorders", age="Age-standardized", metric="Rate")
    gbd_all_ages = compute_dodji_components(gbd, cause="Drug use disorders", age="All ages", metric="Rate")
    gbd_number = compute_dodji_components(gbd, cause="Drug use disorders", age="Age-standardized", metric="Number")

    # Compute alternative DODJIs
    dodji_all_drug = compute_dodji_score(gbd_all_drug, gdp_per_capita)
    dodji_opioid = compute_dodji_score(gbd_opioid, gdp_per_capita)
    dodji_all_ages = compute_dodji_score(gbd_all_ages, gdp_per_capita)

    # Full DODJI with WHO divergence (WHO has 37 European countries)
    who_components = who[["country", "year", "ASDR"]].copy()
    who_components.columns = ["country", "year", "ASDR"]
    dodji_full_who = compute_full_dodji(gbd_all_drug, who_components, gdp_per_capita)

    # Robustness checks
    checks = []
    checks.append(robustness_summary(primary_dodji, dodji_all_drug, "Primary vs GBD all-drug age-standardised rate"))
    checks.append(robustness_summary(primary_dodji, dodji_opioid, "Primary vs GBD opioid-only age-standardised rate"))
    checks.append(robustness_summary(primary_dodji, dodji_all_ages, "Primary vs GBD all-drug all-ages rate"))
    if not dodji_full_who.empty:
        checks.append(robustness_summary(primary_dodji, dodji_full_who, "Primary vs GBD+WHO divergence (European subset)"))

    robust_summary = pd.DataFrame(checks)
    robust_summary.to_csv(OUTPUT_DIR / "gbd_robustness_summary.csv", index=False)
    print("\n=== GBD robustness summary ===")
    print(robust_summary)

    # Cross-source summary
    cross_source = pd.DataFrame({
        "country": dodji_full_who.index,
        "primary_dodji": primary_dodji[dodji_full_who.index],
        "who_gbd_dodji": dodji_full_who.values,
    })
    cross_source.to_csv(OUTPUT_DIR / "who_gbd_cross_source_dodji.csv", index=False)

    rho_who, pval_who = stats.spearmanr(cross_source["primary_dodji"], cross_source["who_gbd_dodji"])
    who_summary = pd.DataFrame({
        "check": ["WHO-GBD divergence variant (37 European countries)"],
        "n": [len(cross_source)],
        "spearman_rho": [round(rho_who, 3)],
        "spearman_p": [round(pval_who, 4)],
    })
    who_summary.to_csv(OUTPUT_DIR / "who_gbd_cross_source_summary.csv", index=False)
    print("\n=== WHO cross-source summary ===")
    print(who_summary)

    # Predictive validation: annual DODJI predicting mortality change
    # Build annual panel using GBD all-drug age-standardised rates
    panel = gbd_all_drug.copy()
    panel["log_rate"] = np.log(panel["rate"].replace(0, np.nan))

    # Compute annual DODJI by year (no GDP residualisation for simplicity; could add)
    # Use rolling 5-year windows for stability
    annual_dodji = []
    years = sorted(panel["year"].unique())
    for country in panel["country"].unique():
        country_data = panel[panel["country"] == country].sort_values("year").set_index("year")
        for yr in years:
            window = country_data.loc[yr-4:yr, "rel_uncertainty"]
            if len(window) >= 3:
                annual_dodji.append({
                    "country": country,
                    "year": yr,
                    "dodji_annual": (window.mean() - panel["rel_uncertainty"].mean()) / panel["rel_uncertainty"].std()
                })
    annual_dodji = pd.DataFrame(annual_dodji)

    # Build outcomes: 3-year mortality change
    outcomes = []
    for country in panel["country"].unique():
        cd = panel[panel["country"] == country].sort_values("year").set_index("year")
        for yr in years:
            if yr + 3 in cd.index and yr in cd.index:
                outcomes.append({
                    "country": country,
                    "year": yr,
                    "mortality_rate_t": cd.loc[yr, "rate"],
                    "mortality_rate_t3": cd.loc[yr+3, "rate"],
                    "log_change_t3": np.log(cd.loc[yr+3, "rate"] + 1e-6) - np.log(cd.loc[yr, "rate"] + 1e-6),
                    "rank_t": cd.loc[yr, "rate"],
                    "rank_t3": cd.loc[yr+3, "rate"],
                })
    outcomes = pd.DataFrame(outcomes)

    pred_data = annual_dodji.merge(outcomes, on=["country", "year"], how="inner")

    # Models
    pred_results = []

    # Log change ~ DODJI
    valid = pred_data.dropna(subset=["dodji_annual", "log_change_t3"])
    if len(valid) > 10:
        X = sm.add_constant(valid["dodji_annual"])
        y = valid["log_change_t3"]
        model = sm.OLS(y, X, missing="drop").fit()
        pred_results.append({
            "outcome": "log_mortality_change_t_to_t3",
            "predictor": "dodji_annual",
            "n": int(model.nobs),
            "beta": round(model.params["dodji_annual"], 4),
            "se": round(model.bse["dodji_annual"], 4),
            "p": round(model.pvalues["dodji_annual"], 4),
            "r2": round(model.rsquared, 3),
        })

    # Rate change ~ DODJI
    valid2 = pred_data.dropna(subset=["dodji_annual", "mortality_rate_t", "mortality_rate_t3"])
    if len(valid2) > 10:
        valid2["rate_change"] = valid2["mortality_rate_t3"] - valid2["mortality_rate_t"]
        X2 = sm.add_constant(valid2["dodji_annual"])
        y2 = valid2["rate_change"]
        model2 = sm.OLS(y2, X2, missing="drop").fit()
        pred_results.append({
            "outcome": "mortality_rate_change_t_to_t3",
            "predictor": "dodji_annual",
            "n": int(model2.nobs),
            "beta": round(model2.params["dodji_annual"], 4),
            "se": round(model2.bse["dodji_annual"], 4),
            "p": round(model2.pvalues["dodji_annual"], 4),
            "r2": round(model2.rsquared, 3),
        })

    pred_df = pd.DataFrame(pred_results)
    pred_df.to_csv(OUTPUT_DIR / "predictive_validation_results.csv", index=False)
    print("\n=== Predictive validation ===")
    print(pred_df)

    # Save annual panel
    pred_data.to_csv(OUTPUT_DIR / "annual_dodji_panel.csv", index=False)
    print(f"\nSaved {OUTPUT_DIR / 'annual_dodji_panel.csv'}")


if __name__ == "__main__":
    main()
