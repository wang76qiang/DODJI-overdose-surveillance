"""
build_v18_derived.py

Downstream recomputation for the v18 explicit classification:
  1. Table-2 regime x mechanism aggregates (regime_mechanism_table_v18.csv)
  2. Mechanism regression with v18 regime fixed effects
     (dodji_score ~ 6 mechanism predictors + C(typology); OLS, listwise;
     Benjamini-Hochberg across the six tests) -> regime_mediation_results_v18.csv
  3. Robustness stability checks (robustness_stability_v18.csv) for variants
     with deposited per-country scores: extended age bands (n=37), WHO-GBD
     cross-source (n=30), non-GBD WHO-GHO/WB (n=47). Within each variant
     subset, regimes and priority tiers are re-derived with the SAME explicit
     v18 rules (primary mortality ranks; variant DODJI percentile for S).
  4. Perturbation analysis (perturbation_robustness_summary_v18.csv):
     DODJI + N(0, 0.5), 1000 simulations, same v18 rules.
"""

from pathlib import Path
import json

import numpy as np
import pandas as pd
import statsmodels.formula.api as smf

from build_reclassification_v18 import (classify_regime, priority_from_scores,
                                        REGIMES)

ROOT = Path(__file__).resolve().parent
R17 = ROOT / "results_v17"
R18 = ROOT / "results_v18"

MECH_COLS = ["who_ill_defined_pct", "who_cod_completeness_pct",
             "who_civil_reg_death_pct", "who_forensic_drug_monitor",
             "wb_gdp_per_capita", "wb_life_expectancy",
             "wb_comm_disease_death_pct"]

PREDICTORS = ["who_ill_defined_pct", "who_cod_completeness_pct",
              "who_civil_reg_death_pct", "who_forensic_drug_monitor",
              "wb_life_expectancy", "wb_comm_disease_death_pct"]


def load_v18():
    df = pd.read_csv(R18 / "reclassification_table_v18.csv")
    mech = pd.read_csv(R17 / "mechanism_variables_47countries.csv")
    return df.merge(mech, on="country", how="left")


def regime_mechanism_table(df):
    rows = []
    for regime, g in df.groupby("typology"):
        row = {"regime": regime, "n": len(g)}
        for col in MECH_COLS:
            row[f"{col}_mean"] = round(g[col].mean(), 2)
            row[f"{col}_n"] = int(g[col].notna().sum())
        rows.append(row)
    out = pd.DataFrame(rows).set_index("regime").reindex(REGIMES).reset_index()
    out.to_csv(R18 / "regime_mechanism_table_v18.csv", index=False)
    return out


def mediation_regression(df):
    available = [p for p in PREDICTORS
                 if p in df.columns and df[p].notna().sum() >= 10]
    formula = "dodji_score ~ " + " + ".join(available) + " + C(typology)"
    model = smf.ols(formula, data=df, missing="drop").fit()
    rows, raw_p = [], []
    for var in available:
        rows.append({"predictor": var, "beta": round(model.params[var], 4),
                     "se": round(model.bse[var], 4),
                     "p_value": round(model.pvalues[var], 4)})
        raw_p.append(model.pvalues[var])
    # Benjamini-Hochberg
    raw_p = np.array(raw_p)
    order = np.argsort(raw_p)
    bh = np.zeros_like(raw_p)
    n = len(raw_p)
    for i, idx in enumerate(order):
        bh[idx] = min(raw_p[idx] * n / (i + 1), 1.0)
    for i in range(n - 2, -1, -1):
        bh[order[i]] = min(bh[order[i]], bh[order[i + 1]])
    for i, var in enumerate(available):
        rows[i]["p_bh"] = round(bh[i], 4)
    out = pd.DataFrame(rows)
    out.attrs["r2"] = round(model.rsquared, 3)
    out.attrs["n_obs"] = int(model.nobs)
    out.to_csv(R18 / "regime_mediation_results_v18.csv", index=False)
    return out


def stability_for_variant(primary, variant, vcol, label):
    """Re-derive regimes and Priority-I sets within the variant subset using
    the explicit v18 rules (primary mortality ranks, variant DODJI)."""
    m = primary.merge(variant[["country", vcol]], on="country").dropna(
        subset=[vcol])
    n = len(m)
    reg_p = classify_regime(m["mortality_rank"], m["dodji_score"])
    reg_v = classify_regime(m["mortality_rank"], m[vcol])
    stability = float(np.mean(reg_p.values == reg_v.values))

    pr_p = priority_from_scores(m["mortality_rank"], m["dodji_score"])
    pr_v = priority_from_scores(m["mortality_rank"], m[vcol])
    k = int(np.ceil(n / 4))  # top quartile = Priority I within subset
    top_p = set(m.loc[pr_p.index[:k], "country"])
    top_v = set(m.loc[pr_v.index[:k], "country"])
    jaccard = len(top_p & top_v) / len(top_p | top_v)

    from scipy import stats
    rho, p = stats.spearmanr(m["dodji_score"], m[vcol])
    return {"check": label, "n": n, "spearman_rho": round(rho, 3),
            "spearman_p": round(p, 4), "regime_stability": round(stability, 3),
            "priority_I_jaccard": round(jaccard, 3)}


