# DODJI: Data justice in overdose surveillance

[![DOI](https://zenodo.org/badge/DOI/10.5281/zenodo.21823299.svg)](https://doi.org/10.5281/zenodo.21830370)

Reproducibility materials for the manuscript **"Data justice in overdose surveillance: a governance framework for counting drug-overdose deaths before crises become visible"**.

- GitHub: https://github.com/wang76qiang/DODJI-overdose-surveillance
- Archived release: https://doi.org/10.5281/zenodo.21830370
- Version: 1.1.0

## Contents

This repository contains the materials promised in the manuscript Data sharing statement:

- analysis code for DODJI construction, validation, sensitivity analyses, mechanism analyses, and exploratory predictive validation;
- pinned derived tables for Tables S1, S2, and S4-S6;
- source-data CSV files and generation scripts for main Figures 1-7 and supplementary Figures S1-S3;
- final figure outputs in PNG and PDF formats;
- the submitted supplementary appendix;
- data-acquisition and provenance documentation.

The restricted source datasets from IHME, WHO, World Bank, INCB, EMCDDA, and other providers are not redistributed. Obtain them from the original providers under their applicable terms.

## Reproducibility status

| Component | Status | Authoritative material |
|---|---|---|
| Main DODJI results and country classification | Reproducible from pinned derived outputs; source inputs must be reacquired | `results_v17/reclassification_table_v17.csv` and analysis scripts |
| Main Table 2 / Table S1 | Exactly reproducible from pinned data | `results_v17/mechanism_variables_47countries.csv` |
| Predictive validation / Table S2 | Reproducible from deposited panel | `results_v17/annual_dodji_panel.csv` |
| Robustness / Tables S5-S6 | Reproducible from deposited outputs and scripts | `results_v17/` |
| Figures 1-7 and S1-S3 | Reproducible from deposited source-data CSVs and scripts | `figures_v21_authoritative/source_data/`, `redesign_r/`, `make_supplementary_figures.py` |
| Policy event-study / Table S3 | Adoption-year data finalised; estimates remain unreported | `results_v17/policy_adoption_years.csv`, source table, codebook, validator, and guarded exploratory template |

The policy dataset contains all 63 mortality-panel countries. Thirty EUDA-reporting countries have harmonised, source-verified years for first official availability of a standard opioid agonist treatment medication; 33 countries outside that harmonised source scope are explicitly excluded and are not treated as never-adopters. All 30 included countries eventually adopted, so there are no verified never-treated controls and late-cohort support is sparse. No policy-effect point estimates are deposited or claimed. Run `validate_policy_adoption_data.py` before any exploratory analysis and consult `results_v17/policy_adoption_years_CODEBOOK.md`.

## Repository map

```text
.
|-- run_gbd_who_analyses.py
|-- run_gbd2019_vs_2021_robustness.py
|-- run_gbd2021_ageband_robustness.py
|-- gbd_robustness_checks.py
|-- collect_mechanism_variables.py
|-- regime_mechanism_mediation.py
|-- non_gbd_dodji_variant.py
|-- perturbation_robustness.py
|-- predictive_validation.py
|-- did_policy_analysis.py
|-- validate_policy_adoption_data.py
|-- lmic_extension_framework.py
|-- make_supplementary_figures.py
|-- results_v17/
|-- figure_reproduction_data/
|-- figures_v21_authoritative/source_data/
|-- figures_redraw_nature_v2/r/
|-- redesign_r/
|-- redraw_r/
|-- geo/ne_50m_admin_0_countries/
|-- docs/
|-- supplement/SUPPLEMENTARY_MATERIALS.docx
|-- MANIFEST.tsv
`-- requirements.txt
```

## External inputs

1. IHME GBD 2021 drug-use-disorder mortality estimates: https://vizhub.healthdata.org/gbd-results/
2. WHO Mortality Database: https://www.who.int/data/data-collection-tools/who-mortality-database
3. World Bank World Development Indicators: https://databank.worldbank.org/source/world-development-indicators
4. WHO Global Health Observatory
5. World Mortality Dataset: https://github.com/akarlinsky/world_mortality
6. Published INCB-based controlled-opioid consumption estimates and EMCDDA policy reports

See `docs/DATA_ACQUISITION_CHECKLIST.md` and `docs/GBD_2019_DOWNLOAD_INSTRUCTIONS.md`.

## Environment and execution

Python 3.10 or later:

```bash
python -m venv .venv
source .venv/bin/activate  # Windows PowerShell: .venv\Scripts\Activate.ps1
python -m pip install -r requirements.txt

python run_gbd_who_analyses.py
python run_gbd2019_vs_2021_robustness.py
python run_gbd2021_ageband_robustness.py
python gbd_robustness_checks.py
python collect_mechanism_variables.py
python regime_mechanism_mediation.py
python non_gbd_dodji_variant.py
python perturbation_robustness.py
python predictive_validation.py
python lmic_extension_framework.py
python make_supplementary_figures.py
```

Main figures require R 4.4 or later with `tidyverse`, `ggplot2`, `cowplot`, `sf`, `ragg`, `scales`, and `ggrepel`. Run the scripts from the repository root. The submitted Figure 1 came from `redesign_r/fig1_surveillance_gap_eusplit_v2.R`.

## Pinned-data caveat

WHO GHO responses can change. Use `results_v17/mechanism_variables_47countries.csv` to reproduce the manuscript values. Re-querying the APIs creates an updated analysis rather than an exact reproduction. See `results_v17/DATA_PROVENANCE_NOTE.md`.

## Citation

See `CITATION.cff`. Cite the archived release with DOI https://doi.org/10.5281/zenodo.21830370.

## Licenses

- Code: MIT License (`LICENSE`)
- Author-generated derived tables, documentation, and figures: CC BY 4.0 (`LICENSE-DATA`)
- Natural Earth geographic files: public domain; see the included Natural Earth documentation
- External source data: governed by the original providers and not redistributed here
