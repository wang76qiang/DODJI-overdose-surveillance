## Figure 1 | The surveillance gap — flagship Nature redesign (R / ggplot2 + sf).
##
## R port of redesign_py/fig1_surveillance_gap.py (QA-passed). All data elements,
## normalisations and colour mappings are IDENTICAL; the map engine upgrades from
## Natural Earth 110m (pyshp) to 50m (sf) -> coastlines are sharper and the five
## microstates missing at 110m (Monaco, Malta, San Marino, Andorra, Bosnia) are
## now rendered. Panels:
##   a hero statistics + DODJI lens   b bivariate burden x surveillance map
##   c rank-change map                d reclassification matrix
##   e bivariate legend               f country story cards
##
## Run from the PROJECT ROOT:  Rscript redesign_r/fig1_surveillance_gap.R

source("redraw_r/nature_redraw_style.R")
suppressPackageStartupMessages({
  library(sf)
  library(grid)
})

OUT <- file.path(PROJECT_ROOT, "figures_redraw_nature_v2", "r")
FS_HERO <- 13

INK <- PAL$neutral_black; DARK <- PAL$neutral_dark; MID <- PAL$neutral_mid
RED <- PAL$red_strong;  BLUE <- PAL$blue_main;    GREEN <- PAL$green_3
GOLD <- PAL$gold

## --------------------------------------------------------- bivariate colour
## Identical bilinear four-corner blend to redraw_py/nature_redraw_style.py.
hex2rgb01 <- function(h) grDevices::col2rgb(h)[, 1] / 255
rgb01_hex <- function(v) grDevices::rgb(pmin(pmax(v, 0), 1)[1], pmin(pmax(v, 0), 1)[2],
                                        pmin(pmax(v, 0), 1)[3])
bivariate_color <- function(b, s) {
  bl <- hex2rgb01(OKABE$sky);       br <- hex2rgb01(OKABE$blue)
  tl <- hex2rgb01(OKABE$yellow);    tr <- hex2rgb01(OKABE$vermillion)
  bot <- bl * (1 - b) + br * b
  top <- tl * (1 - b) + tr * b
  rgb01_hex(bot * (1 - s) + top * s)
}
bivariate_vec <- function(b, s) mapply(bivariate_color, b, s)

## ------------------------------------------------------- source -> 50m name
## 50m NAME_EN already contains Monaco / Malta / San Marino / Andorra / Bosnia.
SOURCE_TO_SHAPE <- c("Russian Federation" = "Russia",
                     "Republic of Moldova" = "Moldova",
                     "Czechia" = "Czech Republic")
shape_name <- function(x) { hit <- x %in% names(SOURCE_TO_SHAPE); x[hit] <- SOURCE_TO_SHAPE[x[hit]]; x }

## ------------------------------------------------------------ panel helpers
theme_panel <- function() {
  theme_void(base_family = TNR) %+replace%
    theme(
      plot.tag = element_text(face = "bold", size = FS_TAG, colour = INK, family = TNR),
      plot.tag.position = "topleft",
      plot.title = element_text(face = "bold", size = FS_LABEL, colour = INK,
                                family = TNR, hjust = 0, lineheight = 0.95,
                                margin = margin(l = 16, b = 2)),
      plot.margin = margin(4, 4, 4, 4, "pt")
    )
}

panel_title <- function(p, tag, title) p + labs(tag = tag, title = title)

circle_df <- function(cx, cy, r, n = 120) {
  a <- seq(0, 2 * pi, length.out = n)
  data.frame(x = cx + r * cos(a), y = cy + r * sin(a))
}

ellipse_df <- function(cx, cy, rx, ry, n = 120) {
  a <- seq(0, 2 * pi, length.out = n)
  data.frame(x = cx + rx * cos(a), y = cy + ry * sin(a))
}

minus <- function(x) gsub("-", "\u2212", x)

## ==================================================================== data
df <- read_csv(file.path(SRC_DIR, "fig1_mortality_and_dodji_atlas.csv"),
               show_col_types = FALSE)
