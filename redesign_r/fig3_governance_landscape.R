## Figure 3 | The overdose governance landscape (Nature flagship redesign)
## 183 x 116 mm composite: a governance scatter | b regime tiles (hero n) |
## c 4 facet mini-cards | d case vignette cards | e DODJI by regime
## (violin + box + jitter + mean diamond).
## Data elements & computation identical to redraw_r/fig3_governance_landscape.R
## (QA-passed): calc_ellipse eigen decomposition, set.seed(1) jitter,
## vignettes merge(sort = FALSE), shared facet ylim.
## v3.1 (2026-07-13): panel d note text y-0.45 -> y-0.35 (second line no longer
##   touches the card bottom border).

source("redraw_r/nature_redraw_style.R")
suppressPackageStartupMessages(library(ggrepel))

FS_HERO <- 13

OUT_V2 <- file.path(PROJECT_ROOT, "figures_redraw_nature_v2", "r")

df <- read_csv(file.path(SRC_DIR, "fig3_governance_landscape.csv"),
               show_col_types = FALSE)
regimes <- names(REGIME_COLORS)
df$regime <- factor(df$regime, levels = regimes)

## --------------------------------------------------------- ellipse (R port)
calc_ellipse <- function(x, y, n = 100, sd = 2.0) {
  if (length(x) < 3) return(NULL)
  covm <- cov(cbind(x, y))
  mn <- c(mean(x), mean(y))
  ev <- eigen(covm, symmetric = TRUE)
  vals <- pmax(ev$values, 0)
  vec <- ev$vectors
  ang <- atan2(vec[2, 1], vec[1, 1])
  t <- seq(0, 2 * pi, length.out = n)
  wx <- sd * sqrt(vals[1]) * cos(t)
  wy <- sd * sqrt(vals[2]) * sin(t)
  xr <- wx * cos(ang) - wy * sin(ang)
  yr <- wx * sin(ang) + wy * cos(ang)
  data.frame(x = mn[1] + xr, y = mn[2] + yr)
}

LW_ELL <- pt2mm(1.0)

title_theme <- function(hjust = 0.5) {
  theme(plot.title = element_text(size = FS_TITLE, face = "bold",
                                  colour = PAL$neutral_black, family = TNR,
                                  hjust = hjust, lineheight = 0.95,
                                  margin = margin(b = 3, unit = "pt")))
}

