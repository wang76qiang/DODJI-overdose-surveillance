"""
build_reclassification_v18.py

Explicit, fully reproducible derivation of the DODJI governance classification
and combined preparedness-priority score (v18; supersedes the undocumented v17
composite).

Algorithm (prespecified here and reported in the manuscript Methods):

Inputs per country (pinned in results_v17/reclassification_table_v17.csv):
    mortality_rank : rank of the GBD 2021 age-standardised drug-use-disorder
                     death rate (1 = highest burden), n = 47
    dodji_score    : primary cross-sectional DODJI (GDP-residualised
                     studentised residual of the raw data-quality score Q)

1. Burden need      B = (47 - mortality_rank) / 46            in [0, 1]
2. Surveillance need S = (rank_ascending(DODJI) - 1) / 46     in [0, 1]
   (percentile rank; robust to sparse-event microstate outliers)
3. Combined priority score = 1 + 3.5 * (0.5*B + 0.5*S), rounded to 0.05
   (equal weights; scale 1.00-4.50)
4. Combined priority rank: descending score; ties broken by higher burden
   need, then higher surveillance need (unique ranks 1-47).
5. Priority tiers by combined-priority-rank quartiles:
   I = ranks 1-12, II = 13-24, III = 25-36, IV = 37-47.
6. Governance regimes (burden-by-surveillance matrix):
   H = mortality_rank <= 23 (highest-burden half)
   V = mortality_rank >= 36 (bottom-quartile reported burden)
   W = dodji_score > 0 (surveillance worse than GDP-adjusted expectation)
       Insufficient exposure data : V and W
       Data-quality-limited       : W and not V
       Medical-system-driven      : H and not W
       Low-burden / protected     : otherwise
7. Auxiliary explicit codes:
   dodji_tier   : "Worse than expected" (DODJI > 0),
                  "As expected" (-0.5 < DODJI <= 0),
                  "Better than expected" (DODJI <= -0.5)
   burden_tier  : Critical (rank <= 12), High (13-24),
                  Moderate (25-36), Low (37-47)
   surveillance_gap : 1 if H and W (high burden with worse-than-expected
                  surveillance), else 0
   reclassification : "Up >=10" (shift >= 10), "Down >=10" (shift <= -10),
                  else "Stable"; rank_shift = mortality - priority rank

Outputs:
    results_v18/reclassification_table_v18.csv
    results_v18/reclassification_summary_v18.csv
    results_v18/v18_key_numbers.json   (manuscript-facing numbers manifest)
"""

from pathlib import Path
import json

import numpy as np
import pandas as pd

ROOT = Path(__file__).resolve().parent
IN_CSV = ROOT / "results_v17" / "reclassification_table_v17.csv"
OUT_DIR = ROOT / "results_v18"

REGIMES = [
    "Medical-system-driven",
    "Low-burden / protected",
    "Data-quality-limited",
    "Insufficient exposure data",
]

RECOMMENDATIONS = {
    "Medical-system-driven": (
        "Maintain mortality surveillance; conduct implementation research on "
        "high-burden subpopulations and health-service integration."
    ),
    "Low-burden / protected": (
        "Sustain prevention and harm-reduction coverage; monitor cross-border "
        "synthetic drug flows through passive and active surveillance."
    ),
    "Data-quality-limited": (
        "Invest in vital-registration modernisation, medical-examiner capacity, "
        "and external mortality audits; prioritise verbal autopsy and sentinel "
        "surveillance research to quantify undercount."
    ),
    "Insufficient exposure data": (
        "Develop targeted prevalence surveys and mortality sentinel sites; "
        "research emerging synthetic opioid and stimulant market dynamics; "
        "strengthen diagnostic and certification capacity."
    ),
}


def classify_regime(mortality_rank, dodji_score):
    """Explicit burden-by-surveillance matrix classifier (vectorised)."""
    r = np.asarray(mortality_rank, dtype=float)
    d = np.asarray(dodji_score, dtype=float)
    H = r <= 23
    V = r >= 36
    W = d > 0
    out = np.full(r.shape, "Low-burden / protected", dtype=object)
    out[H & ~W] = "Medical-system-driven"
    out[W & ~V] = "Data-quality-limited"
    out[V & W] = "Insufficient exposure data"
    return pd.Series(out, index=getattr(mortality_rank, "index", None))


def priority_from_scores(mortality_rank, dodji_score):
    """Return DataFrame with B, S, score, rank, tier for given inputs.

    The input Series index is preserved so results can be joined back to the
    source rows; rows are sorted by combined priority (best first).
    """
    idx = getattr(mortality_rank, "index", None)
    df = pd.DataFrame({"mortality_rank": np.asarray(mortality_rank, dtype=float),
                       "dodji_score": np.asarray(dodji_score, dtype=float)},
                      index=idx)
    n = len(df)
    df["B"] = (n - df["mortality_rank"]) / (n - 1)
    s_rank = df["dodji_score"].rank(method="average")
    df["S"] = (s_rank - 1) / (n - 1)
    raw = 1 + 3.5 * (0.5 * df["B"] + 0.5 * df["S"])
    df["priority_score"] = (np.round(raw / 0.05) * 0.05).round(2)
    df = df.sort_values(["priority_score", "B", "S"],
                        ascending=[False, False, False])
    df["combined_priority_rank"] = np.arange(1, n + 1)
    k = int(np.ceil(n / 4))
    df["priority_label"] = pd.cut(
        df["combined_priority_rank"], bins=[0, k, 2 * k, 3 * k, n],
        labels=["Priority I", "Priority II", "Priority III", "Priority IV"],
        include_lowest=True)
    return df


