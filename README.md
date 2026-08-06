# DODJI: Data Justice in Overdose Surveillance — Reproducibility Repository

Reproducibility materials for the manuscript *"Data justice in overdose surveillance:
a governance framework and action agenda for counting drug-overdose deaths before
crises become visible"* (submitted to *The Lancet*).

This repository contains **analytic code, derived result tables (including the pinned
mechanism-variables table used for Table 2), figure-generation scripts, figure outputs,
and source data for figures**, as stated in the manuscript's Data-sharing statement.

## Repository structure

```
.
├── MANUSCRIPT_LANCET_MAIN_LA4.docx      # Submission manuscript (The Lancet)
├── SUPPLEMENTARY_MATERIALS.docx         # Supplementary materials (Tables S1-S6, figures)
├── run_gbd_who_analyses.py              # 1. Main DODJI computation (GBD 2021 + WHO)
├── run_gbd2019_vs_2021_robustness.py    # 2. GBD 2019 vs 2021 cross-version robustness
├── run_gbd2021_ageband_robustness.py    # 3. GBD 2021 age-band robustness (European subset)
├── gbd_robustness_checks.py             # 4. GBD specification-variant correlations
├── collect_mechanism_variables.py       # 5. WHO GHO / World Bank mechanism variables
├── regime_mechanism_mediation.py        # 6. Mechanism regression (Table 2 statistics)
├── non_gbd_dodji_variant.py             # 7. Non-GBD civil-registration-proxy variant
├── perturbation_robustness.py           # 8. Monte-Carlo perturbation stability checks
├── predictive_validation.py             # 9. Exploratory predictive validation (Table S2)
├── did_policy_analysis.py               # 10. Policy event-study (see caveat below)
├── lmic_extension_framework.py          # 11. LMIC extension / unrepresented regions
├── make_supplementary_figures.py        # Figures S1–S3
├── redesign_r/                          # R scripts for main Figures 1–7
│   ├── fig1_surveillance_gap.R          #   (submitted Figure 1 = fig1_surveillance_gap_eusplit_v2.R,
│   ├── fig1_surveillance_gap_eusplit*.R #    output renamed to Figure1_surveillance_gap_nature)
│   ├── fig2_priority_reordering.R ... fig7_robustness.R
├── redraw_r/nature_redraw_style.R       # Shared theme/palette sourced by redesign_r scripts
├── results_v17/                         # Derived result tables (CSV)
│   ├── reclassification_table_v17.csv           # 47-country master table (Table S4)
│   ├── mechanism_variables_47countries.csv      # PINNED authoritative Table 2 source (Table S1)
│   ├── predictive_validation_results.csv        # Table S2 source
│   ├── gbd_robustness_summary.csv, perturbation_robustness_summary.csv, ...  # Table S5a/b sources
│   ├── microstate_sensitivity_v17.csv           # Table S6 source
│   ├── annual_dodji_panel.csv                   # Figure S1 source
│   └── DATA_PROVENANCE_NOTE.md
├── figures_v21_authoritative/source_data/  # Source-data CSVs read by the R figure scripts
├── figure_reproduction_data/               # Per-panel plotting data for Figures 1–7 (with README)
├── figures_redraw_nature_v2/r/             # Final figure outputs (PNG 600 dpi + PDF), Figures 1–7 and S1–S3
├── geo/ne_50m_admin_0_countries/           # Natural Earth shapefile used for Figure 1 maps
├── docs/                                   # Data download instructions and acquisition checklist
└── requirements.txt
```

Supplementary table numbers above follow the final submission manuscript, in which
supplementary tables are numbered by order of first citation.

## External data requirements

Input data are publicly available from the original providers and are **not**
redistributed here:

1. **IHME GBD 2021** drug-use-disorder mortality estimates (rates + uncertainty
   intervals; age-standardised, all-ages, and age bands 15–49, 15–64, 65+):
   <https://vizhub.healthdata.org/gbd-results/>