## --------------------------------------------------------- panel a: scatter
mk_scatter <- function(df) {
  med_mort <- median(df$mortality_rank); med_dodj <- median(df$dodji_score)
  ells <- do.call(rbind, lapply(regimes, function(r) {
    g <- df[df$regime == r, ]
    e <- calc_ellipse(g$mortality_rank, g$dodji_score, sd = 2)
    if (is.null(e)) return(NULL)
    e$regime <- r; e
  }))
  xmin <- min(df$mortality_rank); xmax <- max(df$mortality_rank)
  ymin <- min(df$dodji_score); ymax <- max(df$dodji_score)
  px <- (xmax - xmin) * 0.02; py <- (ymax - ymin) * 0.05
  quad <- data.frame(
    x = c(xmin + px, xmax - px, xmin + px, xmax - px),
    y = c(ymax - py, ymax - py, ymin + py, ymin + py),
    lab = c("Lower burden\n+ protected", "Lower burden\n+ surveillance concern",
            "Weak visibility\n+ low reported rates", "Visible high burden\n+ implementation"),
    col = c(PAL$green_3, PAL$gold, PAL$red_strong, PAL$blue_main),
    h = c(0, 1, 0, 1), v = c(1, 1, 0, 0))
  ## quadrant background tints (alpha <= 0.06), split at the medians
  quad_bg <- data.frame(
    xmin = c(-Inf, med_mort, -Inf, med_mort),
    xmax = c(med_mort, Inf, med_mort, Inf),
    ymin = c(med_dodj, med_dodj, -Inf, -Inf),
    ymax = c(Inf, Inf, med_dodj, med_dodj),
    col = c(PAL$green_3, PAL$gold, PAL$red_strong, PAL$blue_main))
  ## representative countries for direct labelling
  rep_cty <- c("Iceland", "United States of America", "Estonia",
               "Slovenia", "Albania")
  rep_df <- df[df$country %in% rep_cty, ]
  rep_df$lab <- cshort(rep_df$country)
  rep_df$col <- REGIME_COLORS[as.character(rep_df$regime)]

  ggplot(df, aes(mortality_rank, dodji_score)) +
    geom_rect(data = quad_bg, aes(xmin = xmin, xmax = xmax,
                                  ymin = ymin, ymax = ymax),
              fill = quad_bg$col, alpha = 0.05, colour = NA,
              inherit.aes = FALSE) +
    geom_path(data = ells, aes(x, y, colour = regime), linetype = "dashed",
              linewidth = LW_ELL, alpha = 0.75, inherit.aes = FALSE) +
    geom_vline(xintercept = med_mort, colour = PAL$neutral_mid,
               linewidth = pt2mm(0.8), linetype = "dashed") +
    geom_hline(yintercept = med_dodj, colour = PAL$neutral_mid,
               linewidth = pt2mm(0.8), linetype = "dashed") +
    geom_point(aes(colour = regime, shape = regime, size = priority_score),
               alpha = 0.85) +
    scale_size_continuous(range = c(0.5, 1.8), guide = "none") +
    scale_colour_manual(values = REGIME_COLORS, guide = "none") +
    scale_shape_manual(values = REGIME_MARKERS, guide = "none") +
    geom_text_repel(data = rep_df, aes(label = lab), colour = rep_df$col,
                    size = ggpt(FS_TINY), fontface = "bold", family = TNR,
                    seed = 1, box.padding = 0.3, point.padding = 0.15,
                    segment.size = 0.25, segment.colour = PAL$neutral_mid,
                    min.segment.length = 0, max.overlaps = Inf,
                    show.legend = FALSE) +
    geom_text(data = quad, aes(x, y, label = lab), colour = quad$col,
              hjust = quad$h, vjust = quad$v, size = ggpt(FS_TINY),
              fontface = "bold", lineheight = 0.85, family = TNR,
              inherit.aes = FALSE) +
    labs(title = "47 countries resolve into four governance regimes",
         x = "Mortality burden rank (1 = highest)", y = "DODJI score",
         tag = "a") +
    theme_nature() + title_theme() +
    theme(axis.title = element_text(size = FS_TICK, face = "bold",
                                    colour = PAL$neutral_black, family = TNR))
}

## --------------------------------------------------------- panel b: tiles
mk_tiles <- function(df) {
  counts <- as.data.frame(table(df$regime)); names(counts) <- c("regime", "n")
  counts$regime <- factor(counts$regime, levels = regimes)
  counts <- counts[order(counts$regime), ]
  n_r <- nrow(counts)
  counts$y <- seq(n_r, 1)
  counts$lab <- REGIME_ONELINE[as.character(counts$regime)]
  counts$col <- REGIME_COLORS[as.character(counts$regime)]
  left <- 0.4; right <- 9.6
  ggplot(counts) +
    geom_rect(aes(xmin = left, xmax = right, ymin = y - 0.46, ymax = y + 0.46),
              fill = counts$col, colour = "white", linewidth = pt2mm(1.2)) +
    geom_rect(aes(xmin = left, xmax = left + 0.22, ymin = y - 0.46, ymax = y + 0.46),
              fill = "white", alpha = 0.30, colour = NA) +
    geom_text(aes(x = left + 0.5, y = y, label = lab), hjust = 0, size = ggpt(FS_TICK),
              fontface = "bold", colour = "white", family = TNR) +
    geom_text(aes(x = right - 0.45, y = y + 0.10, label = n), hjust = 1,
              size = ggpt(FS_HERO), fontface = "bold", colour = "white",
              family = TNR) +
    geom_text(aes(x = right - 0.45, y = y - 0.30, label = "countries"), hjust = 1,
              size = ggpt(FS_TINY), colour = "white", alpha = 0.92, family = TNR) +
    scale_x_continuous(limits = c(0, 10), expand = c(0, 0)) +
    scale_y_continuous(limits = c(0.5, n_r + 0.5), expand = c(0, 0)) +
    labs(title = "Regime sizes: 24 of 47 countries are low-burden / protected",
         tag = "b") +
    theme_void_nature() + title_theme(hjust = 0.5) +
    theme(plot.margin = margin(3, 3, 3, 3, "pt"))
}

