## Figure 4 | Evidence stress test — flagship Nature redesign (R / ggplot2).
##
## R port of redesign_py/fig4_evidence_stress_test.py (QA-passed). All data
## elements and computations are IDENTICAL; only the rendering engine changes.
## Panels a-f: six validation domains (horizontal bars) with verdict chips,
## significance stars and conclusion-style titles. Panel g: dashboard verdict
## wall (hero status word + 3-dot evidence-strength meter + one-line evidence).
## v4.3 (2026-07-13): panel a residualisation geom_curve arrow removed (redundant;
##   the -0.46 -> 0.00 bars speak for themselves).
##
## Run from the PROJECT ROOT:  Rscript redesign_r/fig4_evidence_stress_test.R

source("redraw_r/nature_redraw_style.R")

OUT <- file.path(PROJECT_ROOT, "figures_redraw_nature_v2", "r")
FS_HERO <- 12   ## v4.1: verdict-wall titles one size smaller (was 13)

INK <- PAL$neutral_black; DARK <- PAL$neutral_dark; MID <- PAL$neutral_mid
RED <- PAL$red_strong;  BLUE <- PAL$blue_main

CHIP <- c(ROBUST = PAL$green_3, WATCH = PAL$gold, RISK = PAL$red_strong)

minus <- function(x) gsub("-", "\u2212", x)

shade <- function(hex, t = 0.30) {
  v <- grDevices::col2rgb(hex)[, 1] / 255
  grDevices::rgb(v[1] * (1 - t), v[2] * (1 - t), v[3] * (1 - t))
}

p_numeric <- function(p) {
  s <- trimws(as.character(p))
  if (is.na(s) || s == "" || s == "NA") return(NA_real_)
  if (startsWith(s, "<")) return(as.numeric(substring(s, 2)))
  suppressWarnings(as.numeric(s))
}

stars_of <- function(p) {
  p <- p_numeric(p)
  if (is.na(p)) return("")
  if (p < 0.001) return("***")
  if (p < 0.01)  return("**")
  if (p < 0.05)  return("*")
  "ns"
}

theme_bar <- function() {
  theme_nature() %+replace%
    theme(
      plot.tag = element_text(face = "bold", size = FS_TAG, colour = INK, family = TNR),
      plot.tag.position = "topleft",
      plot.title = element_text(face = "bold", size = FS_TITLE, colour = INK,
                                family = TNR, hjust = 0, lineheight = 0.95,
                                margin = margin(l = 16, b = 3)),
      axis.line.y = element_blank(),
      axis.ticks.y = element_blank(),
      axis.text.y = element_text(colour = INK, size = FS_SMALL, face = "bold",
                                 family = TNR, lineheight = 0.95, hjust = 1),
      plot.margin = margin(4, 4, 4, 4, "pt")
    )
}

