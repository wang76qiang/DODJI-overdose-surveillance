"""
collect_mechanism_variables.py

Collect public institutional / forensic / governance indicators for the 47 DODJI
countries to support regime-level mechanism analysis (P0a).

Uses batched API calls to WHO GHO and World Bank WDI.

Outputs:
    results_v17/mechanism_variables_47countries.csv
"""

from pathlib import Path
import csv
import json
import time
import urllib.request
import urllib.error
import urllib.parse
import pandas as pd

ROOT = Path(__file__).resolve().parent
RESULTS_DIR = ROOT / "results_v17"
INPUT_CSV = RESULTS_DIR / "reclassification_table_v17.csv"
OUTPUT_CSV = RESULTS_DIR / "mechanism_variables_47countries.csv"

# ISO3 mapping for common country names in the DODJI table
COUNTRY_ISO3 = {
    "Albania": "ALB", "Argentina": "ARG", "Australia": "AUS", "Austria": "AUT",
    "Belarus": "BLR", "Belgium": "BEL", "Bosnia and Herzegovina": "BIH", "Brazil": "BRA",
    "Bulgaria": "BGR", "Canada": "CAN", "Chile": "CHL", "Colombia": "COL", "Costa Rica": "CRI",
    "Croatia": "HRV", "Cyprus": "CYP", "Czechia": "CZE", "Denmark": "DNK",
    "Dominican Republic": "DOM", "Ecuador": "ECU", "Estonia": "EST", "Finland": "FIN",
    "France": "FRA", "Germany": "DEU", "Greece": "GRC", "Guatemala": "GTM",
    "Hungary": "HUN", "Iceland": "ISL", "Ireland": "IRL", "Israel": "ISR",
    "Italy": "ITA", "Latvia": "LVA", "Lithuania": "LTU", "Luxembourg": "LUX",
    "Malta": "MLT", "Mexico": "MEX", "Monaco": "MCO", "Montenegro": "MNE",
    "Netherlands": "NLD", "New Zealand": "NZL", "North Macedonia": "MKD", "Norway": "NOR",
    "Panama": "PAN", "Peru": "PER", "Poland": "POL", "Portugal": "PRT",
    "Romania": "ROU", "Serbia": "SRB", "Slovakia": "SVK", "Slovenia": "SVN",
    "Spain": "ESP", "Sweden": "SWE", "Switzerland": "CHE", "United Kingdom": "GBR",
    "United States of America": "USA", "Uruguay": "URY",
    "San Marino": "SMR", "Andorra": "AND", "Republic of Moldova": "MDA",
    "South Korea": "KOR", "Russian Federation": "RUS", "Ukraine": "UKR",
    "Turkey": "TUR", "Japan": "JPN"
}


def fetch_json(url: str, retries: int = 2):
    """Fetch JSON from url with retry logic. Expects url to be already valid."""
    for attempt in range(retries + 1):
        try:
            req = urllib.request.Request(
                url,
                headers={"User-Agent": "DODJI mechanism collector (academic research)"},
            )
            with urllib.request.urlopen(req, timeout=60) as response:
                return json.load(response)
        except urllib.error.HTTPError as e:
            if e.code == 429 and attempt < retries:
                time.sleep(2 ** attempt)
                continue
            print(f"  HTTP {e.code} for {url[:120]}")
            return None
        except Exception as e:
            print(f"  Error fetching {url[:120]}: {e}")
            return None
    return None


def get_who_gho_indicator_all_countries(iso3_list: list, indicator: str, year_start: int = 2015, year_end: int = 2023):
    """
    Fetch WHO GHO indicator for multiple countries in one call.
    Returns dict {iso3: most_recent_numeric_value}.
    """
    countries_filter = " or ".join([f"SpatialDim eq '{c}'" for c in iso3_list])
    # OData 'and' binds tighter than 'or', so the country clause must be parenthesised.
    filter_expr = f"({countries_filter}) and TimeDim ge {year_start} and TimeDim le {year_end}"
    filter_query = urllib.parse.quote(filter_expr)
    url = f"https://ghoapi.azureedge.net/api/{indicator}?$filter={filter_query}"

    data = fetch_json(url)
    if not data or "value" not in data:
        return {}

    # Keep most recent value per country
    latest = {}
    for r in data["value"]:
        iso = r.get("SpatialDim")
        year = r.get("TimeDim")
        # Use numeric value if available; otherwise map Yes/No text values to 1/0
        val = r.get("NumericValue")
        if val is None:
            text = (r.get("Value") or "").strip().lower()
            if text in ("yes", "y"):
                val = 1
            elif text in ("no", "n"):
                val = 0
        if iso is None or year is None or val is None:
            continue
        if iso not in latest or year > latest[iso][0]:
            latest[iso] = (year, val)
    return {iso: val for iso, (_, val) in latest.items()}


