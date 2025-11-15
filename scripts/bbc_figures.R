#!/usr/bin/env Rscript

# Generate 20 BBC-style graphics from the EPEC PPP dataset.

required_packages <- c(
  "tidyverse",
  "bbplot",
  "scales",
  "slider"
)

installed <- rownames(installed.packages())
missing <- required_packages[!required_packages %in% installed]
if (length(missing) > 0) {
  install.packages(missing, repos = "https://cloud.r-project.org")
}

library(tidyverse)
library(bbplot)
library(scales)
library(slider)

data_path <- file.path("data", "epec_country_sector_year.csv")
fig_dir <- file.path("figures")
if (dir.exists(fig_dir)) {
  unlink(fig_dir, recursive = TRUE)
}
dir.create(fig_dir, showWarnings = FALSE, recursive = TRUE)

df <- read_csv(data_path, show_col_types = FALSE) |>
  mutate(
    avg_project_size = if_else(project_count > 0, project_value_eur_millions / project_count, NA_real_),
    decade = paste0(floor(year / 10) * 10, "s")
  )

sector_palette <- c(
  "Defence" = "#6C4E90",
  "Education" = "#1380A1",
  "Environment" = "#0F5499",
  "General Public Services" = "#F6A01A",
  "Healthcare" = "#651A32",
  "Housing and Community Services" = "#A8C686",
  "Public Order and Safety" = "#2E4057",
  "RDI" = "#B25D25",
  "Recreation and Culture" = "#8CA252",
  "Telcos" = "#C70039",
  "Transport" = "#1C5D99"
)

save_bbc_plot <- local({
  i <- 0
  function(plot, slug) {
    i <<- i + 1
    filename <- sprintf("%02d_%s.png", i, slug)
    ggsave(
      filename = file.path(fig_dir, filename),
      plot = plot,
      width = 10,
      height = 6,
      dpi = 300
    )
  }
})

global_year <- df |>
  group_by(year) |>
  summarise(
    projects = sum(project_count, na.rm = TRUE),
    value_m = sum(project_value_eur_millions, na.rm = TRUE),
    .groups = "drop"
  ) |>
  mutate(value_bn = value_m / 1000)

# 1. Annual PPP value
plot1 <- ggplot(global_year, aes(x = year, y = value_bn)) +
  geom_line(color = "#1380A1", linewidth = 1.2) +
  geom_point(color = "#1380A1", size = 1.8) +
  labs(
    title = "PPP value peaked pre-GFC",
    subtitle = "Total PPP project value per year (EUR bn)",
    caption = "Source: EPEC data portal"
  ) +
  bbc_style()
save_bbc_plot(plot1, "value_by_year")

# 2. Annual PPP project counts
plot2 <- ggplot(global_year, aes(x = year, y = projects)) +
  geom_col(fill = "#F6A01A") +
  labs(
    title = "Deal counts fell after 2006",
    subtitle = "Number of PPP projects closed per year",
    caption = "Source: EPEC data portal"
  ) +
  bbc_style()
save_bbc_plot(plot2, "projects_by_year")

# 3. Rolling three-year average value
rolling <- global_year |>
  mutate(
    rolling_value = slide_dbl(value_bn, mean, .before = 2, .complete = FALSE)
  )
plot3 <- ggplot(rolling, aes(x = year, y = rolling_value)) +
  geom_line(color = "#651A32", linewidth = 1.2) +
  labs(
    title = "Rolling PPP value smooths the boom-bust cycle",
    subtitle = "Three-year rolling average of PPP value (EUR bn)",
    caption = "Source: EPEC data portal"
  ) +
  bbc_style()
save_bbc_plot(plot3, "rolling_value")

# 4. Cumulative PPP value
plot4 <- global_year |>
  mutate(cumulative_bn = cumsum(value_bn)) |>
  ggplot(aes(x = year, y = cumulative_bn)) +
  geom_area(fill = "#0F5499", alpha = 0.7) +
  labs(
    title = "Over €400bn of PPP projects since 1990",
    subtitle = "Cumulative PPP value (EUR bn)",
    caption = "Source: EPEC data portal"
  ) +
  bbc_style()
