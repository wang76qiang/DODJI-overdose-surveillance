"""
perturbation_robustness.py

Internal sensitivity analysis: perturb DODJI scores with random noise proportional
to a plausible uncertainty range and measure stability of regime classification and
Priority-I set. This is a placeholder for the more comprehensive GBD cross-version/
cross-input robustness checks (P0b) that require additional GBD/WHO downloads.

Inputs:
    - results_v17/reclassification_table_v17.csv

Outputs:
    - results_v17/perturbation_robustness_summary.csv
"""

from pathlib import Path
import pandas as pd
import numpy as np
from scipy import stats

ROOT = Path(__file__).resolve().parent
RESULTS_DIR = ROOT / "results_v17"
INPUT_CSV = RESULTS_DIR / "reclassification_table_v17.csv"
OUTPUT_CSV = RESULTS_DIR / "perturbation_robustness_summary.csv"


def classify_regime(dodji):
    """Map continuous DODJI to four regimes using quartile thresholds."""
    q = np.nanquantile(dodji, [0.25, 0.5, 0.75])
    regimes = pd.Series(index=dodji.index, dtype=object)
    regimes[dodji <= q[0]] = "Medical-system-driven"
    regimes[(dodji > q[0]) & (dodji <= q[1])] = "Low-burden / protected"
    regimes[(dodji > q[1]) & (dodji <= q[2])] = "Data-quality-limited"
    regimes[dodji > q[2]] = "Insufficient exposure data"
    return regimes


def main():
    df = pd.read_csv(INPUT_CSV)
    primary = df[["country", "dodji_score", "priority_label", "typology"]].copy()
    primary["regime_primary"] = classify_regime(primary["dodji_score"])

    # Plausible DODJI uncertainty: assume SD = 0.5 units (roughly half the interquartile range)
    noise_sd = 0.5
    n_sims = 1000

    stability = []
    priority_jaccard = []
    rank_correlations = []

    rng = np.random.default_rng(42)

    for _ in range(n_sims):
        perturbed = primary["dodji_score"] + rng.normal(0, noise_sd, size=len(primary))
        regime_alt = classify_regime(perturbed)
        stability.append(np.mean(primary["regime_primary"] == regime_alt))

        priority_alt = set(primary.loc[perturbed.rank(ascending=False) <= 10, "country"])
        priority_primary = set(primary.loc[primary["priority_label"] == "Priority I", "country"])
        jaccard = len(priority_primary & priority_alt) / len(priority_primary | priority_alt)
        priority_jaccard.append(jaccard)

        rho, _ = stats.spearmanr(primary["dodji_score"], perturbed)
        rank_correlations.append(rho)

    summary = pd.DataFrame({
        "check": ["DODJI score perturbation (SD=0.5, n=1000)"],
        "regime_stability_mean": [round(np.mean(stability), 3)],
        "regime_stability_95ci_low": [round(np.quantile(stability, 0.025), 3)],
        "regime_stability_95ci_high": [round(np.quantile(stability, 0.975), 3)],
        "priority_I_jaccard_mean": [round(np.mean(priority_jaccard), 3)],
        "priority_I_jaccard_95ci_low": [round(np.quantile(priority_jaccard, 0.025), 3)],
        "priority_I_jaccard_95ci_high": [round(np.quantile(priority_jaccard, 0.975), 3)],
        "spearman_rho_mean": [round(np.mean(rank_correlations), 3)],
        "spearman_rho_95ci_low": [round(np.quantile(rank_correlations, 0.025), 3)],
        "spearman_rho_95ci_high": [round(np.quantile(rank_correlations, 0.975), 3)],
    })

    summary.to_csv(OUTPUT_CSV, index=False)
    print(f"Saved {OUTPUT_CSV}")
    print(summary.T)


if __name__ == "__main__":
    main()