def get_wdi_indicators_batched(iso3_list: list, indicator: str, year_start: int = 2015, year_end: int = 2023):
    """
    Fetch World Bank WDI indicator for multiple countries in one call.
    Returns dict {iso3: most_recent_value}.
    """
    codes = ";".join(iso3_list)
    url = (
        f"https://api.worldbank.org/v2/country/{codes}/indicator/{indicator}?"
        f"date={year_start}:{year_end}&format=json&per_page=5000"
    )
    data = fetch_json(url)
    if not data or len(data) < 2:
        return {}

    latest = {}
    for r in data[1]:
        iso = r.get("countryiso3code") or r.get("country", {}).get("id")
        year = r.get("date")
        val = r.get("value")
        if iso is None or year is None or val is None:
            continue
        year_int = int(year)
        if iso not in latest or year_int > latest[iso][0]:
            latest[iso] = (year_int, val)
    return {iso: val for iso, (_, val) in latest.items()}


def main():
    # Load 47-country list
    df = pd.read_csv(INPUT_CSV)
    countries = df["country"].tolist()

    # Verify mapping
    missing = [c for c in countries if c not in COUNTRY_ISO3]
    if missing:
        print("Missing ISO3 mappings:", missing)
        raise SystemExit(1)

    iso3_list = [COUNTRY_ISO3[c] for c in countries]

    # Define indicators
    who_indicators = {
        # Data quality / vital registration
        "who_ill_defined_pct": "WHS10_9",  # Ill-defined causes in CoD registration (%)
        "who_cod_completeness_pct": "SDGCODCOMPLETENESS",  # Completeness of cause-of-death data (%)
        "who_civil_reg_death_pct": "WHS10_8",  # Civil registration coverage of cause-of-death (%)
        "who_civil_reg_birth_pct": "WHS9_91",  # Civil registration coverage of births (%)
        # Forensic surveillance capacity (categorical: Yes/No)
        "who_forensic_alcohol_monitor": "RSUD_850",
        "who_forensic_drug_monitor": "RSUD_860",
    }

    wb_indicators = {
        "wb_gdp_per_capita": "NY.GDP.PCAP.CD",
        "wb_population": "SP.POP.TOTL",
        "wb_life_expectancy": "SP.DYN.LE00.IN",
        "wb_comm_disease_death_pct": "SH.DTH.COMM.ZS",
    }

    # Collect WHO indicators (batched in groups of 15 to respect URL length limits).
    # Use a wide year window because some GHO indicators (e.g., civil-registration
    # coverage, forensic monitoring) were last updated around 2013-2014.
    who_data = {col: {} for col in who_indicators}
    batch_size = 15
    for col, ind in who_indicators.items():
        print(f"Fetching WHO GHO {ind} ({col}) for {len(iso3_list)} countries...")
        values = {}
        for i in range(0, len(iso3_list), batch_size):
            batch = iso3_list[i:i+batch_size]
            batch_values = get_who_gho_indicator_all_countries(batch, ind, year_start=1990, year_end=2023)
            values.update(batch_values)
            time.sleep(0.3)
        who_data[col] = values
        print(f"  Got {len(who_data[col])} values")
        time.sleep(0.5)

    # Collect WB indicators (batched)
    wb_data = {col: {} for col in wb_indicators}
    for col, ind in wb_indicators.items():
        print(f"Fetching WB {ind} ({col}) for {len(iso3_list)} countries...")
        wb_data[col] = get_wdi_indicators_batched(iso3_list, ind)
        print(f"  Got {len(wb_data[col])} values")
        time.sleep(0.5)

    # Build records
    records = []
    for country in countries:
        iso3 = COUNTRY_ISO3[country]
        rec = {"country": country, "iso3": iso3}
        for col in who_indicators:
            rec[col] = who_data[col].get(iso3)
        for col in wb_indicators:
            rec[col] = wb_data[col].get(iso3)
        records.append(rec)

    out_df = pd.DataFrame(records)
    out_df.to_csv(OUTPUT_CSV, index=False)
    print(f"\nSaved {OUTPUT_CSV} with {len(out_df)} rows and {len(out_df.columns)} columns.")
    print(out_df.head())

    # Quick availability report
    print("\n=== Availability report ===")
    for col in out_df.columns:
        if col in ("country", "iso3"):
            continue
        n = out_df[col].notna().sum()
        print(f"{col}: {n}/{len(out_df)} ({100*n/len(out_df):.1f}%)")


if __name__ == "__main__":
    main()
