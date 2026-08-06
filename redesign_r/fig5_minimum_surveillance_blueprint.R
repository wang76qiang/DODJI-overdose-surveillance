## Figure 5 | Minimum surveillance blueprint — flagship Nature redesign (R).
##
## R port of redesign_py/fig5_minimum_surveillance_blueprint.py (QA-passed).
## All data elements are IDENTICAL; only the rendering engine changes.
##   a four-stage capability roadmap (chevron headers + goal lines +
##     colour-spined capability cards + hero capability count)
##   b five-step build-up staircase
##   c regime -> minimum-package matching with curved flow ribbons
##
## Run from the PROJECT ROOT:  Rscript redesign_r/fig5_minimum_surveillance_blueprint.R

source("redraw_r/nature_redraw_style.R")

OUT <- file.path(PROJECT_ROOT, "figures_redraw_nature_v2", "r")
FS_HERO <- 13

INK <- PAL$neutral_black; DARK <- PAL$neutral_dark; MID <- PAL$neutral_mid
RED <- PAL$red_strong;  BLUE <- PAL$blue_main;    GREEN <- PAL$green_3
GOLD <- PAL$gold
BG_TINT <- "#CCCCCC0F"   ## alpha ~0.059 (<= 0.06), same as the Python version

STAGE_ORDER <- c("Foundation", "Foundational-intermediate", "Intermediate", "Advanced")
STAGE_GOAL <- c("Foundation" = "Count and code every death",
                "Foundational-intermediate" = "See deaths in near-real time",
                "Intermediate" = "Link records into intelligence",
                "Advanced" = "Measure equity, evaluate impact")

theme_panel <- function() {
  theme_void(base_family = TNR) %+replace%
    theme(
      plot.tag = element_text(face = "bold", size = FS_TAG, colour = INK, family = TNR),
      plot.tag.position = "topleft",
      plot.title = element_text(face = "bold", size = FS_TITLE, colour = INK,
                                family = TNR, hjust = 0, lineheight = 0.95,
                                margin = margin(l = 16, b = 3)),
      panel.background = element_rect(fill = BG_TINT, colour = NA),
      plot.margin = margin(4, 4, 4, 4, "pt")
    )
}

cap_text <- function(text, width, max_lines) {
  lines <- strwrap(as.character(text), width = width)
  if (length(lines) > max_lines) {
    lines <- lines[seq_len(max_lines)]
    lines[max_lines] <- paste0(gsub("[.,; ]+$", "", lines[max_lines]), "\u2026")
  }
  paste(lines, collapse = "\n")
}

## chevron polygon (right-pointing; notched left edge unless first)
chevron_df <- function(x, y0, w, h, first = FALSE) {
  p <- 0.42
  pts <- data.frame(x = c(x, x + w - p, x + w, x + w - p, x),
                    y = c(y0, y0, y0 + h / 2, y0 + h, y0 + h))
  if (!first) pts <- rbind(pts, data.frame(x = x + p, y = y0 + h / 2))
  pts
}

## ==================================================================== data
df <- read_csv(file.path(SRC_DIR, "fig5_minimum_surveillance_package.csv"),
               show_col_types = FALSE)

## ================================================== panel a — the roadmap
stage_width <- 4.05; stage_gap <- 0.55; start_x <- 0.35
chev_y0 <- 8.55; chev_h <- 1.00
comp_x_pad <- 0.16
box_h <- 1.70; box_gap <- 0.16; top_y <- 7.90

chev <- do.call(rbind, lapply(seq_along(STAGE_ORDER), function(i) {
  s <- STAGE_ORDER[i]
  x <- start_x + (i - 1) * (stage_width + stage_gap)
  cbind(chevron_df(x, chev_y0, stage_width, chev_h, first = i == 1),
        id = i, color = STAGE_COLORS[[s]])
}))
chev_lab <- data.frame(
  x = start_x + (seq_along(STAGE_ORDER) - 1) * (stage_width + stage_gap) +
    stage_width / 2 + c(0, rep(0.10, 3)),
  label = paste(seq_along(STAGE_ORDER), STAGE_DISPLAY[STAGE_ORDER]),
  stringsAsFactors = FALSE
)
goal_lab <- data.frame(
  x = start_x + (seq_along(STAGE_ORDER) - 1) * (stage_width + stage_gap) +
    stage_width / 2,
  label = STAGE_GOAL[STAGE_ORDER],
  stringsAsFactors = FALSE
)