n_up     <- sum(df$reclassification_direction == "Up >=10")
n_down   <- sum(df$reclassification_direction == "Down >=10")
n_stable <- sum(df$reclassification_direction == "Stable")
n_all    <- nrow(df)
n_insuff <- sum(df$regime == "Insufficient exposure data")
n_med    <- sum(df$regime == "Medical-system-driven")

world <- st_read(file.path(PROJECT_ROOT, "geo", "ne_50m_admin_0_countries",
                           "ne_50m_admin_0_countries.shp"), quiet = TRUE)

## ==================================================== panel a — hero stats
## Diverging proportional bar: of 47 countries re-ranked after adding DODJI,
## 10 fall >=10 ranks (blue), 27 hold (grey), 10 rise >=10 (vermillion).
w_tot <- 8.0
w_dn <- w_tot * n_down / n_all
w_st <- w_tot * n_stable / n_all
x_dn <- c(1.0, 1.0 + w_dn)
x_st <- c(1.0 + w_dn, 1.0 + w_dn + w_st)
x_up <- c(1.0 + w_dn + w_st, 9.0)
bar_y <- c(4.35, 5.75)

pa <- ggplot() +
  ## hero pair: fall (left, blue) vs rise (right, vermillion)
  annotate("text", x = 2.5, y = 8.95, label = n_down, size = ggpt(FS_HERO),
           fontface = "bold", colour = OKABE$blue, family = TNR) +
  annotate("text", x = 2.5, y = 7.45, label = "fall \u226510 ranks \u2193",
           size = ggpt(FS_SMALL), fontface = "bold", colour = OKABE$blue,
           family = TNR) +
  annotate("text", x = 7.5, y = 8.95, label = n_up, size = ggpt(FS_HERO),
           fontface = "bold", colour = OKABE$vermillion, family = TNR) +
  annotate("text", x = 7.5, y = 7.45, label = "rise \u226510 ranks \u2191",
           size = ggpt(FS_SMALL), fontface = "bold", colour = OKABE$vermillion,
           family = TNR) +
  ## proportional stacked bar: 10 fall | 27 stable | 10 rise of 47
  annotate("rect", xmin = x_dn[1], xmax = x_dn[2], ymin = bar_y[1], ymax = bar_y[2],
           fill = OKABE$blue, colour = "white", linewidth = pt2mm(0.8)) +
  annotate("rect", xmin = x_st[1], xmax = x_st[2], ymin = bar_y[1], ymax = bar_y[2],
           fill = PAL$neutral_light, colour = "white", linewidth = pt2mm(0.8)) +
  annotate("rect", xmin = x_up[1], xmax = x_up[2], ymin = bar_y[1], ymax = bar_y[2],
           fill = OKABE$vermillion, colour = "white", linewidth = pt2mm(0.8)) +
  annotate("text", x = mean(x_st), y = mean(bar_y),
           label = paste0(n_stable, " stable"), size = ggpt(FS_SMALL),
           fontface = "bold", colour = INK, family = TNR) +
  annotate("text", x = 5.0, y = 3.70,
           label = paste0("of ", n_all, " countries re-ranked"),
           size = ggpt(FS_TINY), colour = MID, family = TNR) +
  ## concept lenses: priority = burden x visibility
  geom_polygon(data = ellipse_df(4.20, 1.90, 1.92, 1.14), aes(x, y),
               fill = OKABE$sky, colour = OKABE$blue,
               linewidth = pt2mm(0.9), alpha = 0.40) +
  geom_polygon(data = ellipse_df(5.80, 1.90, 1.92, 1.14), aes(x, y),
               fill = PAL$red_1, colour = OKABE$vermillion,
               linewidth = pt2mm(0.9), alpha = 0.50) +
  annotate("text", x = 3.30, y = 1.90, label = "burden", size = ggpt(FS_TINY),
           fontface = "bold", colour = OKABE$blue, family = TNR) +
  annotate("text", x = 6.70, y = 1.90, label = "visibility", size = ggpt(FS_TINY),
           fontface = "bold", colour = OKABE$vermillion, family = TNR) +
  annotate("text", x = 5.0, y = 0.42, label = "priority = burden \u00d7 visibility",
           size = ggpt(FS_TINY), colour = MID, family = TNR) +
  scale_x_continuous(limits = c(0, 10)) +
  scale_y_continuous(limits = c(0, 10)) +
  theme_panel()
