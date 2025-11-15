#!/usr/bin/env Rscript

required_packages <- c("tidyverse", "bbplot", "scales")
installed <- rownames(installed.packages())
missing <- required_packages[!required_packages %in% installed]
if (length(missing) > 0) {
  install.packages(missing, repos = "https://cloud.r-project.org")
}

library(tidyverse)
library(bbplot)
library(scales)

data_path <- file.path("data", "epec_country_sector_year.csv")
fig_dir <- file.path("figures", "bbc")
dir.create(fig_dir, showWarnings = FALSE, recursive = TRUE)

df <- read_csv(data_path, show_col_types = FALSE)

value_year <- df |>
  group_by(year) |>
  summarise(value_bn = sum(project_value_eur_millions, na.rm = TRUE) / 1000) |>
  ungroup()

projects_year <- df |>
  group_by(year) |>
  summarise(projects = sum(project_count, na.rm = TRUE)) |>
  ungroup()

value_sector <- df |>
  group_by(sector) |>
  summarise(value_bn = sum(project_value_eur_millions, na.rm = TRUE) / 1000) |>
  ungroup() |>
  arrange(value_bn)

projects_country <- df |>
  group_by(country) |>
  summarise(projects = sum(project_count, na.rm = TRUE)) |>
  ungroup() |>
  arrange(desc(projects)) |>
  slice_head(n = 10) |>
  arrange(projects)

value_line <- ggplot(value_year, aes(x = year, y = value_bn)) +
  geom_line(color = "#1380A1", linewidth = 1.2) +
  geom_point(color = "#1380A1", size = 2) +
  scale_y_continuous(labels = label_number(suffix = " bn", accuracy = 1),
                     expand = expansion(mult = c(0, 0.05))) +
  labs(
    title = "PPP project value peaked before the financial crisis",
    subtitle = "Total annual PPP project value across all countries and sectors (EUR, 2023 prices)",
    x = NULL,
    y = NULL,
    caption = "Source: EIB EPEC portal"
  ) +
  bbc_style()

ggsave(
  filename = file.path(fig_dir, "bbc_value_by_year.png"),
  plot = value_line,
  width = 10,
  height = 6,
  dpi = 300
)

projects_cols <- ggplot(projects_year, aes(x = year, y = projects)) +
  geom_col(fill = "#F6A01A") +
  scale_y_continuous(expand = expansion(mult = c(0, 0.05))) +
  labs(
    title = "Deal counts surged mid-2000s then cooled",
    subtitle = "Number of PPP projects reaching close each year",
    x = NULL,
    y = NULL,
    caption = "Source: EIB EPEC portal"
  ) +
  bbc_style()

ggsave(
  filename = file.path(fig_dir, "bbc_projects_by_year.png"),
  plot = projects_cols,
  width = 10,
  height = 6,
  dpi = 300
)

sector_bar <- ggplot(value_sector, aes(x = value_bn, y = sector)) +
  geom_col(fill = "#651A32") +
  scale_x_continuous(labels = label_number(suffix = " bn", accuracy = 1)) +
  labs(
    title = "Transport dominates PPP investment value",
    subtitle = "Cumulative PPP project value by sector, 1990-2021",
    x = NULL,
    y = NULL,
    caption = "Source: EIB EPEC portal"
  ) +
  bbc_style()

ggsave(
  filename = file.path(fig_dir, "bbc_value_by_sector.png"),
  plot = sector_bar,
  width = 10,
  height = 6,
  dpi = 300
)

country_bar <- ggplot(projects_country, aes(x = projects, y = country)) +
  geom_col(fill = "#0F5499") +
  labs(
    title = "United Kingdom leads PPP deal flow",
    subtitle = "Top 10 countries by number of PPP projects closed, 1990-2021",
    x = NULL,
    y = NULL,
    caption = "Source: EIB EPEC portal"
  ) +
  bbc_style()

ggsave(
  filename = file.path(fig_dir, "bbc_projects_top_countries.png"),
  plot = country_bar,
  width = 10,
  height = 6,
  dpi = 300
)
