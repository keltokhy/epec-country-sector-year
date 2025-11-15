"""Download EPEC PPP aggregates for every country-sector-year combination.

The portal at https://data.eib.org/epec/ exposes JSON endpoints that the
front-end calls via AJAX. This script reuses those public endpoints to pull a
complete cube of counts and project values by country, sector, and year. All
outputs are saved under data/.
"""
from __future__ import annotations

import argparse
import csv
import json
import sys
from dataclasses import dataclass
from datetime import datetime, timezone
from pathlib import Path
from typing import Iterable, List, Sequence, Tuple

import requests
from bs4 import BeautifulSoup

BASE_URL = "https://data.eib.org"
PORTAL_URL = f"{BASE_URL}/epec/"
SECTOR_YEARS_ENDPOINT = f"{BASE_URL}/epec/sector/years"
QUICKSTAT_ENDPOINT = f"{BASE_URL}/epec/graph/quickStat"

REPO_ROOT = Path(__file__).resolve().parents[1]
DEFAULT_OUTPUT_DIR = REPO_ROOT / "data"
DEFAULT_OUTPUT_CSV = DEFAULT_OUTPUT_DIR / "epec_country_sector_year.csv"
DEFAULT_METADATA_JSON = DEFAULT_OUTPUT_DIR / "epec_country_sector_year.metadata.json"


@dataclass(frozen=True)
class Filters:
    sectors: Sequence[str]
    countries: Sequence[str]
    min_year: int
    max_year: int

    @property
    def year_range(self) -> Sequence[int]:
        return list(range(self.min_year, self.max_year + 1))


def fetch_portal_html() -> str:
    resp = requests.get(PORTAL_URL, timeout=60)
    resp.raise_for_status()
    return resp.text


def extract_filters(html: str) -> Filters:
    soup = BeautifulSoup(html, "html.parser")

    slider = soup.find("div", {"id": "yearSlider"})
    if slider is None:
        raise RuntimeError("Year slider not found in the EPEC portal HTML.")
    min_year = int(slider["data-slider-min"])
    max_year = int(slider["data-slider-max"])

    sector_select = soup.find("select", {"id": "sector"})
    country_select = soup.find("select", {"id": "country"})
    if sector_select is None or country_select is None:
        raise RuntimeError("Unable to locate sector or country dropdowns in portal HTML.")

    sectors = [
        opt.get_text(strip=True)
        for opt in sector_select.find_all("option")
        if opt.get_text(strip=True) and "--All--" not in opt.get_text()
    ]
    countries = [
        opt.get_text(strip=True)
        for opt in country_select.find_all("option")
        if opt.get_text(strip=True)
        and "--All--" not in opt.get_text()
        and opt.get("value", "").lower() != "all"
    ]

    if not sectors or not countries:
        raise RuntimeError("Parsed empty sector or country list from the portal.")

    return Filters(sectors=sectors, countries=countries, min_year=min_year, max_year=max_year)


def encode_filter(value: str) -> str:
    """Match the portal encoding by replacing spaces with underscores."""
    return value.replace(" ", "_")


def fetch_sector_years(
    sector: str,
    country: str,
    year_span: Tuple[int, int],
) -> dict:
    params = {
        "year": f"{year_span[0]},{year_span[1]}",
        "sector": encode_filter(sector),
        "country": encode_filter(country),
    }
    resp = requests.get(SECTOR_YEARS_ENDPOINT, params=params, timeout=60)
    resp.raise_for_status()
    payload = resp.json()
    if not isinstance(payload, dict) or "data" not in payload:
        raise RuntimeError(f"Unexpected payload for {sector}/{country}: {payload}")
    return payload


def fetch_reference_totals(filters: Filters) -> tuple[int, int]:
    params = [
        ("year", filters.min_year),
        ("year", filters.max_year),
        ("sector", ""),
        ("ccountry", "all"),
    ]
    resp = requests.get(QUICKSTAT_ENDPOINT, params=params, timeout=60)
    resp.raise_for_status()
    payload = resp.json()
    if not isinstance(payload, list) or len(payload) < 1:
        raise RuntimeError(f"Unexpected quickStat payload: {payload}")
    reference = payload[0]
    return int(reference["total"]), int(reference["totalValue"])