pa <- panel_title(pa, "a", "10 countries rise,\n10 more fall in priority")

## ============================================== panel b — bivariate world map
df_b <- df
mn <- min(df_b$mortality_rank); mx <- max(df_b$mortality_rank)
df_b$burden_norm <- 1 - (df_b$mortality_rank - mn) / (mx - mn)
mn_d <- min(df_b$dodji_score); mx_d <- max(df_b$dodji_score)
df_b$surv_norm <- (df_b$dodji_score - mn_d) / (mx_d - mn_d)
df_b$shape <- shape_name(df_b$country)
df_b$fill <- bivariate_vec(df_b$burden_norm, df_b$surv_norm)

world_b <- world
world_b$fill <- PAL$missing
idx <- match(world_b$NAME_EN, df_b$shape)
hit <- !is.na(idx)
world_b$fill[hit] <- df_b$fill[idx[hit]]

## inset 3x3 bivariate key, drawn in ocean space (lower-left)
xs3 <- seq(0, 1, length.out = 3); ys3 <- seq(0, 1, length.out = 3)
key <- expand.grid(j = 1:3, i = 1:3)
key$x0 <- -178 + (key$j - 1) * 11
key$y0 <- -58 + (key$i - 1) * 11
key$fill <- bivariate_vec(xs3[key$j], ys3[4 - key$i])

pb <- ggplot(world_b) +
  geom_sf(aes(fill = I(fill)), colour = "white", linewidth = 0.08) +
  geom_rect(data = key, aes(xmin = x0, xmax = x0 + 10.99, ymin = y0, ymax = y0 + 10.99,
                            fill = I(fill)), colour = "white", linewidth = 0.2) +
  annotate("text", x = -178 + 3 * 11 + 8, y = -58 + 1.5 * 11, label = "higher\nburden \u2192",
           size = ggpt(4), fontface = "bold", colour = DARK, family = TNR,
           hjust = 0.5, vjust = 0.5, angle = 90, lineheight = 1.1) +
  annotate("text", x = -178, y = -58 + 3 * 11 + 2, label = "weaker\nsurveillance \u2191",
           size = ggpt(4), fontface = "bold", colour = DARK, family = TNR,
           hjust = 0, vjust = 0, lineheight = 0.9) +
  ## leader labels (same anchors as the Python version)
  annotate("segment", x = -157, y = 26, xend = -98, yend = 39.5, colour = DARK,
           linewidth = pt2mm(0.6), lineend = "round") +
  annotate("point", x = -98, y = 39.5, size = 0.225, colour = INK) +
  annotate("text", x = -170, y = 24, label = "USA", size = ggpt(FS_SMALL),
           fontface = "bold", colour = INK, family = TNR, hjust = 0) +
  annotate("segment", x = -26, y = 45, xend = -3.6, yend = 54, colour = DARK,
           linewidth = pt2mm(0.6), lineend = "round") +
  annotate("point", x = -3.6, y = 54, size = 0.225, colour = INK) +
  annotate("text", x = -34, y = 43, label = "UK", size = ggpt(FS_SMALL),
           fontface = "bold", colour = INK, family = TNR, hjust = 0) +
  ## Iceland: point anchored on the true 50m centroid (-18.44, 64.98);
  ## label placed over open Atlantic south-west of the island so the
  ## leader line crosses no land and the dot sits on Iceland itself
  annotate("segment", x = -29, y = 59.2, xend = -19.4, yend = 63.8, colour = DARK,
           linewidth = pt2mm(0.6), lineend = "round") +
  annotate("point", x = -18.44, y = 64.98, size = 0.225, colour = INK) +
  annotate("text", x = -47, y = 57.5, label = "Iceland", size = ggpt(FS_SMALL),
           fontface = "bold", colour = INK, family = TNR, hjust = 0) +
  annotate("segment", x = 34, y = 16, xend = 20.1, yend = 41.3, colour = DARK,
           linewidth = pt2mm(0.6), lineend = "round") +
  annotate("point", x = 20.1, y = 41.3, size = 0.225, colour = INK) +
  annotate("text", x = 34, y = 16, label = "Albania\nDODJI 2.30", size = ggpt(FS_SMALL),
           fontface = "bold", colour = INK, family = TNR, hjust = 0, lineheight = 0.95) +
  coord_sf(xlim = c(-180, 180), ylim = c(-60, 90), expand = FALSE) +
  theme_panel() +
  theme(panel.background = element_rect(fill = "#EEF3F6", colour = NA))
