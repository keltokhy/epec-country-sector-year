# EPEC Country-Sector-Year Aggregates

This repository hosts a reproducible extract of the European PPP Expertise Centre (EPEC) portal data from https://data.eib.org/epec/. It contains the full cube of PPP project counts and total values (in EUR millions) by country, sector, and year for 1990‑2021, coupled with metadata describing the pull.

## Contents
- `data/epec_country_sector_year.csv` – tidy dataset with columns `country`, `sector`, `year`, `project_count`, `project_value_eur_millions`.
- `data/epec_country_sector_year.metadata.json` – provenance details (download timestamp, list of filters, source URL).
- `scripts/epec_extract.py` – scraper that reads the portal filters and queries the public JSON endpoints to regenerate the dataset.

## Reproducing the Extract
The script depends on `requests` and `beautifulsoup4`. With `uv` (preferred) you can run:

```bash
uv run python scripts/epec_extract.py --out-csv data/epec_country_sector_year.csv --metadata data/epec_country_sector_year.metadata.json
```

The script pulls filter values directly from the portal, iterates every country-sector combination, and calls `https://data.eib.org/epec/sector/years?year=MIN,MAX&sector=...&country=...` to retrieve the time series. Missing combinations are filled with zero counts/values.

## Notes
- Data is aggregated; the portal does not expose transaction-level records.
- The extraction timestamp in the metadata file reflects when the bundled CSV was generated (UTC).
- If EPEC updates its portal year range or sector/country lists, rerunning the script will automatically capture the new scope.
