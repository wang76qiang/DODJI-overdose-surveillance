"""
lmic_extension_framework.py

Framework for P1b: design a staged empirical extension of DODJI to low- and
middle-income countries (LMICs) not currently represented in the 47-country sample.

Inputs:
    - results_v17/reclassification_table_v17.csv
    - World Bank income-group classification (fetched from World Bank API)

Outputs:
    results_v17/lmic_extension_framework.csv
    results_v17/unrepresented_regions_summary.csv
"""

from pathlib import Path
import pandas as pd
import urllib.request
import json

ROOT = Path(__file__).resolve().parent
RESULTS_DIR = ROOT / "results_v17"
INPUT_CSV = RESULTS_DIR / "reclassification_table_v17.csv"
OUTPUT_FRAMEWORK = RESULTS_DIR / "lmic_extension_framework.csv"
OUTPUT_UNREPRESENTED = RESULTS_DIR / "unrepresented_regions_summary.csv"

# Countries currently in the DODJI sample
CURRENT_COUNTRIES = set(pd.read_csv(INPUT_CSV)["country"].tolist())

# WHO regions and representative LMICs for staged inclusion
LMIC_CANDIDATES = [
    # Sub-Saharan Africa
    {"country": "South Africa", "iso3": "ZAF", "who_region": "AFR", "income_group": "Upper middle", "stage": 2, "rationale": "Highest overdose mortality data availability in region"},
    {"country": "Nigeria", "iso3": "NGA", "who_region": "AFR", "income_group": "Lower middle", "stage": 3, "rationale": "Large population; verbal autopsy data emerging"},
    {"country": "Kenya", "iso3": "KEN", "who_region": "AFR", "income_group": "Lower middle", "stage": 3, "rationale": "DSS sites and injury surveillance pilots"},
    # South-East Asia
    {"country": "India", "iso3": "IND", "who_region": "SEARO", "income_group": "Lower middle", "stage": 2, "rationale": "Million Death Study; COD data improving"},
    {"country": "Thailand", "iso3": "THA", "who_region": "SEARO", "income_group": "Upper middle", "stage": 2, "rationale": "Well-developed vital registration for LMIC"},
    {"country": "Indonesia", "iso3": "IDN", "who_region": "SEARO", "income_group": "Lower middle", "stage": 3, "rationale": "Large archipelago; limited forensic toxicology"},
    # Eastern Mediterranean
    {"country": "Egypt", "iso3": "EGY", "who_region": "EMRO", "income_group": "Lower middle", "stage": 3, "rationale": "Population surveillance but drug overdose coding weak"},
    {"country": "Pakistan", "iso3": "PAK", "who_region": "EMRO", "income_group": "Lower middle", "stage": 3, "rationale": "Verbal autopsy-based; limited medico-legal capacity"},
    # Western Pacific
    {"country": "China", "iso3": "CHN", "who_region": "WPRO", "income_group": "Upper middle", "stage": 2, "rationale": "Disease Surveillance Points; overdose data partial"},
    {"country": "Philippines", "iso3": "PHL", "who_region": "WPRO", "income_group": "Lower middle", "stage": 3, "rationale": "Drug-related violence complicates overdose attribution"},
    {"country": "Viet Nam", "iso3": "VNM", "who_region": "WPRO", "income_group": "Lower middle", "stage": 3, "rationale": "Rapidly changing drug markets; limited toxicology"},
    # Americas
    {"country": "Brazil", "iso3": "BRA", "who_region": "AMRO", "income_group": "Upper middle", "stage": 2, "rationale": "Already in sample; can anchor LMIC comparator"},
    {"country": "Colombia", "iso3": "COL", "who_region": "AMRO", "income_group": "Upper middle", "stage": 2, "rationale": "Already in sample"},
    {"country": "Mexico", "iso3": "MEX", "who_region": "AMRO", "income_group": "Upper middle", "stage": 2, "rationale": "Already in sample"},
    {"country": "Peru", "iso3": "PER", "who_region": "AMRO", "income_group": "Upper middle", "stage": 2, "rationale": "Already in sample"},
    {"country": "Guatemala", "iso3": "GTM", "who_region": "AMRO", "income_group": "Upper middle", "stage": 2, "rationale": "Already in sample"},
]