def robustness_stability(df):
    primary = df[["country", "mortality_rank", "dodji_score"]]
    rows = []
    age = pd.read_csv(R17 / "gbd2021_ageband_country_scores.csv")
    for band in ["15-49 years", "15-64 years", "65+ years"]:
        rows.append(stability_for_variant(
            primary, age[["country", band]], band,
            f"Primary vs {band} age-standardised (extended set)"))
    cross = pd.read_csv(R17 / "who_gbd_cross_source_dodji.csv")
    rows.append(stability_for_variant(
        primary, cross[["country", "who_gbd_dodji"]], "who_gbd_dodji",
        "Primary vs GBD+WHO divergence (European subset)"))
    nongbd = pd.read_csv(R17 / "non_gbd_dodji_variant.csv")[
        ["country", "non_gbd_dodji"]]
    rows.append(stability_for_variant(
        primary, nongbd, "non_gbd_dodji",
        "Non-GBD WHO-GHO/WB DODJI variant"))
    out = pd.DataFrame(rows)
    out.to_csv(R18 / "robustness_stability_v18.csv", index=False)
    return out


def perturbation(df, n_sims=1000, sd=0.5, seed=20240807):
    rng = np.random.default_rng(seed)
    primary = df[["country", "mortality_rank", "dodji_score"]]
    reg_p = classify_regime(primary["mortality_rank"], primary["dodji_score"])
    pr_p = priority_from_scores(primary["mortality_rank"],
                                primary["dodji_score"])
    top_p = set(primary.loc[pr_p.index[:12], "country"])
    stab, jac, rhos = [], [], []
    from scipy import stats
    d = primary["dodji_score"].values
    for _ in range(n_sims):
        pert = d + rng.normal(0, sd, len(d))
        reg_v = classify_regime(primary["mortality_rank"], pert)
        stab.append(np.mean(reg_p.values == reg_v.values))
        pr_v = priority_from_scores(primary["mortality_rank"], pert)
        top_v = set(primary.loc[pr_v.index[:12], "country"])
        jac.append(len(top_p & top_v) / len(top_p | top_v))
        rhos.append(stats.spearmanr(d, pert)[0])
    out = pd.DataFrame({
        "check": ["DODJI score perturbation (SD=0.5, n=1000)"],
        "spearman_rho_mean": [round(np.mean(rhos), 3)],
        "spearman_rho_95ci_low": [round(np.quantile(rhos, 0.025), 3)],
        "spearman_rho_95ci_high": [round(np.quantile(rhos, 0.975), 3)],
        "regime_stability_mean": [round(np.mean(stab), 3)],
        "regime_stability_95ci_low": [round(np.quantile(stab, 0.025), 3)],
        "regime_stability_95ci_high": [round(np.quantile(stab, 0.975), 3)],
        "priority_I_jaccard_mean": [round(np.mean(jac), 3)],
        "priority_I_jaccard_95ci_low": [round(np.quantile(jac, 0.025), 3)],
        "priority_I_jaccard_95ci_high": [round(np.quantile(jac, 0.975), 3)],
    })
    out.to_csv(R18 / "perturbation_robustness_summary_v18.csv", index=False)
    return out


def main():
    df = load_v18()
    t2 = regime_mechanism_table(df)
    print("== Table 2 aggregates ==\n", t2.to_string(index=False))
    med = mediation_regression(df)
    print("\n== Mechanism regression (v18 regimes) ==\n", med.to_string(index=False))
    print("R2:", med.attrs["r2"], " n:", med.attrs["n_obs"])
    stab = robustness_stability(df)
    print("\n== Robustness stability (v18 rules) ==\n", stab.to_string(index=False))
    pert = perturbation(df)
    print("\n== Perturbation ==\n", pert.to_string(index=False))

    # extend numbers manifest
    with open(R18 / "v18_key_numbers.json") as f:
        manifest = json.load(f)
    manifest["mechanism_regression"] = {
        "n_obs": med.attrs["n_obs"], "r2": med.attrs["r2"],
        "ill_defined": med[med["predictor"] == "who_ill_defined_pct"]
        [["beta", "se", "p_value", "p_bh"]].to_dict("records")[0]}
    manifest["robustness_stability"] = stab.to_dict("records")
    manifest["perturbation"] = pert.to_dict("records")[0]
    manifest["table2"] = t2.to_dict("records")
    with open(R18 / "v18_key_numbers.json", "w") as f:
        json.dump(manifest, f, indent=2, ensure_ascii=False)


if __name__ == "__main__":
    main()
