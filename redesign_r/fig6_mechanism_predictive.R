## Figure 6 | Mechanism and predictive validation of the DODJI signal
## (Nature flagship redesign, v2)
## 183 x 92 mm composite: a multivariable-regression forest | b predictive
## validation forest across model specifications; composite footnote below.
## Data elements & computation identical to redraw_r/fig6_mechanism_predictive.R
## (QA-passed): same CSVs, same CI (beta +/- 1.96*se), same significance rule
## (p < 0.05), same ordering, same gold band 0.055-0.165, same footnote.
## Fixes preserved from the QA-passed base: two-line bold panel titles with
## plot.title.position = "panel", bottom-margin footnote at x = 0.47 / FS_TINY,
## explicit panel-b x breaks, gold sign-reversal band coordinates.
## Note: y is mapped as NUMERIC row index (scale_y_continuous with labels) so
## that continuous row-tint rects cannot corrupt the discrete scale (ggplot2 4).

source("redraw_r/nature_redraw_style.R")

FS_HERO <- 13

OUT_V2 <- file.path(PROJECT_ROOT, "figures_redraw_nature_v2", "r")

mech <- read_csv(file.path(SRC_DIR, "mechanism_regression_results.csv"),
                 show_col_types = FALSE)
pred <- read_csv(file.path(SRC_DIR, "predictive_validation_results.csv"),
                 show_col_types = FALSE)

WHITE_BG <- theme(panel.background = element_rect(fill = "white", colour = NA))
GOLD_TXT <- "#8A5A00"   ## darker gold for legible text on the light band

title_theme <- function() {
  theme(plot.title = element_text(size = FS_TITLE, face = "bold",
                                  colour = PAL$neutral_black, family = TNR,
                                  hjust = 0.5, lineheight = 0.95,
                                  margin = margin(b = 5, unit = "pt")),
        plot.title.position = "panel")
}

## ---------------------------------------------------- panel a: mechanism
mk_mechanism <- function(df) {
  label_map <- c("who_ill_defined_pct" = "Ill-defined cause fraction",
                 "who_cod_completeness_pct" = "Cause-of-death completeness",
                 "who_civil_reg_death_pct" = "Civil death registration coverage",
                 "who_forensic_drug_monitor" = "Forensic drug monitoring",
                 "wb_life_expectancy" = "Life expectancy",
                 "wb_comm_disease_death_pct" = "Communicable disease death share")
  df$label <- label_map[df$predictor]
  df$lower <- df$beta - 1.96 * df$se
  df$upper <- df$beta + 1.96 * df$se
  df$sig <- df$p_value < 0.05
  df$note <- ifelse(df$sig, "*", "ns")
  df <- df[order(df$beta), ]
  ## top row = most negative beta (old: ascending + invert_yaxis)
  df$y <- factor(df$label, levels = rev(df$label))
  df$y_i <- as.numeric(df$y)          ## numeric row index, bottom = 1
  df$note_x <- ifelse(df$beta >= 0, df$upper + 0.012, df$lower - 0.012)
  df$note_h <- ifelse(df$beta >= 0, 0, 1)
  df$col <- ifelse(df$sig, PAL$red_strong, PAL$neutral_mid)
  df <- df[order(df$y_i), ]           ## bottom -> top for axis label colours
  lab_cols <- ifelse(df$sig, PAL$red_strong, PAL$neutral_dark)
  sig_row <- df$y_i[df$sig]

  ggplot(df, aes(beta, y_i)) +
    ## subtle tint behind the significant row (alpha <= 0.06)
    annotate("rect", xmin = -Inf, xmax = Inf,
             ymin = sig_row - 0.48, ymax = sig_row + 0.48,
             fill = PAL$red_strong, alpha = 0.05) +
    ## bolded zero reference line
    geom_vline(xintercept = 0, colour = PAL$neutral_black,
               linewidth = pt2mm(1.3), linetype = "dashed") +
    ## thin CI lines with end caps; saturated red for sig, grey for ns
    geom_errorbarh(data = df[!df$sig, ], aes(xmin = lower, xmax = upper),
                   height = 0.16, colour = PAL$neutral_mid,
                   linewidth = pt2mm(0.8)) +
    geom_errorbarh(data = df[df$sig, ], aes(xmin = lower, xmax = upper),
                   height = 0.18, colour = PAL$red_strong,
                   linewidth = pt2mm(1.1)) +
    geom_point(data = df[df$sig, ], colour = PAL$red_strong,
               fill = PAL$red_strong, shape = 16, size = 2.3) +
    geom_point(data = df[!df$sig, ], colour = PAL$neutral_mid, fill = NA,
               shape = 21, size = 1.9, stroke = pt2mm(1.0)) +
    geom_text(aes(note_x, y_i, label = note), hjust = df$note_h,
              size = ggpt(FS_TINY), fontface = "bold",
              colour = df$col, family = TNR) +
    ## hero number + direct annotation with guiding arrow
    annotate("text", x = -0.115, y = sig_row + 0.82, hjust = 0,
             label = "all BH-adjusted p \u2265 0.24", size = ggpt(FS_HERO - 2),
             fontface = "bold", colour = PAL$red_strong, family = TNR) +
    annotate("text", x = -0.115, y = sig_row + 0.44, hjust = 0,
             label = "weakest nominal signal: civil\nregistration p = 0.049 (raw)",
             size = ggpt(FS_TINY), fontface = "bold",
             colour = PAL$red_strong, family = TNR, lineheight = 0.95) +
    annotate("segment", x = 0.105, xend = -0.02,
             y = sig_row + 0.20, yend = sig_row + 0.14,
             colour = PAL$red_strong, linewidth = pt2mm(0.9),
             arrow = arrow(length = unit(1.8, "mm"), type = "closed")) +
    scale_y_continuous(breaks = df$y_i, labels = df$label,
                       expand = expansion(mult = c(0.06, 0.06))) +
    coord_cartesian(xlim = c(-0.12, 0.32)) +
    labs(x = "Regression coefficient (\u03b2)\nwith 95% CI",
         y = NULL,
         title = "No mechanism driver survives\nmultiplicity control",
         caption = "Higher DODJI = weaker surveillance", tag = "a") +
    theme_nature() + WHITE_BG + title_theme() +
    theme(plot.caption = element_text(size = FS_TINY, face = "bold",
                                      colour = PAL$neutral_mid, family = TNR,
                                      hjust = 1, margin = margin(t = 2, unit = "pt")),
          axis.title.x = element_text(size = FS_TICK, face = "bold",
                                      colour = PAL$neutral_black, family = TNR),
          axis.text.y = element_text(size = FS_TICK, face = "bold",
                                     colour = lab_cols, family = TNR))
}