## ----------------------------------------------------------- bar renderer
render_bar <- function(sub, colors, xlim, xlabel, title, chip, labels,
                       value_labels = NULL, stars = NULL, value_dx = 0.02,
                       inside_frac = 0.35, edge = "white", edgelw = 0.5,
                       xpad = 0, xbreaks = waiver()) {
  n <- nrow(sub)
  sub$y <- rev(seq_len(n))           ## first row on top
  span <- xlim[2] - xlim[1]
  labs <- vapply(seq_len(n), function(i) {
    v <- sub$value[i]
    lab <- if (!is.null(value_labels)) value_labels[i] else minus(sprintf("%.2f", v))
    st  <- if (!is.null(stars)) stars[i] else ""
    if (nzchar(st) && !grepl("\n", lab)) lab <- paste0(lab, st)
    lab
  }, character(1))
  inside <- abs(sub$value) > inside_frac * span
  sub$lx <- ifelse(inside,
                   sub$value - value_dx * sign(sub$value),
                   sub$value + value_dx * sign(sub$value))
  sub$lx[sub$value == 0] <- value_dx
  sub$hjust <- ifelse(inside, ifelse(sub$value >= 0, 1, 0), ifelse(sub$value >= 0, 0, 1))
  sub$hjust[sub$value == 0] <- 0
  sub$tcol <- ifelse(inside, "white", INK)
  sub$lab <- labs

  ggplot(sub) +
    geom_col(aes(x = value, y = y), width = 0.55, fill = colors, colour = edge,
             linewidth = pt2mm(edgelw), orientation = "y") +
    geom_vline(xintercept = 0, colour = DARK, linewidth = pt2mm(0.8)) +
    geom_text(aes(x = lx, y = y, label = lab, colour = I(tcol), hjust = hjust),
              vjust = 0.5, size = ggpt(FS_SMALL), fontface = "bold", family = TNR,
              lineheight = 0.95) +
    annotate("label", x = xlim[2], y = n + 1.30, label = chip, hjust = 1, vjust = 1,
             size = ggpt(FS_SMALL), fontface = "bold", colour = "white",
             fill = CHIP[[chip]], linewidth = 0, family = TNR,
             label.padding = unit(0.30, "lines")) +
    scale_x_continuous(limits = xlim, breaks = xbreaks,
                       expand = expansion(add = c(0, xpad))) +
    scale_y_continuous(breaks = sub$y, labels = labels,
                       limits = c(0.45, n + 1.35), expand = expansion(0)) +
    coord_cartesian(clip = "off") +
    labs(x = xlabel, y = NULL, tag = NULL, title = title) +
    theme_bar()
}

## ==================================================================== data
df <- read_csv(file.path(SRC_DIR, "fig4_evidence_stress_test.csv"),
               show_col_types = FALSE)

## a — Measurement validity
sub <- df[df$domain == "Measurement validity", ]
sig <- vapply(sub$p_value, stars_of, character(1))
cols <- ifelse(sig %in% c("", "ns"), MID, RED)
pa <- render_bar(sub, cols, c(-0.55, 0.55), "Pearson r with log GDP per capita",
                 "GDP-decoupled signal", "ROBUST",
                 labels = c("Raw quality", "DODJI\nresidualised"), stars = sig) +
  labs(tag = "a")

## b — Internal consistency
sub <- df[df$domain == "Internal consistency", ]
sig <- vapply(sub$p_value, stars_of, character(1))
pb <- render_bar(sub, rep(PAL$violet, 2), c(0, 1), "Correlation with DODJI",
                 "Internally consistent", "ROBUST",
                 labels = c("WHO-GBD\ndivergence", "GBD uncertainty\nwidth"),
                 stars = sig, xpad = 0.12, xbreaks = c(0, 0.25, 0.5, 0.75, 1)) +
  labs(tag = "b")

## c — External credibility
sub <- df[df$domain == "External credibility", ]
sig <- vapply(sub$p_value, stars_of, character(1))
cols <- ifelse(grepl("under-registration", sub$metric), RED, BLUE)
pc <- render_bar(sub, cols, c(-0.55, 0.55), "Correlation with external proxy",
                 "Externally validated", "ROBUST",
                 labels = c("Death under-\nregistration", "External\nsurveillance\ncapacity"),
                 stars = sig) +
  labs(tag = "c")

## d — Specificity (desired nulls)
sub <- df[df$domain == "Specificity", ]
sub$p_value <- suppressWarnings(as.numeric(sub$p_value))
labs <- sprintf("r=%s\np=%.2f (ns)", minus(sprintf("%.2f", sub$value)), sub$p_value)
pd <- render_bar(sub, rep(MID, 2), c(-0.25, 0.25), "Correlation with DODJI",
                 "Specificity confirmed", "ROBUST",
                 labels = c("Opioid-agonist\ntherapy coverage",
                            "GBD garbage-\ncode share"),
                 value_labels = labs) +
  labs(tag = "d")

## e — Small-state sensitivity
sub <- df[df$domain == "Small-state sensitivity", ]
sig <- vapply(sub$p_value, stars_of, character(1))
pe <- render_bar(sub, PAL$gold, c(0, 1), "Correlation with DODJI",
                 "Persists, attenuated", "WATCH",
                 labels = "Death under-\nregistration\n(excluding\nmicrostates)",
                 stars = sig, xpad = 0.12, xbreaks = c(0, 0.25, 0.5, 0.75, 1)) +
  annotate("text", x = 0.98, y = 0.62, label = paste0("n=", sub$n[1]), hjust = 1,
           vjust = 0, size = ggpt(FS_TINY), fontface = "bold", colour = MID,
           family = TNR) +
  labs(tag = "e")