2. **WHO Mortality Database** — drug-use-disorder trends:
   <https://www.who.int/data/data-collection-tools/who-mortality-database>
3. **World Bank World Development Indicators** — GDP per capita, population, etc.:
   <https://databank.worldbank.org/source/world-development-indicators>
4. **WHO Global Health Observatory** — cause-of-death completeness, ill-defined
   causes, forensic monitoring (queried by `collect_mechanism_variables.py`)
5. **World Mortality Dataset** — civil-registration completeness:
   <https://github.com/akarlinsky/world_mortality>
6. **INCB** controlled-opioid consumption estimates; **EMCDDA** policy histories.

Scripts read local copies of these files via environment variables
(`DODJI_DATA_DIR`, `DODJI_GBD2021_FILENAME`, …); see the header of each script
and `docs/GBD_2019_DOWNLOAD_INSTRUCTIONS.md` / `docs/DATA_ACQUISITION_CHECKLIST.md`.

## Execution order

```bash
# Analysis (Python 3.10+; pip install -r requirements.txt)
python run_gbd_who_analyses.py
python run_gbd2019_vs_2021_robustness.py
python run_gbd2021_ageband_robustness.py
python gbd_robustness_checks.py
python collect_mechanism_variables.py     # see pinned-table caveat below
python regime_mechanism_mediation.py
python non_gbd_dodji_variant.py
python perturbation_robustness.py
python predictive_validation.py
python lmic_extension_framework.py

# Figures (run from the repository root)
python make_supplementary_figures.py      # Figures S1–S3 -> figures_redraw_nature_v2/r/
Rscript redesign_r/fig1_surveillance_gap_eusplit_v2.R   # submitted Figure 1
Rscript redesign_r/fig2_priority_reordering.R           # ... through Figure 7
```

## Important reproducibility notes

### Pinned mechanism variables

`results_v17/mechanism_variables_47countries.csv` is the **pinned authoritative
version** used to generate main-text Table 2 and the mechanism regression. Several
WHO GHO indicators (e.g., `WHS10_8`, `RSUD_850/860`) were last updated around
2009–2014, outside the originally planned 2015–2023 window. Re-running
`collect_mechanism_variables.py` may yield slightly different values because API
responses change over time. For exact reproduction of manuscript numbers, use the
pinned CSV. See `results_v17/DATA_PROVENANCE_NOTE.md`.

### Policy event-study

`did_policy_analysis.py` is a pedagogical two-way fixed-effects event-study
implementation. It requires manually assembled inputs
(`results_v17/policy_adoption_years.csv`, `results_v17/annual_mortality_panel.csv`)
coded from EMCDDA reports and peer-reviewed policy evaluations. The policy analysis
in the manuscript is reported as **descriptive ecological associations, not causal
effects** (supplementary Table S3 documents the design only; no point estimates are
reported).

### Figures

Final submitted figures (600-dpi PNG + PDF) are in `figures_redraw_nature_v2/r/`.
R figure scripts read `figures_v21_authoritative/source_data/` and write to
`figures_redraw_nature_v2/r/` with the repository root as the working directory.
The submitted Figure 1 was produced by `fig1_surveillance_gap_eusplit_v2.R`;
its output file was renamed `Figure1_surveillance_gap_nature.{png,pdf}` for submission.

## Environment

- Python 3.10+ with `requirements.txt`
- R 4.4+ with packages: `tidyverse`, `ggplot2`, `cowplot`, `sf`, `ragg`, `scales`, `ggrepel`

## Citation and license

This repository is licensed under the Creative Commons Attribution 4.0
International (CC BY 4.0) license. See `LICENSE`.

To cite these materials or the manuscript, please use the repository DOI
(see the GitHub "Cite this repository" menu) or:

Fang H, Wang L, Wang Q. Data justice in overdose surveillance: a governance
framework and action agenda for counting drug-overdose deaths before crises
become visible. Manuscript submitted to *The Lancet*; 2026. Reproducibility
repository: <repository URL and Zenodo DOI to be inserted after registration>.
