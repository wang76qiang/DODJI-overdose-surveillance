# Policy adoption-year dataset codebook

## Primary exposure

`first_treat_year` is the first calendar year in which a standard opioid agonist treatment
(OAT) medication was officially available nationally. Standard OAT includes methadone,
high-dose buprenorphine, buprenorphine/naloxone, and slow-release oral morphine.
Diacetylmorphine programmes and pilots are excluded from the primary definition.

The date is an **availability date**, not a coverage threshold, reimbursement date, statute
enactment date, or proof of broad implementation. The outcome panel covers 1992-2018.

## Analysis scope

Thirty countries are included: the 28 countries covered by EUDA Appendix Table A1 that are
present in the mortality panel, plus authoritative country-report extensions for Norway and
Turkey. The other 33 panel countries have `analysis_included=0`. Their missing years mean
"outside the harmonised source scope", not "never treated". The analysis code must not use
scope-excluded rows as untreated controls.

## Field definitions

- `country`: exact country label used in `annual_mortality_panel.csv`.
- `first_treat_year`: minimum verified year across the four standard OAT medication classes.
- `policy_type`: fixed exposure identifier, `standard_oat_official_availability`.
- `analysis_included`: 1 only when a comparable authoritative year is available.
- `source_scope`: harmonised EUDA table, authoritative extension, or scope exclusion.
- `*_year`: medication-specific official introduction/availability year.
- `*_status`: `officially_available`, `legally_available_no_reported_clients`,
  `not_applicable`, or `not_coded`.
- `source_id`, `source_url`, `source_locator`: provenance linked to
  `policy_adoption_sources.csv`.
- `verification_status`: audit disposition. `scope_excluded_not_assumed_never_treated`
  must never be recoded as non-adoption.

## Source hierarchy and decisions

1. EUDA/EMCDDA cross-national tables were preferred for harmonised definitions.
2. Norway and Turkey were added only where authoritative country reports stated a national
   availability year.
3. Parenthesised EUDA medication dates mean legally available with no reported clients.
   This status is retained in the medication-specific field.
4. No date was inferred from a current-availability flag, a news article, or a neighbouring
   country's history.
5. No missing year was converted to zero.

## Version

Dataset version: 1.1.0. Compiled and verified 2026-08-07.
