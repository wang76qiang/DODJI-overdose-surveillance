# Data Provenance Note

## `mechanism_variables_47countries.csv`

This file is the **authoritative version used to generate Table 2 and the mechanism regression in the manuscript**. It was produced from WHO Global Health Observatory (GHO) and World Bank WDI queries executed prior to manuscript finalisation.

### Important reproducibility caveat

The current `collect_mechanism_variables.py` script uses a 1990-2023 query window (updated during the pre-submission audit) because several GHO indicators were last updated outside the originally stated 2015-2023 window:

- `WHS10_8` (civil-registration death coverage): last data around 2009-2013.
- `RSUD_850` / `RSUD_860` (forensic alcohol/drug monitoring): last data around 2014.
- `WHS9_91` (civil-registration birth coverage): no data available.

Running the updated script will retrieve values for most indicators, but the exact counts and values may differ slightly from the pinned CSV because (1) API responses can change, and (2) the script does not currently disaggregate or filter by `Dim1` dimensions for the RSUD indicators.

### Recommendation

For the purpose of reproducing the exact manuscript numbers, use this pinned `mechanism_variables_47countries.csv`. If updating the analysis, review the API output carefully, consider `Dim1` filtering for RSUD indicators, and update Table 2 / paragraph 61 accordingly.