def dodji_tier(d):
    if d > 0:
        return "Worse than expected"
    if d <= -0.5:
        return "Better than expected"
    return "As expected"


def burden_tier(r):
    if r <= 12:
        return "Critical"
    if r <= 24:
        return "High"
    if r <= 36:
        return "Moderate"
    return "Low"


def main():
    OUT_DIR.mkdir(exist_ok=True)
    base = pd.read_csv(IN_CSV, encoding="utf-8-sig")
    base = base[["country", "mortality_level", "mortality_rank", "dodji_score"]]
    n = len(base)
    assert n == 47

    pr = priority_from_scores(base["mortality_rank"], base["dodji_score"])
    df = (base.join(pr[["B", "S", "priority_score", "combined_priority_rank",
                        "priority_label"]])
              .sort_values("combined_priority_rank")
              .reset_index(drop=True))
    df["rank_shift_up"] = df["mortality_rank"] - df["combined_priority_rank"]
    df["reclassification"] = np.select(
        [df["rank_shift_up"] >= 10, df["rank_shift_up"] <= -10],
        ["Up >=10", "Down >=10"], default="Stable")
    df["typology"] = classify_regime(df["mortality_rank"], df["dodji_score"])
    df["dodji_tier"] = df["dodji_score"].map(dodji_tier)
    df["burden_tier"] = df["mortality_rank"].map(burden_tier)
    df["surveillance_gap"] = ((df["mortality_rank"] <= 23) &
                              (df["dodji_score"] > 0)).astype(int)
    df["recommendation"] = df["typology"].map(RECOMMENDATIONS)

    cols = ["country", "typology", "mortality_level", "mortality_rank",
            "dodji_score", "dodji_tier", "burden_tier", "B", "S",
            "priority_score", "combined_priority_rank", "rank_shift_up",
            "reclassification", "priority_label", "surveillance_gap",
            "recommendation"]
    df = df[cols]
    df.to_csv(OUT_DIR / "reclassification_table_v18.csv", index=False)

    up = int((df["rank_shift_up"] >= 10).sum())
    down = int((df["rank_shift_up"] <= -10).sum())
    summary = {
        "n_countries": n,
        "up_by_10_or_more": up,
        "down_by_10_or_more": down,
        "stable": n - up - down,
        "low_or_mid_mortality_reclassified_surveillance_priority": int(
            ((df["rank_shift_up"] >= 10) & (df["mortality_rank"] > 12)).sum()),
        "high_mortality_implementation_not_foundational_priority": int(
            ((df["mortality_rank"] <= 12) &
             (df["typology"] == "Medical-system-driven")).sum()),
    }
    pd.DataFrame([summary]).to_csv(
        OUT_DIR / "reclassification_summary_v18.csv", index=False)

    # ---- manuscript-facing numbers manifest ----
    med = df.groupby("typology").agg(
        n=("country", "count"),
        med_rank=("mortality_rank", "median"),
        med_dodji=("dodji_score", "median")).reindex(REGIMES)
    tiers = df.groupby("priority_label", observed=True).agg(
        n=("country", "count"),
        smin=("priority_score", "min"),
        smax=("priority_score", "max"))
    # boundary ties
    ties = {}
    bounds = [("I", "II"), ("II", "III"), ("III", "IV")]
    for hi, lo in bounds:
        hi_min = tiers.loc[f"Priority {hi}", "smin"]
        lo_max = tiers.loc[f"Priority {lo}", "smax"]
        if hi_min == lo_max:
            tied = df[df["priority_score"] == hi_min][
                ["country", "priority_label"]]
            ties[f"{hi}-{lo}"] = {
                "score": float(hi_min),
                "countries": {r["country"]: r["priority_label"]
                              for _, r in tied.iterrows()}}
    manifest = {
        "n": n,
        "movers": summary,
        "up_movers": df.loc[df["rank_shift_up"] >= 10,
                            ["country", "mortality_rank",
                             "combined_priority_rank", "rank_shift_up"]]
                      .to_dict("records"),
        "regime_stats": {k: {"n": int(v["n"]),
                             "med_rank": float(v["med_rank"]),
                             "med_dodji": round(float(v["med_dodji"]), 2)}
                         for k, v in med.iterrows()},
        "tier_stats": {k: {"n": int(v["n"]), "smin": float(v["smin"]),
                           "smax": float(v["smax"])}
                       for k, v in tiers.iterrows()},
        "tier_ties": ties,
        "top12_mortality": df[df["mortality_rank"] <= 12][
            ["country", "typology"]].to_dict("records"),
        "priority_I": df[df["priority_label"] == "Priority I"]["country"]
                      .tolist(),
    }
    with open(OUT_DIR / "v18_key_numbers.json", "w") as f:
        json.dump(manifest, f, indent=2, ensure_ascii=False)

    print(df[["country", "typology", "mortality_rank", "dodji_score",
              "priority_score", "combined_priority_rank", "rank_shift_up",
              "priority_label"]].to_string(index=False))
    print("\nSummary:", summary)
    print("\nRegime stats:\n", med)
    print("\nTier stats:\n", tiers)
    print("\nTier ties:", json.dumps(ties, ensure_ascii=False))


if __name__ == "__main__":
    main()