## f — Robustness
sub <- df[df$domain == "Robustness", ]
sig <- vapply(sub$p_value, stars_of, character(1))
pf <- render_bar(sub, BLUE, c(0, 1), "Spearman r with primary DODJI",
                 "Cross-source robust", "ROBUST",
                 labels = "WHO-GBD\ncross-source\nvariant", stars = sig,
                 xpad = 0.12, xbreaks = c(0, 0.25, 0.5, 0.75, 1)) +
  annotate("text", x = 0.98, y = 0.62, label = paste0("n=", sub$n[1]), hjust = 1,
           vjust = 0, size = ggpt(FS_TINY), fontface = "bold", colour = MID,
           family = TNR) +
  labs(tag = "f")

## g — verdict wall
verdicts <- data.frame(
  x = c(0.6, 3.6, 6.6, 0.6, 3.6, 6.6), y = c(5.8, 5.8, 5.8, 1.8, 1.8, 1.8),
  color = c(rep(PAL$green_3, 3), rep(PAL$gold, 2), RED),
  title = c("High confidence", "Validated", "Consistent",
            "Not causal", "Caution", "Not supported"),
  sub = c("Full-sample triage", "GDP-decoupled signal",
          "External surveillance proxies", "Policy-effect transportability",
          "Microstate point rankings", "Within-country forecasting"),
  stringsAsFactors = FALSE
)
verdicts$level <- ifelse(verdicts$color == PAL$green_3, 3,
                         ifelse(verdicts$color == PAL$gold, 2, 1))
dots <- do.call(rbind, lapply(seq_len(nrow(verdicts)), function(i) {
  r <- verdicts[i, ]
  data.frame(x = r$x + 1.06 + 0.34 * 0:2, y = r$y + 2.98,
             on = 0:2 < r$level)
}))
segs <- data.frame(x0 = verdicts$x + 0.42, x1 = verdicts$x + 2.38,
                   y = verdicts$y + 1.42)

pg <- ggplot(verdicts) +
  geom_rect(aes(xmin = x, xmax = x + 2.8, ymin = y, ymax = y + 3.5,
                fill = I(color), colour = I(vapply(color, shade, character(1)))),
            linewidth = pt2mm(1.1)) +
  geom_point(data = dots, aes(x = x, y = y, fill = ifelse(on, "white", NA)),
             shape = 21, colour = "white", size = 1.6, stroke = 0.7,
             show.legend = FALSE) +
  geom_segment(data = segs, aes(x = x0, xend = x1, y = y, yend = y),
               colour = "white", linewidth = pt2mm(0.6), alpha = 0.55) +
  geom_text(aes(x = x + 1.4, y = y + 2.02, label = title), size = ggpt(FS_HERO),
            fontface = "bold", colour = "white", family = TNR) +
  geom_text(aes(x = x + 1.4, y = y + 0.88, label = sub), size = ggpt(FS_SMALL),
            colour = "white", family = TNR) +
  scale_fill_identity() +
  scale_x_continuous(limits = c(0, 10), expand = expansion(0)) +
  scale_y_continuous(limits = c(0, 10), expand = expansion(0)) +
  labs(tag = "g") +
  theme_void(base_family = TNR) +
  theme(plot.tag = element_text(face = "bold", size = FS_TAG, colour = INK,
                                family = TNR),
        plot.tag.position = "topleft",
        plot.margin = margin(4, 4, 4, 4, "pt"))

## ================================================================= composite
row1 <- plot_grid(pa, pb, pc, nrow = 1)
row2 <- plot_grid(pd, pe, pf, nrow = 1)
final <- plot_grid(row1, row2, pg, ncol = 1, rel_heights = c(1, 1, 1.55))

save_pub(final, OUT, "Figure4_evidence_stress_test_nature", 183, 116)
message("Fig4 R redesign done -> ", OUT)