pb <- panel_title(pb, "b", "Burden and visibility\ndiverge worldwide")

## ============================================= panel c — rank-change world map
df_c <- df
df_c$rank_change <- df_c$mortality_rank - df_c$combined_priority_rank
df_c$shape <- shape_name(df_c$country)
vmax <- max(abs(df_c$rank_change))   ## 42

world_c <- world
world_c$rc <- NA_real_
idxc <- match(world_c$NAME_EN, df_c$shape)
hitc <- !is.na(idxc)
world_c$rc[hitc] <- df_c$rank_change[idxc[hitc]]

pc <- ggplot(world_c) +
  geom_sf(aes(fill = rc), colour = "white", linewidth = 0.08) +
  scale_fill_gradient2(low = OKABE$blue, mid = "white", high = OKABE$vermillion,
                       midpoint = 0, limits = c(-vmax, vmax), na.value = PAL$missing,
                       breaks = c(-vmax, 0, vmax),
                       labels = c(paste0("\u2212", vmax), "0", paste0("+", vmax)),
                       name = "Rank change after adding DODJI",
                       guide = guide_colorbar(direction = "horizontal",
                                              barwidth = unit(24, "mm"),
                                              barheight = unit(1.2, "mm"),
                                              title.position = "top",
                                              title.hjust = 0.5)) +
  annotate("segment", x = 46, y = 24, xend = 21.6, yend = 41.7, colour = DARK,
           linewidth = pt2mm(0.6), lineend = "round") +
  annotate("point", x = 21.6, y = 41.7, size = 0.225, colour = INK) +
  annotate("text", x = 46, y = 24, label = "N. Macedonia\n+32 ranks", size = ggpt(FS_SMALL),
           fontface = "bold", colour = OKABE$vermillion, family = TNR,
           hjust = 0, lineheight = 0.95) +
  annotate("segment", x = -54, y = 61.5, xend = -3.6, yend = 54, colour = DARK,
           linewidth = pt2mm(0.6), lineend = "round") +
  annotate("point", x = -3.6, y = 54, size = 0.225, colour = INK) +
  annotate("text", x = -72, y = 63, label = "UK\n\u221238 ranks", size = ggpt(FS_SMALL),
           fontface = "bold", colour = OKABE$blue, family = TNR,
           hjust = 0, lineheight = 0.95) +
  annotate("segment", x = 54, y = 80, xend = 16, yend = 68, colour = DARK,
           linewidth = pt2mm(0.6), lineend = "round") +
  annotate("point", x = 16, y = 68, size = 0.225, colour = INK) +
  annotate("text", x = 54, y = 80, label = "Norway\n\u221235 ranks", size = ggpt(FS_SMALL),
           fontface = "bold", colour = OKABE$blue, family = TNR,
           hjust = 0, lineheight = 0.95) +
  coord_sf(xlim = c(-180, 180), ylim = c(-60, 90), expand = FALSE) +
  theme_panel() +
  theme(panel.background = element_rect(fill = "#EEF3F6", colour = NA),
        legend.position = c(0.75, 0.03),
        legend.direction = "horizontal",
        legend.title = element_text(size = FS_TINY - 1, face = "bold", colour = INK,
                                    family = TNR),
        legend.text = element_text(size = FS_TINY - 1, colour = DARK, family = TNR),
        legend.background = element_blank())