def current_sample_summary():
    """Summarise representation of the current 47-country sample by WHO region/income."""
    # Fetch WB income classification for current countries
    iso3_map = {
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
        "United States of America": "USA", "Uruguay": "URY", "San Marino": "SMR", "Andorra": "AND",
        "Republic of Moldova": "MDA", "South Korea": "KOR", "Russian Federation": "RUS",
        "Ukraine": "UKR", "Turkey": "TUR", "Japan": "JPN"
    }
    df = pd.read_csv(INPUT_CSV)
    df["iso3"] = df["country"].map(iso3_map)
    # Fetch WB income group (single API call for all countries)
    codes = ";".join(df["iso3"].dropna().unique())
    url = f"https://api.worldbank.org/v2/country/{codes}?format=json&per_page=100"
    try:
        with urllib.request.urlopen(url, timeout=30) as r:
            data = json.load(r)
        income_map = {c["id"]: c.get("incomeLevel", {}).get("value", "Unknown") for c in data[1]}
        df["income_group"] = df["iso3"].map(income_map)
    except Exception as e:
        print(f"Could not fetch WB income groups: {e}")
        df["income_group"] = "Unknown"
    return df


def main():
    # Save framework table
    framework = pd.DataFrame(LMIC_CANDIDATES)
    framework.to_csv(OUTPUT_FRAMEWORK, index=False)
    print(f"Saved {OUTPUT_FRAMEWORK}")

    # Summarise unrepresented WHO regions
    current = current_sample_summary()
    current_regions = {"Europe"}  # Simplified; most countries are European
    # Build region map
    region_map = {
        "Albania": "EURO", "Andorra": "EURO", "Austria": "EURO", "Belarus": "EURO",
        "Belgium": "EURO", "Bosnia and Herzegovina": "EURO", "Bulgaria": "EURO",
        "Croatia": "EURO", "Cyprus": "EURO", "Czechia": "EURO", "Denmark": "EURO",
        "Estonia": "EURO", "Finland": "EURO", "France": "EURO", "Germany": "EURO",
        "Greece": "EURO", "Hungary": "EURO", "Iceland": "EURO", "Ireland": "EURO",
        "Israel": "EURO", "Italy": "EURO", "Latvia": "EURO", "Lithuania": "EURO",
        "Luxembourg": "EURO", "Malta": "EURO", "Monaco": "EURO", "Montenegro": "EURO",
        "Netherlands": "EURO", "North Macedonia": "EURO", "Norway": "EURO", "Poland": "EURO",
        "Portugal": "EURO", "Romania": "EURO", "Russian Federation": "EURO", "Serbia": "EURO",
        "Slovakia": "EURO", "Slovenia": "EURO", "Spain": "EURO", "Sweden": "EURO",
        "Switzerland": "EURO", "Turkey": "EURO", "Ukraine": "EURO", "United Kingdom": "EURO",
        "Argentina": "AMRO", "Brazil": "AMRO", "Canada": "AMRO", "Chile": "AMRO",
        "Colombia": "AMRO", "Costa Rica": "AMRO", "Dominican Republic": "AMRO",
        "Ecuador": "AMRO", "Guatemala": "AMRO", "Mexico": "AMRO", "Panama": "AMRO",
        "Peru": "AMRO", "United States of America": "AMRO", "Uruguay": "AMRO",
        "Australia": "WPRO", "Japan": "WPRO", "New Zealand": "WPRO", "South Korea": "WPRO",
        "Republic of Moldova": "EURO"
    }
    current["who_region"] = current["country"].map(region_map).fillna("Unknown")
    region_counts = current["who_region"].value_counts().reset_index()
    region_counts.columns = ["who_region", "current_n_countries"]

    all_regions = pd.DataFrame({
        "who_region": ["AFR", "AMRO", "EMRO", "EURO", "SEARO", "WPRO"],
        "region_name": ["Africa", "Americas", "Eastern Mediterranean", "Europe", "South-East Asia", "Western Pacific"],
    })
    unrepresented = all_regions.merge(region_counts, on="who_region", how="left")
    unrepresented["current_n_countries"] = unrepresented["current_n_countries"].fillna(0).astype(int)
    unrepresented["status"] = unrepresented["current_n_countries"].apply(
        lambda x: "Well represented" if x >= 5 else ("Under-represented" if x > 0 else "Not represented")
    )
    unrepresented.to_csv(OUTPUT_UNREPRESENTED, index=False)
    print(f"Saved {OUTPUT_UNREPRESENTED}")
    print(unrepresented)


if __name__ == "__main__":
    main()