save_bbc_plot(plot4, "cumulative_value")

sector_totals <- df |>
  group_by(sector) |>
  summarise(
    value_bn = sum(project_value_eur_millions, na.rm = TRUE) / 1000,
    projects = sum(project_count, na.rm = TRUE),
    avg_size = if_else(projects > 0, value_bn * 1000 / projects, NA_real_),
    .groups = "drop"
  )

# 5. Sector value totals
plot5 <- ggplot(sector_totals, aes(x = value_bn, y = reorder(sector, value_bn), fill = sector)) +
  geom_col() +
  scale_fill_manual(values = sector_palette, guide = "none") +
  labs(
    title = "Transport dominates PPP value",
    subtitle = "Total PPP value by sector (EUR bn)",
    caption = "Source: EPEC data portal",
    x = NULL,
    y = NULL
  ) +
  bbc_style()
save_bbc_plot(plot5, "sector_value_totals")

# 6. Sector project totals
plot6 <- ggplot(sector_totals, aes(x = projects, y = reorder(sector, projects), fill = sector)) +
  geom_col() +
  scale_fill_manual(values = sector_palette, guide = "none") +
  labs(
    title = "Education leads on project counts",
    subtitle = "Number of PPP projects by sector",
    caption = "Source: EPEC data portal",
    x = NULL,
    y = NULL
  ) +
  bbc_style()
save_bbc_plot(plot6, "sector_project_totals")

# 7. Sector average project size
plot7 <- ggplot(sector_totals, aes(x = avg_size, y = reorder(sector, avg_size), fill = sector)) +
  geom_col() +
  scale_fill_manual(values = sector_palette, guide = "none") +
  labs(
    title = "Average project sizes vary widely",
    subtitle = "Average PPP project size by sector (EUR m)",
    caption = "Source: EPEC data portal",
    x = NULL,
    y = NULL
  ) +
  bbc_style()
save_bbc_plot(plot7, "sector_avg_size")

sector_year_value <- df |>
  group_by(year, sector) |>
  summarise(
    value = sum(project_value_eur_millions, na.rm = TRUE),
    projects = sum(project_count, na.rm = TRUE),
    .groups = "drop"
  )

# 8. Sector share of value over time
plot8 <- sector_year_value |>
  group_by(year) |>
  mutate(share = value / sum(value)) |>
  ggplot(aes(x = year, y = share, fill = sector)) +
  geom_area(position = "stack", alpha = 0.9) +
  scale_y_continuous(labels = percent) +
  scale_fill_manual(values = sector_palette) +
  labs(
    title = "Transport share surged post-2000",
    subtitle = "Sector share of annual PPP value",
    caption = "Source: EPEC data portal",
    x = NULL,
    y = NULL
  ) +
  bbc_style()
save_bbc_plot(plot8, "sector_value_share")

# 9. Sector share of projects over time
plot9 <- sector_year_value |>
  group_by(year) |>
  mutate(share = projects / sum(projects)) |>
  ggplot(aes(x = year, y = share, fill = sector)) +
  geom_area(position = "stack", alpha = 0.9) +
  scale_y_continuous(labels = percent) +
  scale_fill_manual(values = sector_palette) +
  labs(
    title = "Education consistently delivers ~25% of PPP deals",
    subtitle = "Sector share of annual PPP project counts",
    caption = "Source: EPEC data portal",
    x = NULL,
    y = NULL
  ) +
  bbc_style()
save_bbc_plot(plot9, "sector_project_share")

country_totals <- df |>
  group_by(country) |>
  summarise(
    value_bn = sum(project_value_eur_millions, na.rm = TRUE) / 1000,
    projects = sum(project_count, na.rm = TRUE),
    avg_size = if_else(projects > 0, value_bn * 1000 / projects, NA_real_),
    .groups = "drop"
  )