pc <- panel_title(pc, "c", "DODJI reorders national\npreparedness priorities")

## ======================================== panel d — reclassification matrix
quads <- data.frame(
  x = c(0.5, 5.2, 0.5, 5.2), y = c(5.3, 5.3, 0.9, 0.9),
  fg = c(GOLD, GREEN, RED, BLUE),
  count = c(n_up, n_stable + n_down, n_insuff, n_med),
  title = c("Lower burden\n+ surveillance concern", "Lower burden\n+ protected systems",
            "Weak visibility\n+ low reported rates", "Visible high burden\n+ implementation need"),
  subtitle = c("Upward movers", "Stable / down", "Insufficient data", "High-burden crises")
)

pd <- ggplot(quads) +
  geom_rect(aes(xmin = x, xmax = x + 4.3, ymin = y, ymax = y + 3.6, fill = I(fg),
                colour = I(fg)), alpha = 0.05, linewidth = pt2mm(1.0)) +
  geom_text(aes(x = x + 4.08, y = y + 0.22, label = count, colour = I(fg)),
            hjust = 1, vjust = 0, size = ggpt(FS_HERO), fontface = "bold", family = TNR) +
  geom_text(aes(x = x + 2.15, y = y + 2.55, label = title, colour = I(fg)),
            size = ggpt(FS_TINY), fontface = "bold", family = TNR, lineheight = 0.95) +
  geom_text(aes(x = x + 2.15, y = y + 1.55, label = subtitle), size = ggpt(FS_TINY),
            colour = MID, family = TNR) +
  scale_x_continuous(limits = c(0, 10)) +
  scale_y_continuous(limits = c(0, 10)) +
  coord_fixed() +
  theme_panel()
pd <- panel_title(pd, "d", "Upward movers cluster\nwhere data are weakest")

## =========================================== panel e — bivariate legend 5x5
n5 <- 5; dx <- 1.265; x0 <- 2.55; y0 <- 1.25
xs5 <- seq(0, 1, length.out = n5); ys5 <- seq(0, 1, length.out = n5)
lg <- expand.grid(j = 1:n5, i = 1:n5)
lg$x0 <- x0 + (lg$j - 1) * dx
lg$y0 <- y0 + (lg$i - 1) * dx
lg$fill <- bivariate_vec(xs5[lg$j], ys5[n5 + 1 - lg$i])
cx <- x0 + (n5 - 1) * dx / 2
top <- y0 + (n5 - 1) * dx + dx * 1.00
right <- x0 + (n5 - 1) * dx + dx * 1.00

corners <- data.frame(
  x = c(x0 - 0.16, right, x0 - 0.16, right),
  y = c(y0 - 0.16, y0 - 0.16, top + 0.16, top + 0.16),
  t = c("Low burden\n+ protected", "High burden\n+ protected",
        "Low burden\n+ weak data", "High burden\n+ weak data"),
  hjust = c(1, 1, 1, 1), vjust = c(1, 1, 0, 0),
  col = c(OKABE$sky, OKABE$blue, "#B8A200", OKABE$vermillion)
)

pe <- ggplot(lg) +
  geom_rect(aes(xmin = x0, xmax = x0 + dx * 1.00, ymin = y0, ymax = y0 + dx * 1.00,
                fill = I(fill)), colour = "white", linewidth = pt2mm(0.3)) +
  annotate("text", x = cx, y = top + 1.55, label = "Higher mortality burden \u2192",
           hjust = 0.5, vjust = 0, fontface = "bold", size = ggpt(FS_SMALL),
           colour = INK, family = TNR) +
  annotate("text", x = x0 - 0.95, y = y0 + (n5 - 1) * dx / 2 + 0.25,
           label = "Weaker surveillance \u2191", angle = 90, hjust = 0.5, vjust = 0.5,
           fontface = "bold", size = ggpt(FS_SMALL), colour = INK, family = TNR,
           lineheight = 1.0) +
  geom_text(data = corners, aes(x = x, y = y, label = t, colour = I(col),
                                hjust = hjust, vjust = vjust),
            fontface = "bold", size = ggpt(FS_TINY), family = TNR, lineheight = 0.9) +
  scale_x_continuous(limits = c(0, 10)) +
  scale_y_continuous(limits = c(0, 10)) +
  coord_fixed() +
  theme_panel()
