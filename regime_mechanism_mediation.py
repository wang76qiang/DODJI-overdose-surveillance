"""
regime_mechanism_mediation.py

Analyse whether DODJI regimes differ on institutional / forensic / governance
mechanism variables and test regime-level mediation (P0a).

Inputs:
    - results_v17/reclassification_table_v17.csv
    - results_v17/mechanism_variables_47countries.csv (from collect_mechanism_variables.py)

Outputs:
    - results_v17/regime_mechanism_table.csv
    - results_v17/regime_mediation_results.csv
    - console/stdout summary
"""

from pathlib import Path
import pandas as pd
import numpy as np
from scipy import stats
import statsmodels.api as sm
import statsmodels.formula.api as smf

ROOT = Path(__file__).resolve().parent
RESULTS_DIR = ROOT / "results_v17"
DODJI_CSV = RESULTS_DIR / "reclassification_table_v17.csv"
MECH_CSV = RESULTS_DIR / "mechanism_variables_47countries.csv"
OUTPUT_REGIME = RESULTS_DIR / "regime_mechanism_table.csv"
OUTPUT_MEDIATION = RESULTS_DIR / "regime_mediation_results.csv"


def load_data():
    dodji = pd.read_csv(DODJI_CSV)
    mech = pd.read_csv(MECH_CSV)
    df = dodji.merge(mech, on="country", how="left")
    return df


def regime_mechanism_table(df):
    """Mean ± SD of each mechanism variable by DODJI regime."""
    mechanism_cols = [
        "who_ill_defined_pct",
        "who_cod_completeness_pct",
        "who_civil_reg_death_pct",
        "who_forensic_alcohol_monitor",
        "who_forensic_drug_monitor",
        "wb_gdp_per_capita",
        "wb_population",
        "wb_life_expectancy",
        "wb_comm_disease_death_pct",
    ]
    rows = []
    for regime, g in df.groupby("typology"):
        row = {"regime": regime, "n": len(g)}
        for col in mechanism_cols:
            vals = g[col].dropna()
            row[f"{col}_mean"] = round(vals.mean(), 3) if len(vals) > 0 else np.nan
            row[f"{col}_sd"] = round(vals.std(), 3) if len(vals) > 1 else np.nan
            row[f"{col}_n"] = int(vals.notna().sum())
        rows.append(row)
    return pd.DataFrame(rows)


def test_regime_differences(df):
    """ANOVA / Kruskal-Wallis tests for each mechanism variable across regimes."""
    mechanism_cols = [
        "who_ill_defined_pct",
        "who_cod_completeness_pct",
        "who_civil_reg_death_pct",
        "who_forensic_alcohol_monitor",
        "who_forensic_drug_monitor",
        "wb_gdp_per_capita",
        "wb_population",
        "wb_life_expectancy",
        "wb_comm_disease_death_pct",
    ]
    results = []
    for col in mechanism_cols:
        groups = [g[col].dropna().values for _, g in df.groupby("typology")]
        groups = [g for g in groups if len(g) > 0]
        if len(groups) < 2:
            continue
        h, p = stats.kruskal(*groups)
        results.append({
            "variable": col,
            "kruskal_h": round(h, 3),
            "p_value": round(p, 4),
            "n_groups": len(groups),
        })
    return pd.DataFrame(results)


def mediation_regression(df):
    """
    Test: mechanism variables predict DODJI within each regime.
    Because DODJI is already GDP-residualised, we focus on non-GDP mechanisms.
    """
    predictors = [
        "who_ill_defined_pct",
        "who_cod_completeness_pct",
        "who_civil_reg_death_pct",
        "who_forensic_drug_monitor",
        "wb_life_expectancy",
        "wb_comm_disease_death_pct",
    ]
    available = [p for p in predictors if p in df.columns and df[p].notna().sum() >= 10]
    if not available:
        return pd.DataFrame()

    formula = "dodji_score ~ " + " + ".join(available) + " + C(typology)"
    model = smf.ols(formula, data=df, missing="drop").fit()

    rows = []
    raw_pvalues = []
    for var in available:
        rows.append({
            "predictor": var,
            "beta": round(model.params[var], 4),
            "se": round(model.bse[var], 4),
            "p_value": round(model.pvalues[var], 4),
        })
        raw_pvalues.append(model.pvalues[var])

    # Multiple-testing correction (Benjamini-Hochberg)
    raw_pvalues = np.array(raw_pvalues)
    sorted_idx = np.argsort(raw_pvalues)
    bh_pvalues = np.zeros_like(raw_pvalues)
    n = len(raw_pvalues)
    for i, idx in enumerate(sorted_idx):
        bh_pvalues[idx] = min(raw_pvalues[idx] * n / (i + 1), 1.0)
    for i in range(n - 2, -1, -1):
        bh_pvalues[sorted_idx[i]] = min(bh_pvalues[sorted_idx[i]], bh_pvalues[sorted_idx[i + 1]])

    for i, var in enumerate(available):
        rows[i]["p_value_bh"] = round(bh_pvalues[i], 4)

    rows.append({
        "predictor": "model_r2",
        "beta": round(model.rsquared, 3),
        "se": np.nan,
        "p_value": np.nan,
        "p_value_bh": np.nan,
    })
    return pd.DataFrame(rows)


def main():
    try:
        df = load_data()
    except FileNotFoundError as e:
        print(e)
        print("\nRun collect_mechanism_variables.py first to produce mechanism data.")
        return

    print("=== Regime mechanism summary ===")
    regime_table = regime_mechanism_table(df)
    regime_table.to_csv(OUTPUT_REGIME, index=False)
    print(regime_table)

    print("\n=== Kruskal-Wallis tests across regimes ===")
    tests = test_regime_differences(df)
    print(tests)

    print("\n=== Mechanism mediation of DODJI ===")
    mediation = mediation_regression(df)
    if not mediation.empty:
        mediation.to_csv(OUTPUT_MEDIATION, index=False)
        print(mediation)
    else:
        print("Insufficient mechanism data for mediation model.")

    print(f"\nSaved {OUTPUT_REGIME} and {OUTPUT_MEDIATION}")


if __name__ == "__main__":
    main()