## --------------------------------------------------------- panel c: facets
## shared ylim across all four facets (data range +/- 6%, plus title-bar headroom)
Y_LIM_DATA <- range(df$dodji_score) + c(-1, 1) * diff(range(df$dodji_score)) * 0.06
BAR_H <- diff(Y_LIM_DATA) * 0.14
Y_LIM_FACET <- c(Y_LIM_DATA[1], Y_LIM_DATA[2] + BAR_H)

mk_facet <- function(df, regime, ylab = FALSE) {
  g <- df[df$regime == regime, ]
  ell <- calc_ellipse(g$mortality_rank, g$dodji_score, sd = 1.5)
  x_mid <- mean(range(g$mortality_rank))
  p <- ggplot(g, aes(mortality_rank, dodji_score)) +
    geom_point(colour = REGIME_COLORS[[regime]], shape = REGIME_MARKERS[[regime]],
               alpha = 0.8, size = 1.8) +
    coord_cartesian(ylim = Y_LIM_FACET) +
    labs(x = "Mortality rank", y = if (ylab) "DODJI score" else NULL) +
    theme_nature() +
    theme(axis.title = element_text(size = FS_TINY, face = "bold",
                                    colour = PAL$neutral_black, family = TNR),
          axis.text = element_text(size = FS_TINY))
  if (!ylab) {
    p <- p + theme(axis.text.y = element_blank(), axis.ticks.y = element_blank())
  }
  if (!is.null(ell)) {
    p <- p + geom_path(data = ell, aes(x, y), colour = PAL$neutral_mid,
                       linetype = "dashed", linewidth = LW_ELL, alpha = 0.5,
                       inherit.aes = FALSE)
  }
  ## regime-colour title bar (mini-card header), drawn last, per-facet centred
  p <- p +
    annotate("rect", xmin = -Inf, xmax = Inf,
             ymin = Y_LIM_DATA[2], ymax = Y_LIM_FACET[2],
             fill = REGIME_COLORS[[regime]], colour = NA) +
    annotate("text", x = x_mid,
             y = (Y_LIM_DATA[2] + Y_LIM_FACET[2]) / 2,
             label = REGIME_ONELINE[[regime]], colour = "white",
             fontface = "bold", size = ggpt(FS_SMALL), family = TNR)
  p
}

## --------------------------------------------------------- panel d: vignettes
mk_vignettes <- function(df) {
  vig <- data.frame(
    country = c("Iceland", "United States of America", "Estonia", "Slovenia"),
    note = c("Small population, strong surveillance;\nhigh mortality triggers implementation",
             "Visible crisis; dominant need is\nreal-time toxicology & service linkage",
             "High burden paired with\nabove-median surveillance concern",
             "Moderate burden, weak visibility;\npriority reclassified upward"),
    stringsAsFactors = FALSE)
  vig <- merge(vig, df[, c("country", "regime", "dodji_score",
                           "combined_priority_rank")],
               by = "country", all.x = TRUE, sort = FALSE)
  vig$col <- REGIME_COLORS[as.character(vig$regime)]
  vig$y <- 8.7 - 2.15 * (seq_len(nrow(vig)) - 1)
  vig$short <- cshort(vig$country)
  vig$stat <- paste0("Priority rank #", vig$combined_priority_rank,
                     "  \u00b7  DODJI ", sprintf("%.2f", vig$dodji_score))
  ggplot(vig) +
    geom_rect(aes(xmin = 0.25, xmax = 9.75, ymin = y - 1.02, ymax = y + 1.02),
              fill = vig$col, alpha = 0.06, colour = vig$col,
              linewidth = pt2mm(0.9)) +
    geom_point(aes(0.85, y + 0.45), colour = vig$col, size = 1.8) +
    geom_text(aes(1.6, y + 0.45, label = short), hjust = 0, size = ggpt(FS_SMALL),
              fontface = "bold", colour = PAL$neutral_black, family = TNR) +
    geom_text(aes(9.45, y + 0.45, label = stat), hjust = 1, size = ggpt(FS_TINY),
              fontface = "bold", colour = vig$col, family = TNR) +
    geom_text(aes(1.6, y - 0.35, label = note), hjust = 0, size = ggpt(FS_TINY),
              colour = PAL$neutral_mid, family = TNR, lineheight = 0.95) +
    scale_x_continuous(limits = c(0, 10), expand = c(0, 0)) +
    scale_y_continuous(limits = c(0, 10), expand = c(0, 0)) +
    labs(title = "Vignettes: regime membership reorders country priorities",
         tag = "d") +
    theme_void_nature() + title_theme(hjust = 0.5) +
    theme(plot.margin = margin(3, 3, 3, 3, "pt"))
}

