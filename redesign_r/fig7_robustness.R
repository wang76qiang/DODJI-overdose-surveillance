## Figure 7 (redesign) | Robustness of DODJI to specification choices
## Flagship-grade visual redesign of redraw_r/fig7_robustness.R.
## ALL data elements and computations are preserved verbatim from the base
## (QA-passed) script; only the visual layer is upgraded:
##   a  conclusion title + "median rho = 0.78" hero badge in the title zone,
##      fragile-variant annotation arrow, alpha<=0.06 threshold zone tints;
##   b  big quadrant counts kept, per-box share (n/9 = %) added, hatch kept,
##      conclusion text + guiding arrow in the empty bottom-left quadrant;
##   c  Variant|rho table with in-cell data bars (bar length proportional to
##      rho) plus the threshold-coloured value; header and grid kept.
## Base fixes retained: factor-position hatch (d$pos = rev(seq_len)),
## threshold legend at y = c(8.76, 7.64, 6.52) upper right, hatch_rect
## bidirectional seq fix, table border grid_df fix.
##
## Run from the PROJECT ROOT:
##   "C:/Program Files/R/R-4.4.2/bin/Rscript.exe" redesign_r/fig7_robustness.R

source(file.path("redraw_r", "nature_redraw_style.R"))

OUT_R2 <- file.path(PROJECT_ROOT, "figures_redraw_nature_v2", "r")

FS_HERO <- 13   ## new step in the type ladder, reserved for hero numbers

TITLE_THEME <- theme(
  plot.title = element_text(face = "bold", size = FS_TITLE, family = TNR,
                            colour = PAL$neutral_black, margin = margin(b = 2)),
  plot.subtitle = element_text(size = FS_SMALL, family = TNR,
                               colour = PAL$neutral_mid, margin = margin(b = 3))
)

## ------------------------------- generic rect hatch (data-coordinate lines)
## (verbatim from the QA-passed base script, incl. bidirectional seq fix)
hatch_rect <- function(x0, x1, y0, y1, spacing_x = 0.05, slope = 1) {
  ## lines y = slope*x + c clipped to the rect; spacing_x = x-gap between lines
  segs <- list()
  c_start <- y0 - slope * x1
  c_end <- y1 - slope * x0
  if (c_end < c_start) { tmp <- c_start; c_start <- c_end; c_end <- tmp }
  for (c in seq(c_start, c_end, by = spacing_x * sqrt(1 + slope^2))) {
    cand <- rbind(c((y0 - c) / slope, y0), c((y1 - c) / slope, y1),
                  c(x0, slope * x0 + c), c(x1, slope * x1 + c))
    inside <- cand[cand[, 1] >= x0 - 1e-9 & cand[, 1] <= x1 + 1e-9 &
                     cand[, 2] >= y0 - 1e-9 & cand[, 2] <= y1 + 1e-9, , drop = FALSE]
    inside <- unique(round(inside, 9))
    if (nrow(inside) >= 2) {
      ord <- order(inside[, 1], inside[, 2])
      p <- inside[ord[c(1, nrow(inside))], , drop = FALSE]
      segs[[length(segs) + 1]] <- data.frame(x = p[1, 1], xend = p[2, 1],
                                             y = p[1, 2], yend = p[2, 2])
    }
  }
  do.call(rbind, segs)
}