pe <- panel_title(pe, "e", "How to read\nthe colours")

## ========================================= panel f — country story cards
df_f <- df
df_f$rank_change <- df_f$mortality_rank - df_f$combined_priority_rank
stories <- data.frame(
  country = c("United States of America", "Canada", "Albania",
              "North Macedonia", "United Kingdom", "Monaco"),
  note = c("High burden, visible crisis \u2192 implementation priority",
           "High burden, strong surveillance \u2192 early warning",
           "Moderate burden, weak visibility \u2192 surveillance investment",
           "Low reported rate, high DODJI \u2192 reclassified upward",
           "Lower burden, strong visibility \u2192 sustain monitoring",
           "Microstate, sparse events \u2192 interpret with caution"),
  stringsAsFactors = FALSE
)
stories <- merge(stories, df_f[, c("country", "regime", "mortality_rank",
                                   "dodji_score", "rank_change")],
                 by = "country", sort = FALSE)
stories$color <- REGIME_COLORS[stories$regime]
stories$short <- cshort(stories$country)
stories$stat <- vapply(seq_len(nrow(stories)), function(k) {
  r <- stories[k, ]
  if (r$country == "Monaco") return("+42 ranks \u00b7 sparse events")
  if (abs(r$rank_change) >= 10) {
    sgn <- if (r$rank_change > 0) "+" else "\u2212"
    return(paste0(sgn, abs(r$rank_change), " ranks \u00b7 DODJI ",
                  minus(sprintf("%.2f", r$dodji_score))))
  }
  paste0("burden rank ", as.integer(r$mortality_rank), " \u00b7 DODJI ",
         minus(sprintf("%.2f", r$dodji_score)))
}, character(1))

card_h <- 1.28; gap <- 0.16; top_y <- 9.62
cards <- stories
cards$y_top <- top_y - (seq_len(nrow(cards)) - 1) * (card_h + gap)
cards$y_bot <- cards$y_top - card_h

pf <- ggplot(cards) +
  geom_rect(aes(xmin = 0.15, xmax = 9.85, ymin = y_bot, ymax = y_top),
            fill = PAL$neutral_light, alpha = 0.16, colour = PAL$neutral_light,
            linewidth = pt2mm(0.6)) +
  geom_rect(aes(xmin = 0.34, xmax = 0.44, ymin = y_bot + 0.17, ymax = y_top - 0.17,
                fill = I(color)), colour = NA) +
  geom_text(aes(x = 0.66, y = y_top - 0.38, label = short), hjust = 0, vjust = 0.5,
            fontface = "bold", size = ggpt(FS_SMALL), colour = INK, family = TNR) +
  geom_text(aes(x = 9.72, y = y_top - 0.38, label = stat, colour = I(color)),
            hjust = 1, vjust = 0.5, fontface = "bold", size = ggpt(FS_TINY), family = TNR) +
  geom_text(aes(x = 0.66, y = y_top - 0.90, label = note), hjust = 0, vjust = 0.5,
            size = ggpt(FS_TINY), colour = DARK, family = TNR) +
  scale_x_continuous(limits = c(0, 10)) +
  scale_y_continuous(limits = c(0, 10)) +
  theme_panel()
pf <- panel_title(pf, "f", "Six countries,\nsix surveillance stories")

## ================================================================= composite
top_row <- plot_grid(pa, pb, pc, nrow = 1, rel_widths = c(2, 3.5, 3.5))
bot_row <- plot_grid(pd, pe, pf, nrow = 1, rel_widths = c(3, 2, 4))
final <- plot_grid(top_row, bot_row, ncol = 1, rel_heights = c(1, 1))

save_pub(final, OUT, "Figure1_surveillance_gap_nature", 183, 108)
message("Fig1 R redesign done -> ", OUT)
