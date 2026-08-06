## Figure 2 (redesign) | Priority reordering after adding surveillance credibility
## Flagship-grade visual redesign of redraw_r/fig2_priority_reordering.R.
## ALL data elements and computations are preserved verbatim from the base
## (QA-passed) script; only the visual layer is upgraded:
##   story-first conclusion titles, mute-and-highlight colour discipline,
##   direct annotation instead of legends, hero numbers, tier bands,
##   median-shift arrow, bold zero line.
##
## Run from the PROJECT ROOT:
##   "C:/Program Files/R/R-4.4.2/bin/Rscript.exe" redesign_r/fig2_priority_reordering.R

source(file.path("redraw_r", "nature_redraw_style.R"))
suppressPackageStartupMessages(library(ggrepel))

OUT_R2 <- file.path(PROJECT_ROOT, "figures_redraw_nature_v2", "r")

FS_HERO <- 13   ## new step in the type ladder, reserved for hero numbers

## Highlight sets reproduced from the Python authoritative build
## (pandas sample(random_state=42) for the 10 stable countries).
HL_STABLE <- c("Belarus", "Belgium", "Croatia", "Cyprus", "Iceland", "Italy",
               "Latvia", "Poland", "Republic of Moldova", "Turkey")

RECLASS_COLORS <- c("Up >=10" = PAL$red_strong, "Stable" = PAL$neutral_mid,
                    "Down >=10" = PAL$blue_main)
RECLASS_LINES <- c("Up >=10" = "solid", "Stable" = "dotted", "Down >=10" = "dashed")

GRAY_BG <- "#BFBFBF"   ## muted background grey (stable, non-highlight)
GRAY_ST <- "#8C8C8C"   ## muted grey for the hard-coded stable highlight set

TITLE_THEME <- theme(
  plot.title = element_text(face = "bold", size = FS_TITLE, family = TNR,
                            colour = PAL$neutral_black, margin = margin(b = 2)),
  plot.subtitle = element_text(size = FS_SMALL, family = TNR,
                               colour = PAL$neutral_mid, margin = margin(b = 3))
)

## ------------------------------------------------------------- panel a — slope
mk_slope <- function(df) {
  up_df <- df %>% filter(reclassification == "Up >=10")
  down_df <- df %>% filter(reclassification == "Down >=10")
  st_all <- df %>% filter(reclassification == "Stable")
  st_hl <- st_all %>% filter(country %in% HL_STABLE)
  mover_df <- bind_rows(up_df, down_df) %>%
    arrange(mortality_rank) %>%
    mutate(short = cshort(country))
  yl <- c(min(df$mortality_rank) - 2, max(df$mortality_rank) + 2)

  ggplot() +
    ## every stable country: thin muted grey line (all 27 drawn; 47 total preserved)
    geom_segment(data = st_all,
                 aes(x = 0, xend = 1, y = mortality_rank, yend = combined_priority_rank),
                 colour = GRAY_BG, linewidth = pt2mm(0.45), alpha = 0.75,
                 linetype = "dotted") +
    ## hard-coded stable highlight set: slightly darker thin grey
    geom_segment(data = st_hl,
                 aes(x = 0, xend = 1, y = mortality_rank, yend = combined_priority_rank),
                 colour = GRAY_ST, linewidth = pt2mm(0.7), alpha = 0.9,
                 linetype = "dotted") +
    ## movers: full-saturation Okabe-Ito, bold
    geom_segment(data = mover_df,
                 aes(x = 0, xend = 1, y = mortality_rank, yend = combined_priority_rank,
                     colour = reclassification, linetype = reclassification),
                 linewidth = pt2mm(1.4), alpha = 0.95) +
    geom_point(data = st_hl, aes(x = 0, y = mortality_rank),
               colour = GRAY_ST, size = 0.9) +
    geom_point(data = st_hl, aes(x = 1, y = combined_priority_rank),
               colour = GRAY_ST, size = 0.9) +
    geom_point(data = mover_df, aes(x = 0, y = mortality_rank,
                                    colour = reclassification), size = 1.6) +
    geom_point(data = mover_df, aes(x = 1, y = combined_priority_rank,
                                    colour = reclassification), size = 1.6) +
    ## direct country labels at both ends (repelled along the rank axis)
    geom_text_repel(data = mover_df,
                    aes(x = 0, y = mortality_rank, label = short,
                        colour = reclassification),
                    nudge_x = -0.09, direction = "y", hjust = 1,
                    xlim = c(-Inf, -0.06), size = ggpt(FS_TINY), fontface = "bold",
                    family = TNR, segment.colour = "grey75",
                    segment.size = pt2mm(0.3), box.padding = 0.10,
                    point.padding = 0.06, max.overlaps = Inf, seed = 42,
                    show.legend = FALSE) +
    geom_text_repel(data = mover_df,
                    aes(x = 1, y = combined_priority_rank, label = short,
                        colour = reclassification),
                    nudge_x = 0.09, direction = "y", hjust = 0,
                    xlim = c(1.06, Inf), size = ggpt(FS_TINY), fontface = "bold",
                    family = TNR, segment.colour = "grey75",
                    segment.size = pt2mm(0.3), box.padding = 0.10,
                    point.padding = 0.06, max.overlaps = Inf, seed = 42,
                    show.legend = FALSE) +
    scale_colour_manual(values = RECLASS_COLORS) +
    scale_linetype_manual(values = RECLASS_LINES) +
    guides(colour = "none", linetype = "none") +
    scale_x_continuous(limits = c(-0.25, 1.25), breaks = c(0, 1),
                       labels = c("Mortality-only\nrank", "DODJI-informed\npreparedness rank")) +
    scale_y_reverse(limits = yl) +
    labs(title = "Surveillance credibility reshuffles preparedness priorities",
         subtitle = "red: up \u226510 ranks \u00b7 blue: down \u226510 \u00b7 grey: stable",
         x = NULL, y = "Rank (1 = highest priority)", tag = "a") +
    coord_cartesian(clip = "off") +
    theme_nature() + TITLE_THEME +
    theme(axis.text.x = element_text(face = "bold", size = FS_TICK, family = TNR,
                                     colour = PAL$neutral_black),
          axis.title = element_text(size = FS_TICK),
          ## wide side margins act as the gutter for country labels (clip off)
          plot.margin = margin(4, 34, 4, 30, "pt"))
}