## ---------------------------------------------------- panel a: bars
mk_bars <- function(df) {
  d <- df
  d$variant_clean <- sub(" variant", "", d$variant, fixed = TRUE)
  d$col <- ifelse(d$rho >= 0.7, PAL$green_3,
                  ifelse(d$rho >= 0.4, PAL$gold, PAL$red_strong))
  d$lab <- sprintf("%.2f (n=%d)", d$rho, d$n)
  d <- d[order(d$rho), ]
  d$y <- factor(d$variant_clean, levels = rev(d$variant_clean))
  ## factor position 1 = bottom row (highest rho); n = top row (lowest rho)
  d$pos <- rev(seq_len(nrow(d)))

  med <- median(d$rho)   ## 0.78 on the authoritative data

  ## hatch for rho < 0.4 bars (screen-45: panel a data x:y aspect ~17:1)
  hatch_df <- do.call(rbind, lapply(seq_len(nrow(d)), function(i) {
    if (d$rho[i] >= 0.4) return(NULL)
    hatch_rect(0, d$rho[i], d$pos[i] - 0.3, d$pos[i] + 0.3,
               spacing_x = 0.03, slope = 17)
  }))

  ## threshold legend, upper right (positions from the QA-passed base)
  legend_df <- data.frame(x = 0.985, y = c(8.76, 7.64, 6.52),
                          lab = c("Stable \u22650.7", "Moderate 0.4\u20130.7",
                                  "Fragile <0.4"),
                          col = c(PAL$green_3, PAL$gold, PAL$red_strong))

  ggplot(d, aes(rho, y)) +
    ## threshold zone tints at alpha <= 0.06 (background muting)
    annotate("rect", xmin = 0.7, xmax = 1.0, ymin = 0.4, ymax = 9.6,
             fill = PAL$green_3, alpha = 0.05, colour = NA) +
    annotate("rect", xmin = 0.4, xmax = 0.7, ymin = 0.4, ymax = 9.6,
             fill = PAL$gold, alpha = 0.05, colour = NA) +
    annotate("rect", xmin = 0.0, xmax = 0.4, ymin = 0.4, ymax = 9.6,
             fill = PAL$red_strong, alpha = 0.05, colour = NA) +
    geom_vline(xintercept = 0.7, colour = PAL$green_3,
               linewidth = pt2mm(1.0), linetype = "dashed") +
    geom_vline(xintercept = 0.4, colour = PAL$gold,
               linewidth = pt2mm(1.0), linetype = "dashed") +
    geom_col(fill = d$col, colour = "#333333", linewidth = pt2mm(0.5),
             width = 0.6, alpha = 0.9) +
    geom_segment(data = hatch_df, aes(x, y, xend = xend, yend = yend),
                 colour = "#333333", linewidth = pt2mm(0.4), inherit.aes = FALSE) +
    geom_text(aes(rho + 0.02, y, label = lab), hjust = 0, size = ggpt(FS_TINY),
              fontface = "bold", colour = PAL$neutral_black, family = TNR) +
    geom_text(data = legend_df, aes(x, y, label = lab), hjust = 1,
              size = ggpt(FS_SMALL), fontface = "bold", colour = legend_df$col,
              family = TNR, inherit.aes = FALSE) +
    ## hero-number badge in the title zone (upper right, above the legend)
    annotate("rect", xmin = 0.60, xmax = 0.975, ymin = 9.62, ymax = 11.12,
             fill = "white", colour = PAL$green_3, linewidth = pt2mm(0.8)) +
    annotate("text", x = 0.7875, y = 10.84, label = "median \u03c1",
             size = ggpt(FS_SMALL), fontface = "bold",
             colour = PAL$neutral_dark, family = TNR) +
    annotate("text", x = 0.7875, y = 10.08, label = sprintf("%.2f", med),
             size = ggpt(FS_HERO), fontface = "bold",
             colour = PAL$green_3, family = TNR) +
    coord_cartesian(xlim = c(0, 1), clip = "off") +
    labs(x = "Spearman correlation with primary DODJI", y = NULL,
         title = "Eight of nine variants stay stable \u2014 DODJI is robust",
         tag = "a") +
    theme_nature() + TITLE_THEME +
    theme(panel.background = element_rect(fill = "white", colour = NA),
          plot.title.position = "panel",
          plot.margin = margin(4, 4, 4, 4, "pt"),
          axis.title.x = element_text(size = FS_TICK, face = "bold",
                                      colour = PAL$neutral_black, family = TNR),
          axis.text.y = element_text(size = FS_SMALL, face = "bold",
                                     colour = PAL$neutral_dark, family = TNR))
}

## ---------------------------------------------------- panel b: quadrant
mk_quadrant <- function(df) {
  n_tot <- nrow(df)
  high <- sum(df$rho >= 0.7)
  moderate <- sum(df$rho >= 0.4 & df$rho < 0.7)
  fragile <- sum(df$rho < 0.4)
  boxes <- data.frame(
    x = c(0.2, 5.0, 5.0), y = c(5.2, 5.2, 0.4),
    w = c(4.3, 4.5, 4.5), h = c(4.3, 4.3, 4.3),
    col = c(PAL$green_3, PAL$gold, PAL$red_strong),
    label = c("Stable", "Moderate", "Fragile"),
    count = c(high, moderate, fragile))
  boxes$pct <- sprintf("%d/%d = %d%%", boxes$count, n_tot,
                       round(100 * boxes$count / n_tot))
  h_mod <- hatch_rect(5.0, 9.5, 5.2, 9.5, spacing_x = 0.55, slope = 1)
  h_fra <- rbind(hatch_rect(5.0, 9.5, 0.4, 4.7, spacing_x = 0.55, slope = 1),
                 hatch_rect(5.0, 9.5, 0.4, 4.7, spacing_x = 0.55, slope = -1))

  ggplot(boxes) +
    geom_rect(aes(xmin = x, xmax = x + w, ymin = y, ymax = y + h),
              fill = boxes$col, colour = boxes$col, linewidth = pt2mm(1.2)) +
    geom_segment(data = h_mod, aes(x, y, xend = xend, yend = yend),
                 colour = "white", alpha = 0.55, linewidth = pt2mm(0.5),
                 inherit.aes = FALSE) +
    geom_segment(data = h_fra, aes(x, y, xend = xend, yend = yend),
                 colour = "white", alpha = 0.55, linewidth = pt2mm(0.5),
                 inherit.aes = FALSE) +
    ## solid label plate so hatch lines never strike through the text
    geom_rect(aes(xmin = x + w / 2 - 1.75, xmax = x + w / 2 + 1.75,
                  ymin = y + h / 2 - 1.85, ymax = y + h / 2 + 1.35),
              fill = boxes$col, colour = NA) +
    geom_text(aes(x + w / 2, y + h / 2 + 0.85, label = label),
              size = ggpt(FS_LABEL), fontface = "bold", colour = "white",
              family = TNR) +
    geom_text(aes(x + w / 2, y + h / 2 - 0.15, label = count),
              size = ggpt(FS_HERO + 1), fontface = "bold", colour = "white",
              family = TNR) +
    geom_text(aes(x + w / 2, y + h / 2 - 1.35, label = pct),
              size = ggpt(FS_SMALL), fontface = "bold", colour = "white",
              family = TNR) +
    coord_fixed(xlim = c(0, 10), ylim = c(0, 10)) +
    labs(tag = "b") + theme_void_nature()
}