boxes <- df
boxes$stage <- factor(boxes$maturity_stage, levels = STAGE_ORDER)
boxes <- boxes[order(boxes$stage), ]
boxes$idx <- unlist(lapply(split(seq_len(nrow(boxes)), boxes$stage), seq_along))
boxes$x <- start_x + (match(boxes$stage, STAGE_ORDER) - 1) *
  (stage_width + stage_gap) + comp_x_pad
boxes$y <- top_y - (boxes$idx - 1) * (box_h + box_gap)
boxes$color <- STAGE_COLORS[as.character(boxes$stage)]
boxes$comp <- vapply(boxes$component, cap_text, character(1), width = 22,
                     max_lines = 2)
boxes$cap <- vapply(boxes$capability, cap_text, character(1), width = 30,
                    max_lines = 3)
cw <- stage_width - 2 * comp_x_pad

n_total <- nrow(df)
hx <- start_x + 3 * (stage_width + stage_gap) + stage_width / 2

pa <- ggplot() +
  geom_polygon(data = chev, aes(x = x, y = y, group = id, fill = I(color)),
               colour = "white", linewidth = pt2mm(1.2)) +
  geom_text(data = chev_lab, aes(x = x, y = chev_y0 + chev_h / 2, label = label),
            size = ggpt(FS_TICK), fontface = "bold", colour = "white", family = TNR) +
  geom_text(data = goal_lab, aes(x = x, y = chev_y0 - 0.38, label = label),
            size = ggpt(FS_TINY), colour = DARK, family = TNR, fontface = "italic") +
  geom_rect(data = boxes, aes(xmin = x, xmax = x + cw, ymin = y - box_h, ymax = y),
            fill = "white", colour = PAL$neutral_light, linewidth = pt2mm(0.9)) +
  geom_rect(data = boxes, aes(xmin = x, xmax = x + 0.14, ymin = y - box_h, ymax = y,
                              fill = I(color)), colour = NA) +
  geom_text(data = boxes, aes(x = x + 0.30, y = y - 0.12, label = comp,
                              colour = I(color)),
            hjust = 0, vjust = 1, size = ggpt(FS_SMALL), fontface = "bold",
            family = TNR, lineheight = 0.95) +
  geom_text(data = boxes, aes(x = x + 0.30, y = y - 0.55, label = cap),
            hjust = 0, vjust = 1, size = ggpt(FS_TINY), colour = MID,
            family = TNR, lineheight = 1.0) +
  ## hero capability count
  annotate("text", x = hx, y = 3.95, label = "TOTAL", size = ggpt(FS_TINY),
           fontface = "bold", colour = MID, family = TNR) +
  annotate("text", x = hx, y = 3.15, label = n_total, size = ggpt(FS_HERO),
           fontface = "bold", colour = INK, family = TNR) +
  scale_x_continuous(limits = c(0, 20), expand = expansion(0)) +
  scale_y_continuous(limits = c(0, 10), expand = expansion(0)) +
  labs(tag = "a",
       title = "Four cumulative stages from counting deaths to measuring equity") +
  theme_panel()

## ============================================== panel b — build-up staircase
steps <- data.frame(
  num = 1:5,
  label = c("Count every\ndeath", "Code overdose\ncorrectly", "Toxicology\npanels",
            "Link records\n& services", "Equity &\nevaluation"),
  stage = c("Foundation", "Foundation", "Foundational-intermediate",
            "Intermediate", "Advanced"),
  stringsAsFactors = FALSE
)
steps$color <- STAGE_COLORS[steps$stage]
steps$x <- seq(1.0, 8.6, length.out = 5)
steps$y <- seq(2.9, 8.1, length.out = 5)

## arrows between consecutive steps, shortened along the path direction
arr <- do.call(rbind, lapply(1:4, function(i) {
  x0 <- steps$x[i]; y0 <- steps$y[i]; x1 <- steps$x[i + 1]; y1 <- steps$y[i + 1]
  d <- sqrt((x1 - x0)^2 + (y1 - y0)^2); sh <- 0.42
  data.frame(x = x0 + (x1 - x0) / d * sh, y = y0 + (y1 - y0) / d * sh,
             xend = x1 - (x1 - x0) / d * sh, yend = y1 - (y1 - y0) / d * sh)
}))
steps$lx <- steps$x + 0.55

