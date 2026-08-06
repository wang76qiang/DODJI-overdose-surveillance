"""
gbd_robustness_checks.py

Framework for P0b: test whether DODJI regime classification and priority rankings
are robust to alternative GBD modelling choices and input data sources.

Required inputs (not in repo; download separately):
    1. GBD 2021 country-year estimates for drug-use disorders / overdose mortality
       (IHME GBD Results Tool, http://ghdx.healthdata.org/gbd-results-tool)
    2. GBD 2019 country estimates for the same causes (for cross-version check)
    3. WHO Mortality Database detailed mortality data by ICD-10 codes
       (https://platform.who.int/mortality/countries/country-detail)
    4. WHO Global Health Estimates cause-of-death envelopes (optional)

Output:
    results_v17/gbd_robustness_summary.csv
    results_v17/gbd_robustness_regime_stability.csv
"""

from pathlib import Path
import pandas as pd
import numpy as np
from scipy import stats

ROOT = Path(__file__).resolve().parent
RESULTS_DIR = ROOT / "results_v17"
INPUT_CSV = RESULTS_DIR / "reclassification_table_v17.csv"
OUTPUT_SUMMARY = RESULTS_DIR / "gbd_robustness_summary.csv"
OUTPUT_STABILITY = RESULTS_DIR / "gbd_robustness_regime_stability.csv"


def compute_dodji_component(mortality_rate, upper_ui, lower_ui, who_estimate=None):
    """
    Compute a simplified DODJI-like score from GBD uncertainty and WHO-GBD divergence.
    This is a placeholder; the actual DODJI uses GDP-residualised studentised residuals.
    """
    uncertainty_width = upper_ui - lower_ui
    if who_estimate is not None and who_estimate > 0:
        divergence = abs(mortality_rate - who_estimate) / who_estimate
    else:
        divergence = 0.0
    # Studentised residual placeholder: rank normalise both components and sum
    z_unc = stats.zscore(uncertainty_width, nan_policy="omit")
    z_div = stats.zscore(divergence, nan_policy="omit")
    return z_unc + z_div


def load_gbd_2021():
    """Load GBD 2021 country estimates. Placeholder."""
    path = RESULTS_DIR / "gbd_2021_overdose_estimates.csv"
    if not path.exists():
        raise FileNotFoundError(
            f"{path} not found. Download GBD 2021 country results from IHME."
        )
    return pd.read_csv(path)


def load_gbd_2019():
    """Load GBD 2019 country estimates. Placeholder."""
    path = RESULTS_DIR / "gbd_2019_overdose_estimates.csv"
    if not path.exists():
        raise FileNotFoundError(
            f"{path} not found. Download GBD 2019 country results from IHME."
        )
    return pd.read_csv(path)


def load_who_mortality():
    """Load WHO Mortality Database ICD-10 overdose deaths. Placeholder."""
    path = RESULTS_DIR / "who_mortality_overdose_x40x44_x60x64_x85_y10y14.csv"
    if not path.exists():
        raise FileNotFoundError(
            f"{path} not found. Download WHO Mortality Database detailed data."
        )
    return pd.read_csv(path)


def classify_regime(dodji):
    """Map continuous DODJI to the four YX1/YX2 regimes."""
    # Placeholder thresholds; should match the classification used in the manuscript.
    q = np.nanquantile(dodji, [0.25, 0.5, 0.75])
    regimes = pd.Series(index=dodji.index, dtype=object)
    regimes[dodji <= q[0]] = "Medical-system-driven"
    regimes[(dodji > q[0]) & (dodji <= q[1])] = "Low-burden / protected"
    regimes[(dodji > q[1]) & (dodji <= q[2])] = "Data-quality-limited"
    regimes[dodji > q[2]] = "Insufficient exposure data"
    return regimes


def robustness_check_primary_vs_alternative(primary, alternative, label):
    """Compare primary DODJI with an alternative specification."""
    merged = primary.merge(alternative, on="country", suffixes=("_primary", "_alt"))
    rho, pval = stats.spearmanr(
        merged["dodji_primary"], merged["dodji_alt"], nan_policy="omit"
    )
    regime_primary = classify_regime(merged["dodji_primary"])
    regime_alt = classify_regime(merged["dodji_alt"])
    stability = np.mean(regime_primary == regime_alt)
    priority_primary = set(merged.loc[merged["priority_primary"] == "Priority I", "country"])
    priority_alt = set(merged.loc[merged["priority_alt"] == "Priority I", "country"])
    priority_jaccard = len(priority_primary & priority_alt) / len(priority_primary | priority_alt)
    return {
        "check": label,
        "spearman_rho": round(rho, 3),
        "spearman_p": round(pval, 4),
        "regime_stability": round(stability, 3),
        "priority_I_jaccard": round(priority_jaccard, 3),
        "n_countries": len(merged),
    }


def main():
    primary = pd.read_csv(INPUT_CSV)
    primary = primary[["country", "dodji_score", "priority_label", "typology"]].rename(
        columns={"dodji_score": "dodji_primary", "priority_label": "priority_primary", "typology": "regime_primary"}
    )

    # Placeholder: when GBD data files are available, uncomment and run each check.
    checks = []

    # 1. Cross-version: GBD 2021 vs GBD 2019
    # gbd19 = load_gbd_2019()
    # checks.append(robustness_check_primary_vs_alternative(primary, gbd19, "GBD 2019 vs GBD 2021"))

    # 2. Cause composition: opioid-only vs all-drug
    # gbd_opioid = load_gbd_2021_opioid_only()
    # checks.append(robustness_check_primary_vs_alternative(primary, gbd_opioid, "Opioid-only vs all-drug"))

    # 3. WHO source: WHO Mortality Database vs GBD estimates
    # who_est = load_who_mortality()
    # checks.append(robustness_check_primary_vs_alternative(primary, who_est, "WHO Mortality Database vs GBD"))

    # 4. Uncertainty metric: 90% UI vs 95% UI
    # gbd_90ui = load_gbd_2021_90ui()
    # checks.append(robustness_check_primary_vs_alternative(primary, gbd_90ui, "90% UI vs 95% UI"))

    if not checks:
        print("No GBD robustness data files found. Running in documentation-only mode.")
        print("Required files:")
        print("  - results_v17/gbd_2021_overdose_estimates.csv")
        print("  - results_v17/gbd_2019_overdose_estimates.csv")
        print("  - results_v17/who_mortality_overdose_x40x44_x60x64_x85_y10y14.csv")
        print("\nOnce files are available, uncomment the check blocks and rerun.")
        return

    summary = pd.DataFrame(checks)
    summary.to_csv(OUTPUT_SUMMARY, index=False)
    print(f"Saved {OUTPUT_SUMMARY}")
    print(summary)


if __name__ == "__main__":
    main()
