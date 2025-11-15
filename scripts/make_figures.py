"""Generate exploratory figures for the EPEC dataset."""
from __future__ import annotations

from pathlib import Path

import matplotlib.pyplot as plt
import pandas as pd
import seaborn as sns

DATA_PATH = Path("data/epec_country_sector_year.csv")
FIG_DIR = Path("figures")
FIG_DIR.mkdir(parents=True, exist_ok=True)


def main() -> None:
    df = pd.read_csv(DATA_PATH)

    yearly = (
        df.groupby("year", as_index=False)
        .agg(projects=("project_count", "sum"), value_eur_m=("project_value_eur_millions", "sum"))
        .sort_values("year")
    )

    sns.set_theme(style="whitegrid")
    fig, ax1 = plt.subplots(figsize=(10, 5))
    ax2 = ax1.twinx()
    ax1.bar(yearly["year"], yearly["projects"], color="#4C72B0", alpha=0.6, label="Projects")
    ax2.plot(yearly["year"], yearly["value_eur_m"], color="#DD8452", label="Value (EUR m)")
    ax1.set_ylabel("Projects closed")
    ax2.set_ylabel("Value (EUR millions)")
    ax1.set_title("PPP Projects and Value Over Time")
    fig.tight_layout()
    fig.legend(loc="upper left", bbox_to_anchor=(0.1, 0.9))
    fig.savefig(FIG_DIR / "projects_value_over_time.png", dpi=200)
    plt.close(fig)

    sector_value = (
        df.groupby("sector", as_index=False)
        .agg(projects=("project_count", "sum"), value_eur_m=("project_value_eur_millions", "sum"))
        .sort_values("value_eur_m", ascending=False)
    )

    fig, ax = plt.subplots(figsize=(10, 6))
    sns.barplot(data=sector_value, y="sector", x="value_eur_m", ax=ax, palette="viridis")
    ax.set_xlabel("Total value (EUR millions)")
    ax.set_ylabel("Sector")
    ax.set_title("Total PPP value by sector (1990-2021)")
    fig.tight_layout()
    fig.savefig(FIG_DIR / "value_by_sector.png", dpi=200)
    plt.close(fig)

    country_projects = (
        df.groupby("country", as_index=False)
        .agg(projects=("project_count", "sum"))
        .sort_values("projects", ascending=False)
        .head(10)
    )

    fig, ax = plt.subplots(figsize=(10, 6))
    sns.barplot(data=country_projects, x="country", y="projects", ax=ax, palette="crest")
    ax.set_ylabel("Projects closed")
    ax.set_xlabel("Country")
    ax.set_title("Top 10 countries by PPP project count (1990-2021)")
    plt.xticks(rotation=45, ha="right")
    fig.tight_layout()
    fig.savefig(FIG_DIR / "projects_by_country.png", dpi=200)
    plt.close(fig)


if __name__ == "__main__":
    main()