pb <- ggplot(steps) +
  annotate("segment", x = 0.60, y = 2.40, xend = 9.00, yend = 8.60,
           colour = MID, linewidth = pt2mm(0.9), linetype = "dashed", alpha = 0.25) +
  geom_segment(data = arr, aes(x = x, y = y, xend = xend, yend = yend),
               colour = DARK, linewidth = pt2mm(1.1),
               arrow = arrow(length = unit(2.2, "mm"), type = "closed")) +
  geom_point(aes(x = x, y = y, fill = I(color)), shape = 21, size = 7.5,
             colour = "white", stroke = pt2mm(1.6)) +
  geom_text(aes(x = x, y = y, label = num), size = ggpt(FS_LABEL),
            fontface = "bold", colour = "white", family = TNR) +
  geom_text(aes(x = lx, y = y - 0.88, label = label), size = ggpt(FS_SMALL),
            fontface = "bold", colour = INK, family = TNR, vjust = 1,
            lineheight = 1.0) +
  geom_label(aes(x = lx, y = y - 2.20, label = STAGE_DISPLAY[stage],
                 colour = I(color)),
             size = ggpt(FS_TINY), fontface = "bold", family = TNR, fill = "white",
             linewidth = pt2mm(0.8), label.padding = unit(0.18, "lines"),
             vjust = 1, show.legend = FALSE) +
  scale_x_continuous(limits = c(0, 10), expand = expansion(0)) +
  scale_y_continuous(limits = c(0, 10), expand = expansion(0)) +
  labs(tag = "b", title = "Five sequenced investments \u2014 easiest first") +
  theme_panel()

## ========================================== panel c — regime -> package flows
mapping <- data.frame(
  regime = c("Insufficient\nexposure data", "Data-quality-\nlimited",
             "Medical-system-\ndriven", "Low-burden /\nprotected"),
  package = c("\u2192 Foundation", "\u2192 Foundation\n+ Foundational-int.",
              "\u2192 Intermediate\n+ Advanced", "\u2192 Sustain\n+ Advanced equity"),
  color = c(RED, GOLD, BLUE, GREEN),
  y = c(8.55, 6.35, 4.15, 1.95),
  rad = c(0.18, -0.12, 0.12, -0.18),
  stringsAsFactors = FALSE
)
bar_h <- 1.55
left_x <- 0.35; left_w <- 3.20
right_x <- 6.45; right_w <- 3.20

pc <- ggplot(mapping)
for (i in seq_len(nrow(mapping))) {   ## geom_curve curvature is not vectorised
  r <- mapping[i, ]
  ## v5.1: flow arrows thinned to 1/4 of their previous width (7 -> 1.75 pt)
  pc <- pc + geom_curve(x = left_x + left_w + 0.12, y = r$y,
                        xend = right_x - 0.12, yend = r$y,
                        curvature = r$rad, colour = r$color,
                        linewidth = 1.75 * 0.3528, alpha = 0.45, lineend = "round",
                        arrow = arrow(length = unit(1.6, "mm"), type = "closed"))
}
pc <- pc +
  geom_rect(aes(xmin = left_x, xmax = left_x + left_w,
                ymin = y - bar_h / 2, ymax = y + bar_h / 2, fill = I(color)),
            colour = "white", linewidth = pt2mm(1.2), alpha = 0.93) +
  geom_text(aes(x = left_x + left_w / 2, y = y, label = regime),
            size = ggpt(FS_SMALL), fontface = "bold", colour = "white",
            family = TNR, lineheight = 1.0) +
  geom_rect(aes(xmin = right_x, xmax = right_x + right_w,
                ymin = y - bar_h / 2, ymax = y + bar_h / 2),
            fill = "white", colour = mapping$color, linewidth = pt2mm(1.3)) +
  geom_text(aes(x = right_x + right_w / 2, y = y, label = package,
                colour = I(color)),
            size = ggpt(FS_SMALL), fontface = "bold", family = TNR,
            lineheight = 1.0) +
  annotate("text", x = left_x + left_w / 2, y = 9.72, label = "Regime",
           size = ggpt(FS_SMALL), fontface = "bold", colour = MID, family = TNR) +
  annotate("text", x = right_x + right_w / 2, y = 9.72, label = "Minimum package",
           size = ggpt(FS_SMALL), fontface = "bold", colour = MID, family = TNR) +
  scale_x_continuous(limits = c(0, 10), expand = expansion(0)) +
  scale_y_continuous(limits = c(0, 10), expand = expansion(0)) +
  labs(tag = "c", title = "Match the entry package to the regime") +
  theme_panel()

## ================================================================= composite
bot <- plot_grid(pb, pc, nrow = 1, rel_widths = c(1.15, 1))
final <- plot_grid(pa, bot, ncol = 1, rel_heights = c(1.55, 1))

save_pub(final, OUT, "Figure5_minimum_surveillance_blueprint_nature", 183, 114)
message("Fig5 R redesign done -> ", OUT)