def iter_rows(filters: Filters) -> Iterable[dict]:
    for country in filters.countries:
        for sector in filters.sectors:
            payload = fetch_sector_years(sector, country, (filters.min_year, filters.max_year))
            values_by_year = {
                int(year): (int(total or 0), float(total_value or 0))
                for year, total, total_value in zip(payload["data"], payload["total"], payload["totalValue"])
            }
            for year in filters.year_range:
                projects, total_value = values_by_year.get(year, (0, 0.0))
                yield {
                    "country": country,
                    "sector": sector,
                    "year": year,
                    "project_count": projects,
                    "project_value_eur_millions": total_value,
                }


def write_csv(rows: Sequence[dict], output_path: Path) -> int:
    output_path.parent.mkdir(parents=True, exist_ok=True)
    if not rows:
        raise RuntimeError("No rows returned from the API.")

    fieldnames = list(rows[0].keys())
    with output_path.open("w", newline="", encoding="utf-8") as fh:
        writer = csv.DictWriter(fh, fieldnames=fieldnames)
        writer.writeheader()
        writer.writerows(rows)
    return len(rows)


def write_metadata(
    filters: Filters,
    output_csv: Path,
    metadata_path: Path,
    row_count: int,
    total_projects: int,
    total_value_millions: int,
) -> None:
    metadata = {
        "source": PORTAL_URL,
        "downloaded_at_utc": datetime.now(timezone.utc).isoformat(),
        "countries": filters.countries,
        "sectors": filters.sectors,
        "year_start": filters.min_year,
        "year_end": filters.max_year,
        "row_count": row_count,
        "output_csv": str(output_csv),
        "total_projects": total_projects,
        "total_project_value_eur_millions": total_value_millions,
        "total_project_value_eur_bn": round(total_value_millions / 1000, 1),
    }
    with metadata_path.open("w", encoding="utf-8") as fh:
        json.dump(metadata, fh, indent=2)


def parse_args(argv: Sequence[str]) -> argparse.Namespace:
    parser = argparse.ArgumentParser(description="Extract EPEC PPP aggregates by country, sector, and year.")
    parser.add_argument(
        "--out-csv",
        type=Path,
        default=DEFAULT_OUTPUT_CSV,
        help=f"Path to write the CSV output (default: {DEFAULT_OUTPUT_CSV})",
    )
    parser.add_argument(
        "--metadata",
        type=Path,
        default=DEFAULT_METADATA_JSON,
        help=f"Path to write run metadata (default: {DEFAULT_METADATA_JSON})",
    )
    return parser.parse_args(argv)


def main(argv: Sequence[str] | None = None) -> None:
    args = parse_args(argv or sys.argv[1:])
    html = fetch_portal_html()
    filters = extract_filters(html)
    rows = list(iter_rows(filters))
    quickstat_total_projects, quickstat_total_value = fetch_reference_totals(filters)
    summed_projects = sum(row["project_count"] for row in rows)
    summed_value = round(sum(row["project_value_eur_millions"] for row in rows))
    if summed_value != quickstat_total_value:
        raise RuntimeError(
            f"Total project value mismatch: summed rows={summed_value} "
            f"vs quickStat={quickstat_total_value}"
        )
    if summed_projects < quickstat_total_projects:
        raise RuntimeError(
            f"Total project count {summed_projects} is below quickStat {quickstat_total_projects}"
        )
    row_count = write_csv(rows, args.out_csv)
    write_metadata(
        filters,
        args.out_csv,
        args.metadata,
        row_count,
        summed_projects,
        summed_value,
    )
    print(f"Wrote {row_count} rows to {args.out_csv}")


if __name__ == "__main__":
    main()
