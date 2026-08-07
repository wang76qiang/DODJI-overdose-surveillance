"""
update_figure_data_v18.py

Regenerate all classification-dependent figure source-data CSVs from the
explicit v18 tables (results_v18/). Schemas match the v17 files exactly so
the R/ggplot and matplotlib figure scripts run unchanged.

Updated:
  figures_v21_authoritative/source_data/fig1_mortality_and_dodji_atlas.csv
  figures_v21_authoritative/source_data/fig2_priority_reordering.csv
  figures_v21_authoritative/source_data/fig3_governance_landscape.csv
  figures_v21_authoritative/source_data/mechanism_regression_results.csv
  figure_reproduction_data/Figure1_composite_data.csv
  figure_reproduction_data/Figure1b_DODJI_surveillance_credibility.csv
  figure_reproduction_data/Figure1c_priority_disagreement.csv
  figure_reproduction_data/Figure2_priority_reordering.csv
  figure_reproduction_data/Figure3_governance_landscape.csv
  figure_reproduction_data/Figure6_mechanism_regression_results.csv
"""

from pathlib import Path

import numpy as np
import pandas as pd

ROOT = Path(__file__).resolve().parent
R18 = ROOT / "results_v18"
SRC = ROOT / "figures_v21_authoritative" / "source_data"
FRD = ROOT / "figure_reproduction_data"

MICROSTATES = {"Monaco", "San Marino", "Andorra", "Iceland", "Malta",
               "Luxembourg"}


def main():
    df = pd.read_csv(R18 / "reclassification_table_v18.csv")

    atlas = df[["country", "mortality_rank", "dodji_score", "priority_score",
                "combined_priority_rank", "typology", "reclassification"]] \
        .rename(columns={"typology": "regime",
                         "reclassification": "reclassification_direction"})
    for path in [SRC / "fig1_mortality_and_dodji_atlas.csv",
                 SRC / "fig3_governance_landscape.csv",
                 FRD / "Figure1_composite_data.csv",
                 FRD / "Figure3_governance_landscape.csv"]:
        atlas.to_csv(path, index=False)

    reorder = df[["country", "mortality_rank", "combined_priority_rank",
                  "rank_shift_up", "reclassification", "typology"]] \
        .rename(columns={"rank_shift_up": "rank_shift",
                         "typology": "regime"})
    for path in [SRC / "fig2_priority_reordering.csv",
                 FRD / "Figure2_priority_reordering.csv"]:
        reorder.to_csv(path, index=False)

    f1b_old = pd.read_csv(FRD / "Figure1b_DODJI_surveillance_credibility.csv",
                          encoding="utf-8-sig")
    f1b = f1b_old[["country", "map_join_name", "is_microstate"]].merge(
        df[["country", "dodji_score", "dodji_tier", "surveillance_gap"]],
        on="country", how="left")
    f1b.to_csv(FRD / "Figure1b_DODJI_surveillance_credibility.csv",
               index=False, encoding="utf-8-sig")

    f1c_old = pd.read_csv(FRD / "Figure1c_priority_disagreement.csv",
                          encoding="utf-8-sig")
    f1c = f1c_old[["country", "map_join_name", "is_microstate"]].merge(
        df[["country", "rank_shift_up", "mortality_rank",
            "combined_priority_rank"]], on="country", how="left")
    f1c.to_csv(FRD / "Figure1c_priority_disagreement.csv",
               index=False, encoding="utf-8-sig")

    med = pd.read_csv(R18 / "regime_mediation_results_v18.csv")
    med["p_bonferroni"] = np.minimum(med["p_value"] * len(med), 1.0).round(4)
    med = med[["predictor", "beta", "se", "p_value", "p_bonferroni", "p_bh"]]
    for path in [SRC / "mechanism_regression_results.csv",
                 FRD / "Figure6_mechanism_regression_results.csv"]:
        med.to_csv(path, index=False)

    print("updated figure source data for", len(df), "countries")
    print(med.to_string(index=False))


if __name__ == "__main__":
    main()
