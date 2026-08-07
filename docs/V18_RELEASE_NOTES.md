# v1.2.0 release notes (pending publication)

## Status: PREPARED LOCALLY — Zenodo/GitHub release still required

Version 1.2.0 introduces the explicit, reproducible v18 classification and
priority-scoring pipeline. All manuscript-facing numbers in the Lancet
submission (MANUSCRIPT_LANCET_MAIN_LA4_STOP_SLOP_STRICT_FINAL.docx and
SUPPLEMENTARY_MATERIALS_REPOSITORY_REGISTERED.docx, edited 2026-08-07) now
derive from `results_v18/`.

## New files

- `build_reclassification_v18.py` — explicit algorithm (formula + regime rule)
- `build_v18_derived.py` — downstream recomputation (Table 1 aggregates,
  mechanism regression with regime FE + BH, robustness stability, perturbation)
- `update_figure_data_v18.py` — regenerates classification-dependent figure
  source CSVs (figures_v21_authoritative/source_data, figure_reproduction_data)
- `results_v18/reclassification_table_v18.csv` — authoritative 47-country table
- `results_v18/reclassification_summary_v18.csv`
- `results_v18/regime_mechanism_table_v18.csv` (main-text Table 1)
- `results_v18/regime_mediation_results_v18.csv` (Figure S4a)
- `results_v18/robustness_stability_v18.csv` (Table S5b)
- `results_v18/perturbation_robustness_summary_v18.csv` (Table S5b)
- `results_v18/v18_key_numbers.json` (manuscript numbers manifest)

## Changed figures (regenerated)

- Figure 1 (eusplit_v2), Figure 2, Figure 3, Figure 6 (-> manuscript Figure S4),
  Supplementary Figure S1. Figures 4, 5, 7 (-> Figure S5), S2, S3 unaffected.

## Editorial fixes included in the manuscript pair

- M1: mechanism-proxy sentence now consistent with main-text Table 1;
  mechanism regression (v18 regimes) has no BH-surviving predictor.
- M2/M3: Data sharing cites the Zenodo concept DOI (10.5281/zenodo.21823299)
  and acknowledges the deposited source-verified policy-adoption dataset.
- M4: explicit priority-score formula and regime-classification rule in
  Methods, S1.3, S1.4, and protocol v1.2.
- M5: Table S5a civil-registration-proxy n corrected 30 -> 47.
- M7: main text consolidated to 6 display items (Figures 1-5 + Table 1);
  old Table 1 dropped (redundant with Table S4); old Table 3 -> Table S7;
  Figures 6/7 -> Figures S4/S5.

## Before journal submission (user actions)

1. Commit and push these changes; tag `v1.2.0`.
2. Create GitHub release v1.2.0 and publish the Zenodo archive; the concept
   DOI 10.5281/zenodo.21823299 will then resolve to v1.2.0.
3. Verify that the archived ZIP contains results_v18/ and the three v18
   scripts, then update `DODJI_PUBLICATION_RECORD` with the version DOI.