# 10. Top 10 countries by value
plot10 <- country_totals |>
  slice_max(order_by = value_bn, n = 10) |>
  ggplot(aes(x = value_bn, y = reorder(country, value_bn))) +
  geom_col(fill = "#1380A1") +
  labs(
    title = "UK PPP value eclipses all others",
    subtitle = "Top 10 countries by total PPP value (EUR bn)",
    caption = "Source: EPEC data portal",
    x = NULL,
    y = NULL
  ) +
  bbc_style()
save_bbc_plot(plot10, "country_value_top10")

# 11. Top 10 countries by project count
plot11 <- country_totals |>
  slice_max(order_by = projects, n = 10) |>
  ggplot(aes(x = projects, y = reorder(country, projects))) +
  geom_col(fill = "#F6A01A") +
  labs(
    title = "UK also leads on deal volume",
    subtitle = "Top 10 countries by PPP project counts",
    caption = "Source: EPEC data portal",
    x = NULL,
    y = NULL
  ) +
  bbc_style()
save_bbc_plot(plot11, "country_projects_top10")

# 12. Country average project size scatter
plot12 <- country_totals |>
  filter(projects > 0) |>
  slice_max(order_by = avg_size, n = 15) |>
  ggplot(aes(x = projects, y = avg_size, label = country)) +
  geom_point(color = "#651A32", size = 3) +
  geom_text(nudge_y = 20, size = 4, family = "Helvetica") +
  labs(
    title = "Smaller markets often host bigger deals",
    subtitle = "Average PPP project size vs total projects",
    caption = "Source: EPEC data portal",
    x = "Projects since 1990",
    y = "Average project size (EUR m)"
  ) +
  bbc_style()
save_bbc_plot(plot12, "country_avg_size_scatter")

# 13. Sector-year value heatmap
plot13 <- ggplot(sector_year_value, aes(x = year, y = sector, fill = value / 1000)) +
  geom_tile() +
  scale_fill_viridis_c(option = "C", name = "EUR bn") +
  labs(
    title = "Transport booms dominate many years",
    subtitle = "PPP value by sector and year",
    caption = "Source: EPEC data portal",
    x = NULL,
    y = NULL
  ) +
  bbc_style()
save_bbc_plot(plot13, "sector_year_value_heatmap")

# 14. Sector-year project heatmap
plot14 <- ggplot(sector_year_value, aes(x = year, y = sector, fill = projects)) +
  geom_tile() +
  scale_fill_viridis_c(option = "B", name = "Projects") +
  labs(
    title = "Education projects spread evenly",
    subtitle = "PPP project counts by sector and year",
    caption = "Source: EPEC data portal",
    x = NULL,
    y = NULL
  ) +
  bbc_style()
save_bbc_plot(plot14, "sector_year_project_heatmap")

# 15. Country-year value heatmap (top 12)
top_countries <- country_totals |>
  slice_max(order_by = value_bn, n = 12) |>
  pull(country)

top6_countries <- country_totals |>
  slice_max(order_by = value_bn, n = 6) |>
  pull(country)

country_year_value <- df |>
  filter(country %in% top_countries) |>
  group_by(country, year) |>
  summarise(value_bn = sum(project_value_eur_millions, na.rm = TRUE) / 1000, .groups = "drop")

plot15 <- ggplot(country_year_value, aes(x = year, y = country, fill = value_bn)) +
  geom_tile() +
  scale_fill_viridis_c(option = "D", name = "EUR bn") +
  labs(
    title = "PPP value waves differ across countries",
    subtitle = "Annual PPP value for top markets",
    caption = "Source: EPEC data portal",
    x = NULL,
    y = NULL
  ) +
  bbc_style()
save_bbc_plot(plot15, "country_year_value_heatmap")