## ------------------------------------------------ panel e: violin + box + jitter
mk_violin <- function(df) {
  set.seed(1)
  counts <- as.data.frame(table(df$regime)); names(counts) <- c("regime", "n")
  counts$regime <- factor(counts$regime, levels = regimes)
  counts <- counts[order(counts$regime), ]
  ymax_g <- tapply(df$dodji_score, df$regime, max)[as.character(counts$regime)]
  counts$ylab <- ymax_g + diff(range(df$dodji_score)) * 0.09
  red_mean <- mean(df$dodji_score[df$regime == "Insufficient exposure data"])
  y_top <- max(df$dodji_score)
  ggplot(df, aes(regime, dodji_score, fill = regime)) +
    geom_violin(alpha = 0.3, colour = NA, width = 0.7, trim = FALSE) +
    geom_boxplot(width = 0.35, fill = NA, colour = PAL$neutral_black,
                 outlier.shape = NA, linewidth = pt2mm(1.0)) +
    stat_summary(fun = mean, geom = "point", shape = 23, size = 2.0,
                 fill = "white", colour = PAL$neutral_black, stroke = 0.55) +
    geom_point(aes(colour = regime, shape = regime),
               position = position_jitter(width = 0.12, height = 0, seed = 1),
               alpha = 0.5, size = 1.1) +
    geom_text(data = counts, aes(x = regime, y = ylab, label = paste0("n = ", n)),
              size = ggpt(FS_TINY), colour = PAL$neutral_dark, family = TNR,
              fontface = "bold", inherit.aes = FALSE) +
    scale_fill_manual(values = REGIME_COLORS, guide = "none") +
    scale_colour_manual(values = REGIME_COLORS, guide = "none") +
    scale_shape_manual(values = REGIME_MARKERS, guide = "none") +
    scale_x_discrete(labels = REGIME_ONELINE) +
    geom_hline(yintercept = 0, colour = PAL$neutral_mid,
               linewidth = pt2mm(1.0), linetype = "dashed") +
    coord_cartesian(ylim = c(NA, y_top * 1.22)) +
    labs(title = "Insufficient exposure data carry the highest DODJI scores",
         x = NULL, y = "DODJI score", tag = "e") +
    theme_nature() + title_theme() +
    theme(axis.title.y = element_text(size = FS_TICK, face = "bold",
                                      colour = PAL$neutral_black, family = TNR),
          axis.text.x = element_text(size = FS_TINY, face = "bold",
                                     colour = PAL$neutral_dark, family = TNR,
                                     angle = 18, hjust = 1, vjust = 1))
}

## ------------------------------------------------------------- assemble
p_a <- mk_scatter(df)
p_b <- mk_tiles(df)
p_c <- plot_grid(mk_facet(df, regimes[1], ylab = TRUE),
                 mk_facet(df, regimes[2]), mk_facet(df, regimes[3]),
                 mk_facet(df, regimes[4]), nrow = 1,
                 labels = "c", label_fontfamily = TNR, label_fontface = "bold",
                 label_size = FS_TAG)
p_d <- mk_vignettes(df)
p_e <- mk_violin(df)

top <- plot_grid(p_a, p_b, nrow = 1)
bot <- plot_grid(p_d, p_e, nrow = 1)
full <- plot_grid(top, p_c, bot, ncol = 1, rel_heights = c(1, 1.05, 1))

save_pub(full, OUT_V2, "Figure3_governance_landscape_nature", 183, 116)
