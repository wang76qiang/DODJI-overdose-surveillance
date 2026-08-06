# GBD 2019 download instructions

The GBD 2019 versus GBD 2021 sensitivity analysis requires local copies of both releases. These source files are not redistributed in this repository.

1. Open the IHME GBD Results Tool: https://vizhub.healthdata.org/gbd-results/
2. Select GBD 2019, the drug-use-disorder cause used in the analysis, deaths, rate, and the manuscript's age/sex/year settings.
3. Download the CSV export.
4. Store the file in a local data directory outside this repository.
5. Set the environment variables documented at the top of `run_gbd2019_vs_2021_robustness.py`.
6. From the repository root, run:

```bash
python run_gbd2019_vs_2021_robustness.py
```

The exact export name depends on the IHME request. Keep the downloaded metadata or request receipt with your local copy so the query can be audited.