# 16. UK, France, Spain trend lines
plot16 <- df |>
  filter(country %in% c("United Kingdom", "France", "Spain")) |>
  group_by(country, year) |>
  summarise(value_bn = sum(project_value_eur_millions, na.rm = TRUE) / 1000, .groups = "drop") |>
  ggplot(aes(x = year, y = value_bn, color = country)) +
  geom_line(linewidth = 1.2) +
  scale_color_manual(values = c("United Kingdom" = "#1380A1", "France" = "#F6A01A", "Spain" = "#651A32")) +
  labs(
    title = "UK PPP market dwarfs France and Spain",
    subtitle = "Annual PPP value (EUR bn)",
    caption = "Source: EPEC data portal",
    x = NULL,
    y = NULL
  ) +
  bbc_style()
save_bbc_plot(plot16, "uk_france_spain_trend")

# 17. Small multiples of top 6 countries
plot17 <- df |>
  filter(country %in% top6_countries) |>
  group_by(country, year) |>
  summarise(value_bn = sum(project_value_eur_millions, na.rm = TRUE) / 1000, .groups = "drop") |>
  ggplot(aes(x = year, y = value_bn, fill = country)) +
  geom_area(alpha = 0.8, color = NA) +
  facet_wrap(~country, scales = "free_y") +
  scale_fill_manual(values = rep("#1380A1", 6), guide = "none") +
  labs(
    title = "Different PPP cycles across major countries",
    subtitle = "Annual PPP value (EUR bn)",
    caption = "Source: EPEC data portal",
    x = NULL,
    y = NULL
  ) +
  bbc_style()
save_bbc_plot(plot17, "country_small_multiples")

# 18. Histogram of average project size
plot18 <- df |>
  filter(!is.na(avg_project_size)) |>
  ggplot(aes(avg_project_size)) +
  geom_histogram(binwidth = 50, fill = "#0F5499", color = "white") +
  labs(
    title = "Most contract-year cells average under €200m",
    subtitle = "Distribution of average PPP project size (EUR m)",
    caption = "Source: EPEC data portal",
    x = NULL,
    y = NULL
  ) +
  bbc_style()
save_bbc_plot(plot18, "avg_project_size_hist")

# 19. Country-year value vs project counts
country_year_summary <- df |>
  group_by(country, year) |>
  summarise(
    projects = sum(project_count, na.rm = TRUE),
    value = sum(project_value_eur_millions, na.rm = TRUE),
    .groups = "drop"
  )

plot19 <- ggplot(country_year_summary, aes(x = projects, y = value / 1000)) +
  geom_point(alpha = 0.4, color = "#651A32") +
  geom_smooth(method = "lm", se = FALSE, color = "#1380A1") +
  labs(
    title = "More deals generally mean more value",
    subtitle = "Country-year PPP value vs projects (EUR bn)",
    caption = "Source: EPEC data portal",
    x = "Projects per year",
    y = "Value (EUR bn)"
  ) +
  bbc_style()
save_bbc_plot(plot19, "country_year_scatter")

# 20. Transport share per country (lollipop)
transport_share <- df |>
  group_by(country) |>
  summarise(
    transport_value = sum(if_else(sector == "Transport", project_value_eur_millions, 0), na.rm = TRUE),
    total_value = sum(project_value_eur_millions, na.rm = TRUE),
    share = transport_value / total_value,
    .groups = "drop"
  ) |>
  filter(!is.na(share), total_value > 0) |>
  slice_max(order_by = share, n = 15)

plot20 <- ggplot(transport_share, aes(x = share, y = reorder(country, share))) +
  geom_segment(aes(x = 0, xend = share, yend = country), color = "#cccccc") +
  geom_point(color = "#C70039", size = 3) +
  scale_x_continuous(labels = percent) +
  labs(
    title = "Some markets rely almost entirely on transport PPPs",
    subtitle = "Transport share of PPP value since 1990",
    caption = "Source: EPEC data portal",
    x = NULL,
    y = NULL
  ) +
  bbc_style()
save_bbc_plot(plot20, "transport_share_lollipop")

message("Generated 20 BBC-style figures in ", fig_dir)