## ------------------------------------------------- panel b: predictive
mk_predictive <- function(df) {
  df$lower <- df$beta - 1.96 * df$se
  df$upper <- df$beta + 1.96 * df$se
  df$col <- ifelse(df$beta < 0 & df$p < 0.05, PAL$blue_main,
                   ifelse(df$beta > 0 & df$p < 0.05, PAL$red_strong,
                          PAL$neutral_mid))
  df$sig <- df$p < 0.05
  df$note <- ifelse(df$sig, "*", "ns")
  df$lab <- sprintf("%.3f %s", df$beta, df$note)
  df$r2lab <- sprintf("R\u00b2=%.2f", df$r2)
  df <- df[order(df$beta), ]
  df$y <- factor(df$model, levels = rev(df$model))
  df$y_i <- as.numeric(df$y)          ## bottom = 1
  df <- df[order(df$y_i), ]           ## bottom -> top
  lab_cols <- df$col

  ggplot(df, aes(beta, y_i)) +
    ## gold sign-reversal band (coordinates preserved from QA-passed base)
    annotate("rect", xmin = 0.055, xmax = 0.165, ymin = -Inf, ymax = Inf,
             fill = PAL$gold, alpha = 0.10) +
    ## subtle tints behind the two significant rows (alpha <= 0.06)
    geom_rect(data = df[df$sig, ],
              aes(xmin = -Inf, xmax = Inf,
                  ymin = y_i - 0.48, ymax = y_i + 0.48),
              fill = df$col[df$sig], alpha = 0.05, inherit.aes = FALSE) +
    geom_vline(xintercept = c(0.055, 0.165), colour = PAL$gold,
               linewidth = pt2mm(0.5)) +
    ## bolded zero reference line
    geom_vline(xintercept = 0, colour = PAL$neutral_black,
               linewidth = pt2mm(1.3), linetype = "dashed") +
    geom_errorbarh(data = df[!df$sig, ], aes(xmin = lower, xmax = upper),
                   height = 0.22, colour = PAL$neutral_mid,
                   linewidth = pt2mm(0.8)) +
    geom_errorbarh(data = df[df$sig, ], aes(xmin = lower, xmax = upper),
                   height = 0.24, colour = df$col[df$sig],
                   linewidth = pt2mm(1.1)) +
    geom_point(data = df[df$sig, ], colour = df$col[df$sig],
               fill = df$col[df$sig], shape = 16, size = 2.3) +
    geom_point(data = df[!df$sig, ], colour = PAL$neutral_mid, fill = NA,
               shape = 21, size = 1.9, stroke = pt2mm(1.0)) +
    ## per-model beta + significance, then a rounded R2 chip on the right
    geom_text(aes(0.185, y_i, label = lab), hjust = 0, size = ggpt(FS_TINY),
              fontface = "bold", colour = df$col, family = TNR) +
    geom_label(aes(0.245, y_i, label = r2lab), hjust = 0,
               size = ggpt(FS_TINY), fontface = "bold", family = TNR,
               colour = df$col, fill = "white",
               linewidth = pt2mm(0.5), label.r = unit(0.25, "lines"),
               label.padding = unit(0.14, "lines")) +
    scale_y_continuous(breaks = df$y_i, labels = df$model) +
    coord_cartesian(xlim = c(-0.085, 0.30), ylim = c(0.35, 5.05)) +
    scale_x_continuous(breaks = seq(-0.05, 0.30, 0.05)) +
    labs(x = "Association with death under-registration (\u03b2)", y = NULL,
         title = "Association reverses sign after\ncountry fixed effects",
         tag = "b") +
    theme_nature() + WHITE_BG + title_theme() +
    theme(axis.title.x = element_text(size = FS_TICK, face = "bold",
                                      colour = PAL$neutral_black, family = TNR),
          axis.text.y = element_text(size = FS_TICK, face = "bold",
                                     colour = lab_cols, family = TNR))
}

## ------------------------------------------------------------- assemble
p_a <- mk_mechanism(mech)
p_b <- mk_predictive(pred)
row <- plot_grid(p_a, p_b, nrow = 1, rel_widths = c(1, 1)) +
  theme(plot.margin = margin(2, 2, 2, 2, "pt"))

save_pub(row, OUT_V2, "Figure6_mechanism_validation_nature", 183, 90)