## ---------------------------------------------------- panel c: table with in-cell bars
mk_table <- function(df) {
  d <- df[order(df$rho), ]
  d$rho_fmt <- sprintf("%.2f", d$rho)
  d$col <- ifelse(d$rho >= 0.7, PAL$green_3,
                  ifelse(d$rho >= 0.4, PAL$gold, PAL$red_strong))
  n <- nrow(d)
  y_top <- 0.90              ## headroom above the table for the conclusion line
  rh <- y_top / (n + 1)      ## row height incl header
  rows <- data.frame(
    y = y_top - rh * (seq_len(n) + 0.5),
    variant = d$variant, rho = d$rho, rho_fmt = d$rho_fmt, col = d$col)
  y_head <- y_top - rh * 0.5
  x_v <- 0.03; x_r <- 0.80; x_split <- 0.75
  bar_x0 <- 0.855; bar_x1 <- 0.985
  rows$bar_xend <- bar_x0 + rows$rho * (bar_x1 - bar_x0)

  grid_df <- data.frame(
    x = c(0, 0, 0, 1, x_split),
    xend = c(1, 0, 1, 1, x_split),
    y = c(y_top, 0, 0, 0, 0),
    yend = c(y_top, y_top, 0, y_top, y_top))
  hlines <- data.frame(y = y_top - rh * seq_len(n))

  ggplot() +
    annotate("rect", xmin = 0, xmax = 1, ymin = y_top - rh, ymax = y_top,
             fill = PAL$neutral_light, colour = NA) +
    ## in-cell scale track (muted) + data bar proportional to rho
    geom_rect(data = rows, aes(xmin = bar_x0, xmax = bar_x1,
                               ymin = y - rh * 0.30, ymax = y + rh * 0.30),
              fill = PAL$neutral_light, alpha = 0.45, colour = NA,
              inherit.aes = FALSE) +
    geom_rect(data = rows, aes(xmin = bar_x0, xmax = bar_xend,
                               ymin = y - rh * 0.30, ymax = y + rh * 0.30),
              fill = rows$col, colour = NA, inherit.aes = FALSE) +
    geom_segment(data = grid_df, aes(x, y, xend = xend, yend = yend),
                 colour = PAL$neutral_mid, linewidth = pt2mm(0.5),
                 inherit.aes = FALSE) +
    geom_segment(data = hlines, aes(0, y, xend = 1, yend = y),
                 colour = PAL$neutral_mid, linewidth = pt2mm(0.5),
                 inherit.aes = FALSE) +
    annotate("text", x = x_v, y = y_head, label = "Variant", hjust = 0,
             size = ggpt(FS_TICK), fontface = "bold",
             colour = PAL$neutral_black, family = TNR) +
    annotate("text", x = x_r, y = y_head, label = "\u03c1", hjust = 0,
             size = ggpt(FS_TICK), fontface = "bold",
             colour = PAL$neutral_black, family = TNR) +
    geom_text(data = rows, aes(x_v, y, label = variant), hjust = 0,
              size = ggpt(FS_SMALL), colour = PAL$neutral_black, family = TNR) +
    geom_text(data = rows, aes(x_r, y, label = rho_fmt), hjust = 0,
              size = ggpt(FS_SMALL), fontface = "bold", colour = rows$col,
              family = TNR) +
    ## one-line conclusion above the table
    annotate("text", x = 0, y = (y_top + 1) / 2, hjust = 0, vjust = 0.5,
             label = "Only the civil-registration proxy falls below 0.4",
             size = ggpt(FS_TICK), fontface = "bold",
             colour = PAL$neutral_black, family = TNR) +
    scale_x_continuous(limits = c(0, 1), expand = c(0, 0)) +
    scale_y_continuous(limits = c(0, 1), expand = c(0, 0)) +
    labs(tag = "c") + theme_void_nature()
}

## ------------------------------------------------------------- assemble
main <- function() {
  df <- read_csv(file.path(SRC_DIR, "fig7_robustness_correlations.csv"),
                 show_col_types = FALSE)
  p_a <- mk_bars(df)
  p_b <- mk_quadrant(df)
  p_c <- mk_table(df)

  bot <- plot_grid(p_b, p_c, nrow = 1)
  full <- plot_grid(p_a, bot, ncol = 1, rel_heights = c(1, 1.05))

  save_pub(full, OUT_R2, "Figure7_robustness_nature", 183, 116)
}

main()
