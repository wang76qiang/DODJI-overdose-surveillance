"""
non_gbd_dodji_variant.py

P0b robustness: construct a DODJI-like index using only non-GBD surveillance
proxies from WHO GHO and World Bank WDI, and compare it with the primary
GBD-based DODJI.

Inputs:
    - results_v17/reclassification_table_v17.csv
    - results_v17/mechanism_variables_47countries.csv

Outputs:
    - results_v17/non_gbd_dodji_variant.csv
    - results_v17/non_gbd_robustness_summary.csv
"""

from pathlib import Path
import pandas as pd
import numpy as np
from scipy import stats

ROOT = Path(__file__).resolve().parent
RESULTS_DIR = ROOT / "results_v17"
DODJI_CSV = RESULTS_DIR / "reclassification_table_v17.csv"
MECH_CSV = RESULTS_DIR / "mechanism_variables_47countries.csv"
OUTPUT_CSV = RESULTS_DIR / "non_gbd_dodji_variant.csv"
OUTPUT_SUMMARY = RESULTS_DIR / "non_gbd_robustness_summary.csv"


def main():
    dodji = pd.read_csv(DODJI_CSV)
    mech = pd.read_csv(MECH_CSV)
    df = dodji.merge(mech, on="country", how="left")

    # Build non-GBD surveillance quality score
    # Higher values = worse surveillance quality
    # ill-defined causes (%): higher is worse
    # COD completeness (%): lower is worse -> reverse
    # civil registration of deaths (%): lower is worse -> reverse
    df["ill_defined_std"] = (df["who_ill_defined_pct"] - df["who_ill_defined_pct"].mean()) / df["who_ill_defined_pct"].std()
    df["cod_complete_rev"] = 100 - df["who_cod_completeness_pct"]
    df["cod_complete_rev_std"] = (df["cod_complete_rev"] - df["cod_complete_rev"].mean()) / df["cod_complete_rev"].std()
    df["civil_reg_rev"] = 100 - df["who_civil_reg_death_pct"]
    df["civil_reg_rev_std"] = (df["civil_reg_rev"] - df["civil_reg_rev"].mean()) / df["civil_reg_rev"].std()

    # Composite quality score (simple average of standardised components)
    quality_components = ["ill_defined_std", "cod_complete_rev_std", "civil_reg_rev_std"]
    df["quality_score"] = df[quality_components].mean(axis=1, skipna=True)

    # GDP-residualise (studentised residual)
    valid = df.dropna(subset=["quality_score", "wb_gdp_per_capita"])
    log_gdp = np.log(valid["wb_gdp_per_capita"])
    X = np.column_stack([np.ones(len(valid)), log_gdp])
    y = valid["quality_score"].values
    beta = np.linalg.lstsq(X, y, rcond=None)[0]
    fitted = X @ beta
    resid = y - fitted
    mse = np.sum(resid ** 2) / (len(resid) - 2)
    se_resid = np.sqrt(mse * (1 - 1 / len(resid) - (log_gdp - log_gdp.mean()) ** 2 / np.sum((log_gdp - log_gdp.mean()) ** 2)))
    se_resid = np.clip(se_resid, np.finfo(float).eps, None)
    non_gbd_dodji = resid / se_resid

    valid = valid.copy()
    valid["non_gbd_dodji"] = non_gbd_dodji

    # Merge back
    df = df.merge(valid[["country", "non_gbd_dodji"]], on="country", how="left")

    # Compare with primary DODJI
    valid_full = df.dropna(subset=["dodji_score", "non_gbd_dodji"])
    rho, pval = stats.spearmanr(valid_full["dodji_score"], valid_full["non_gbd_dodji"])

    # Regime stability (use same quartile method as primary)
    for col in ["dodji_score", "non_gbd_dodji"]:
        q = np.nanquantile(df[col], [0.25, 0.5, 0.75])
        regimes = pd.Series(index=df.index, dtype=object)
        regimes[df[col] <= q[0]] = "Medical-system-driven"
        regimes[(df[col] > q[0]) & (df[col] <= q[1])] = "Low-burden / protected"
        regimes[(df[col] > q[1]) & (df[col] <= q[2])] = "Data-quality-limited"
        regimes[df[col] > q[2]] = "Insufficient exposure data"
        df[f"{col}_regime"] = regimes

    regime_match = df.dropna(subset=["dodji_score_regime", "non_gbd_dodji_regime"])
    stability = np.mean(regime_match["dodji_score_regime"] == regime_match["non_gbd_dodji_regime"])

    # Priority-I set stability (top 10 by combined priority score not available for non-GBD; use top 10 by non-GBD DODJI)
    primary_top10 = set(df.nsmallest(10, "dodji_score")["country"])
    non_gbd_top10 = set(df.nsmallest(10, "non_gbd_dodji")["country"])
    jaccard = len(primary_top10 & non_gbd_top10) / len(primary_top10 | non_gbd_top10)

    summary = pd.DataFrame({
        "check": ["Non-GBD WHO-GHO/WB DODJI variant"],
        "n_countries": [len(valid_full)],
        "spearman_rho": [round(rho, 3)],
        "spearman_p": [round(pval, 4)],
        "regime_stability": [round(stability, 3)],
        "top10_jaccard": [round(jaccard, 3)],
    })

    df.to_csv(OUTPUT_CSV, index=False)
    summary.to_csv(OUTPUT_SUMMARY, index=False)

    print(f"Saved {OUTPUT_CSV}")
    print(f"Saved {OUTPUT_SUMMARY}")
    print(summary.T)


if __name__ == "__main__":
    main()
