# Data acquisition checklist for P0b / P1a

## Status (YX6)

- ✅ GBD 2021 country estimates — available in `E:/药物滥用/大文章撰写分析/原始数据`
- ✅ WHO Mortality Database — available in `E:/药物滥用/大文章撰写分析/原始数据`
- ✅ GBD 2021 age-band files — available in `E:/药物滥用/数据16/数据16`
- ❌ GBD 2019 country estimates — not obtained; replaced by GBD 2021 internal age-band robustness

---

## P0b. GBD internal / cross-input robustness checks

### Required downloads

1. **GBD 2021 country estimates**
   - Source: IHME GBD Results Tool (http://ghdx.healthdata.org/gbd-results-tool)
   - Selection:
     - Measure: Deaths, YLLs, Rate
     - Metric: Rate, Number
     - Cause: Drug-use disorders (all) + Opioid use disorders (subcause)
     - Location: All countries in DODJI sample (47 countries)
     - Year: 1990-2021
     - Age: All ages, Age-standardised
     - Sex: Both
   - Save as: `results_v17/gbd_2021_overdose_estimates.csv`
   - Columns needed: `location_name`, `year`, `cause_name`, `age_name`, `sex`, `val`, `upper`, `lower`

2. **GBD 2021 age-band estimates (European subset)**
   - Source: IHME GBD Results Tool
   - Selection:
     - Cause: Drug use disorders
     - Measure: Deaths
     - Metric: Rate
     - Age: 15-49 years, 15-64 years, 65+ years (age-standardised within each band)
     - Sex: Both
     - Year: 1990-2021
   - Files already present:
     - `E:/药物滥用/数据16/数据16/15-49岁标化.csv`
     - `E:/药物滥用/数据16/数据16/15-64标化数据.csv`
     - `E:/药物滥用/数据16/数据16/65+标化数据.csv`

3. **WHO Mortality Database detailed deaths**
   - Source: https://platform.who.int/mortality/countries/country-detail
   - Download ICD-10 deaths by country and year for codes X40-X44, X60-X64, X85, Y10-Y14.
   - Aggregate to country-year-all-ages-both-sexes.
   - Save as: `results_v17/who_mortality_overdose_x40x44_x60x64_x85_y10y14.csv`
   - Columns needed: `country`, `year`, `deaths`, `population`

### Execution

```bash
python run_gbd_who_analyses.py
python run_gbd2021_ageband_robustness.py
```

Expected outputs:
- `results_v17/gbd_robustness_summary.csv`
- `results_v17/who_gbd_cross_source_summary.csv`
- `results_v17/gbd2021_ageband_robustness_summary.csv`
- `results_v17/gbd2021_ageband_country_scores.csv`

### Sensitivity checks to report

| Check | Alternative DODJI | Stability metric |
|-------|-------------------|------------------|
| Cause scope | Opioid-only vs all-drug | Spearman ρ, regime stability, Priority-I Jaccard |
| Age metric | Age-standardised vs all-ages | Same |
| Age-band standardisation | 15-49 / 15-64 / 65+ years (European subset, n=37) | Same |
| Mortality source | WHO Mortality Database vs GBD (European subset, n=37) | Same |

**Note:** GBD 2019 cross-version check was abandoned because no GBD 2019 files are available. It is replaced by the age-band standardisation sensitivity analysis and noted as a limitation in the manuscript.

---

## P1a. Predictive validation using annual trajectories

### Required downloads

1. **Annual GBD overdose estimates 2010-2021**
   - Same GBD Results Tool as above.
   - Year: 2010, 2011, ..., 2021
   - Save as: `results_v17/annual_overdose_panel_2010_2021.csv`
   - Columns needed: `country`, `year`, `mortality_rate`, `gbd_upper_ui`, `gbd_lower_ui`

2. **Optional: WHO Mortality Database annual deaths**
   - Use as external validator if GBD annual data are not available.

### Execution

```bash
python run_gbd_who_analyses.py
```

Expected outputs:
- `results_v17/predictive_validation_results.csv`
- `results_v17/annual_dodji_panel.csv`

### Analyses to report

| Outcome | Predictor | Model |
|---------|-----------|-------|
| 3-year mortality change | Annual DODJI | OLS (exploratory/ecological) |

---

## Notes

- IHME GBD downloads require agreeing to terms of use; no API key needed for public results.
- WHO Mortality Database is free but may require registration.
- Both downloads may take several hours depending on server load.