## ------------------------------------------------------- panel b — hero counts
mk_summary <- function(df) {
  up_n <- sum(df$reclassification == "Up >=10")
  down_n <- sum(df$reclassification == "Down >=10")
  stable_n <- sum(df$reclassification == "Stable")
  blocks <- data.frame(
    y = c(7.30, 4.90, 2.50),
    color = c(PAL$red_strong, PAL$blue_main, PAL$neutral_mid),
    num = c(up_n, down_n, stable_n),
    lab = c("countries up\n\u226510 ranks", "countries down\n\u226510 ranks",
            "countries\nremain stable")
  )
  h <- 2.1
  ggplot(blocks) +
    ## zone tint at alpha <= 0.06
    geom_rect(aes(xmin = 0.35, xmax = 9.65, ymin = y - h / 2, ymax = y + h / 2),
              fill = blocks$color, alpha = 0.06, colour = NA) +
    ## colour chip
    geom_rect(aes(xmin = 0.60, xmax = 1.70, ymin = y - 0.72, ymax = y + 0.72),
              fill = blocks$color, colour = NA) +
    ## hero number
    geom_text(aes(x = 2.15, y = y, label = num), hjust = 0, vjust = 0.5,
              size = ggpt(FS_HERO), fontface = "bold", colour = blocks$color,
              family = TNR) +
    ## direct label
    geom_text(aes(x = 4.05, y = y, label = lab), hjust = 0, vjust = 0.5,
              size = ggpt(FS_SMALL), fontface = "bold", colour = PAL$neutral_black,
              family = TNR, lineheight = 0.95) +
    scale_x_continuous(limits = c(0, 10)) + scale_y_continuous(limits = c(0, 10)) +
    labs(tag = "b") + theme_void_nature()
}

## ------------------------------------------------------- panel c — priority tiers
mk_tiers <- function(df) {
  r <- df$combined_priority_rank
  tiers <- data.frame(
    tier = paste0("Priority ", c("I", "II", "III", "IV")),
    rng = c("rank 1\u20138", "rank 9\u201317", "rank 18\u201334", "rank 35\u201347"),
    count = c(sum(r <= 8), sum(r >= 9 & r <= 17), sum(r >= 18 & r <= 34), sum(r >= 35)),
    color = PRIORITY_COLORS,
    y = c(8.0, 5.9, 3.8, 1.7)
  )
  h <- 1.7
  ggplot(tiers) +
    ## descending-priority arrow guiding the eye I -> IV
    annotate("segment", x = 0.42, xend = 0.42, y = 8.85, yend = 0.72,
             colour = PAL$neutral_mid, linewidth = pt2mm(0.8),
             arrow = grid::arrow(length = grid::unit(1.6, "mm"), type = "closed")) +
    ## coloured tier bands, solid fill (no hatch), direct labels
    geom_rect(aes(xmin = 0.85, xmax = 9.45, ymin = y - h / 2, ymax = y + h / 2),
              fill = tiers$color, colour = "white", linewidth = pt2mm(1.0)) +
    geom_text(aes(x = 1.40, y = y + 0.30, label = tier), hjust = 0, size = ggpt(7),
              fontface = "bold", colour = "white", family = TNR) +
    geom_text(aes(x = 1.40, y = y - 0.34, label = rng), hjust = 0, size = ggpt(5),
              colour = "white", family = TNR) +
    geom_text(aes(x = 9.15, y = y, label = paste0("n=", count)), hjust = 1,
              size = ggpt(9), fontface = "bold", colour = "white", family = TNR) +
    scale_x_continuous(limits = c(0, 10)) + scale_y_continuous(limits = c(0, 10)) +
    labs(tag = "c") + theme_void_nature()
}

## ------------------------------------------------- panel d — rank-shift histogram
mk_histogram <- function(df) {
  brks <- seq(-45, 50, 5)
  h <- hist(df$rank_shift, breaks = brks, plot = FALSE)
  hd <- data.frame(mid = h$mids, left = brks[-length(brks)], dens = h$density)
  hd$fill <- ifelse(hd$left >= 10, PAL$red_strong,
                    ifelse(hd$left + 5 <= -10, PAL$blue_main, PAL$neutral_mid))
  hd$ht <- ifelse(hd$left >= 10, 1, ifelse(hd$left + 5 <= -10, -1, 0))
  kde <- density(df$rank_shift, from = min(df$rank_shift) - 2,
                 to = max(df$rank_shift) + 2, n = 200)
  kd <- data.frame(x = kde$x, y = kde$y)
  ymax <- max(hd$dens, kd$y) * 1.05
  med <- median(df$rank_shift)

  half <- 5 * 0.92 / 2
  ## screen-space 45 deg hatch: data-slope = (w/x_span) / (h/y_span) with the
  ## panel ~ 62 x 34 mm and x_span = 97; spacing 2.0 x-units ~ 1.3 mm stripes.
  hatch_slope <- (62 / 97) / (34 / ymax)
  segs <- do.call(rbind, lapply(seq_len(nrow(hd)), function(i) {
    if (hd$ht[i] == 0) return(NULL)
    hatch_segments(hd$mid[i] - half, hd$mid[i] + half, hd$dens[i],
                   spacing = 2.0, slope = hd$ht[i] * hatch_slope)
  }))

  up_n <- sum(df$rank_shift >= 10); down_n <- sum(df$rank_shift <= -10)

  ggplot() +
    geom_col(data = hd, aes(x = mid, y = dens), width = 5 * 0.92, fill = hd$fill,
             colour = "#333333", linewidth = pt2mm(0.5), alpha = 0.85) +
    {if (!is.null(segs)) geom_segment(data = segs, aes(x = x, xend = xend, y = y, yend = yend),
                                      colour = "#333333", linewidth = pt2mm(0.4), alpha = 0.8)} +
    geom_line(data = kd, aes(x = x, y = y), colour = PAL$neutral_black,
              linewidth = pt2mm(0.8)) +
    ## bold zero line (median coincides with it)
    geom_vline(xintercept = 0, colour = PAL$neutral_black, linewidth = pt2mm(1.1)) +
    geom_vline(xintercept = 10, colour = PAL$red_strong, linewidth = pt2mm(0.6),
               linetype = "dotted") +
    geom_vline(xintercept = -10, colour = PAL$blue_main, linewidth = pt2mm(0.6),
               linetype = "dotted") +
    ## median-shift arrow + value (free zone right of zero, clear of bars/boxes)
    annotate("text", x = 11, y = ymax * 0.93,
             label = paste0("median\n= ", med), size = ggpt(FS_SMALL),
             fontface = "bold", colour = PAL$neutral_black, family = TNR,
             lineheight = 0.9) +
    annotate("curve", x = 9.5, y = ymax * 0.85, xend = med + 0.8, yend = ymax * 0.66,
             curvature = 0.45, colour = PAL$neutral_dark, linewidth = pt2mm(0.6),
             arrow = grid::arrow(length = grid::unit(1.5, "mm"), type = "closed")) +
    scale_x_continuous(breaks = seq(-40, 40, 10), limits = c(-46, 51)) +
    scale_y_continuous(limits = c(0, ymax), expand = c(0, 0)) +
    labs(title = "Shifts pile near zero; extremes reach +42/\u221238",
         x = "Rank shift (mortality rank \u2212 DODJI-informed rank)", y = "Density",
         tag = "d") +
    theme_nature() + TITLE_THEME +
    theme(axis.title = element_text(size = FS_TICK))
}

main <- function() {
  df <- read_csv(file.path(SRC_DIR, "fig2_priority_reordering.csv"), show_col_types = FALSE)
  p_a <- mk_slope(df)
  p_b <- mk_summary(df)
  p_c <- mk_tiers(df)
  p_d <- mk_histogram(df)
  right <- plot_grid(plot_grid(p_b, p_c, nrow = 1), p_d, ncol = 1)
  full <- plot_grid(p_a, right, nrow = 1, rel_widths = c(3, 2))
  save_pub(full, OUT_R2, "Figure2_priority_reordering_nature", 183, 108)
}

main()
