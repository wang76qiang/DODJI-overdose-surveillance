## Figure 1 | The surveillance gap — EU-split redesign (R / ggplot2 + sf).
##
## Derived from redesign_r/fig1_surveillance_gap.R. Panels b and c are each
## split into TWO sub-panels: a full-world map of all 47 study countries plus
## a dedicated full-Europe panel (xlim -26..50, ylim 33.5..72.5) where every
## European study country is legible and the highlighted countries carry
## short direct labels instead of long ocean-spanning leader lines. A dashed
## rectangle on each world panel marks the Europe zoom extent.
##   a hero statistics + DODJI lens   b world + Europe bivariate maps
##   c world + Europe rank-change maps d reclassification matrix
##   e bivariate legend               f country story cards
##
## v2 changes vs eusplit:
##   - dashed connector lines from each world panel's Europe rectangle to the
##     Europe zoom panel (b1->b2, c1->c2)
##   - N. Macedonia label without box / white background
##   - bivariate key (b) and rank-change colorbar (c) moved OUTSIDE, below the
##     respective world panels
##   - panels b and c enlarged; overall composition redesigned (maps on top,
##     hero/matrix/legend/cards below)
##
## v2.1 changes vs v2:
##   - panel a moved to the TOP-LEFT corner; new 3-row reading order:
##     [a | b world+key | b Europe] / [d | c world+cbar | c Europe] / [e | f]
##   - bivariate key (b) hugs the lower edge of the world map (ggdraw overlay),
##     cells forced square via coord_fixed, "higher burden" label rotated
##     90 degrees counter-clockwise
##
## v2.2 changes vs v2.1:
##   - panel c maps sized IDENTICALLY to panel b: rows 1 and 2 share the same
##     height (rel_heights 1.30/1.30/1.00, canvas 183 x 146 mm) and c_col
##     mirrors b_col (colour bar extracted via get_legend into the bottom
##     strip, legend-free map in the top strip)
##   - "burden x surveillance, 47 countries" caption below the key deleted
##   - arrow after "higher burden" rotated 90 degrees counter-clockwise
##     (now points left, toward the colour grid)
##   - connector npc coordinates re-measured on the 4322x3448 px render
##
## v2.3 changes vs v2.2:
##   - key label arrows swapped: "higher burden" keeps the ORIGINAL arrow
##     glyph (unrotated \u2192; under the label's 90-degree rotation it
##     renders pointing up, as in v2.1), while the arrow after
##     "weaker surveillance" is rotated 90 degrees clockwise (renders as
##     \u2193, pointing down toward the colour grid)
##   - "Europe" titles above the two zoom panels (b2, c2) removed (empty
##     title kept so the panels stay aligned with the world maps and the
##     dashed connector coordinates remain valid)
##
## v2.4 changes vs v2.3:
##   - bivariate key moved right, now centred horizontally under the world
##     map in panel b
##   - key labels carry standalone axis arrows as long as their text:
##     "weaker surveillance" gets a right-pointing arrow below the text
##     (3.92 data units), "higher burden" gets an up-pointing arrow left of
##     the rotated text (2.75 data units)
##
## v2.5 changes vs v2.4:
##   - inter-cell gap of the 3x3 bivariate key narrowed to 1/10 of the
##     previous width (cell size 0.94 -> 0.994 data units)
##
## v2.6 changes vs v2.5:
##   - panel e heatmap cells enlarged to 120% (dx 1.265 -> 1.518); to fit all
##     labels the panel title is now one line ("How to read the colours") and
##     the y axis range is extended 10 -> 11.1, keeping the physical unit
##     size (and thus the full 120% growth) intact
##   - panel f story cards 20% taller (card_h 1.28 -> 1.536); card gap
##     narrowed 0.16 -> 0.10 and text rows repositioned proportionally so the
##     six cards still fit the [0, 10] canvas
##
## v2.7 changes vs v2.6:
##   - panel e axis arrows moved off the text and lengthened to full text
##     size (widths measured with systemfonts at the render's 62.6 px/unit:
##     'Higher mortality burden' = 8.79 units wide, 'Weaker surveillance' =
##     7.32 units tall): burden arrow sits BELOW its text pointing right,
##     surveillance arrow to the RIGHT of its rotated text pointing up
##   - panel e top corner labels lowered (top+0.16 -> top+0.05) and ylim
##     extended 11.1 -> 11.4 to stack title + arrow without clipping
##     (heatmap cells end up 93 px = 116% of the original 80 px)
##
## Output: figures_redraw_nature_v2/r/Figure1_surveillance_gap_nature_eusplit_v2
## (neither Figure1_surveillance_gap_nature.* nor the eusplit v1 is overwritten).
##
## Run from the PROJECT ROOT:  Rscript redesign_r/fig1_surveillance_gap_eusplit_v2.R

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

ellipse_df <- function(cx, cy, rx, ry, n = 120) {
  a <- seq(0, 2 * pi, length.out = n)
  data.frame(x = cx + rx * cos(a), y = cy + ry * sin(a))
}

minus <- function(x) gsub("-", "\u2212", x)

## Europe zoom extent (shared by both split panels and the world-map markers)
EU_X <- c(-26, 50); EU_Y <- c(33.5, 72.5)

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
w_tot <- 8.0
w_dn <- w_tot * n_down / n_all
w_st <- w_tot * n_stable / n_all
x_dn <- c(1.0, 1.0 + w_dn)
x_st <- c(1.0 + w_dn, 1.0 + w_dn + w_st)
x_up <- c(1.0 + w_dn + w_st, 9.0)
bar_y <- c(4.35, 5.75)

pa <- ggplot() +
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
pa <- panel_title(pa, "a", "11 countries rise,\n11 more fall in priority")

## ==================================== panel b1 — bivariate map, full world
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

## 3x3 bivariate key — now a standalone strip placed BELOW the world panel
xs3 <- seq(0, 1, length.out = 3); ys3 <- seq(0, 1, length.out = 3)
key <- expand.grid(j = 1:3, i = 1:3)
key$x0 <- (key$j - 1) * 1.0
key$y0 <- (key$i - 1) * 1.0
key$fill <- bivariate_vec(xs3[key$j], ys3[4 - key$i])

pb_key <- ggplot(key) +
  ## v2.5: inter-cell gap narrowed to 1/10 of the previous width (0.06 -> 0.006)
  geom_rect(aes(xmin = x0, xmax = x0 + 0.994, ymin = y0, ymax = y0 + 0.994,
                fill = I(fill)), colour = "white", linewidth = 0.2) +
  ## v2.4: labels carry separate axis arrows, each as long as its text
  ## (text lengths measured on the 4322x3448 px render: 'weaker surveillance'
  ## = 3.92 data units wide, 'higher burden' = 2.75 data units tall)
  ## "weaker surveillance": arrow BELOW the text, spanning the text width
  annotate("text", x = 0, y = 3.40, label = "weaker surveillance",
           size = ggpt(FS_TINY), fontface = "bold", colour = DARK, family = TNR,
           hjust = 0, vjust = 0) +
  annotate("segment", x = 0, xend = 3.92, y = 3.15, yend = 3.15, colour = DARK,
           linewidth = pt2mm(0.8), lineend = "round",
           arrow = grid::arrow(type = "closed", length = grid::unit(0.9, "mm"), angle = 22)) +
  ## "higher burden" rotated 90 degrees counter-clockwise, right of the key;
  ## arrow to the LEFT of the text, spanning the text height
  annotate("text", x = 3.82, y = 1.5, label = "higher burden",
           size = ggpt(FS_TINY), fontface = "bold", colour = DARK, family = TNR,
           angle = 90, hjust = 0.5, vjust = 0.5) +
  annotate("segment", x = 3.40, xend = 3.40, y = 0.13, yend = 2.88, colour = DARK,
           linewidth = pt2mm(0.8), lineend = "round",
           arrow = grid::arrow(type = "closed", length = grid::unit(0.9, "mm"), angle = 22)) +
  scale_x_continuous(limits = c(0, 4.35), expand = c(0, 0)) +
  scale_y_continuous(limits = c(-0.12, 4.05), expand = c(0, 0)) +
  coord_fixed() +
  theme_void() +
  theme(plot.margin = margin(0, 0, 0, 0, "pt"))

pb_world <- ggplot(world_b) +
  geom_sf(aes(fill = I(fill)), colour = "white", linewidth = 0.08) +
  ## USA: sole non-European callout on the world panel
  annotate("segment", x = -157, y = 26, xend = -98, yend = 39.5, colour = DARK,
           linewidth = pt2mm(0.6), lineend = "round") +
  annotate("point", x = -98, y = 39.5, size = 0.225, colour = INK) +
  annotate("text", x = -170, y = 24, label = "USA", size = ggpt(FS_SMALL),
           fontface = "bold", colour = INK, family = TNR, hjust = 0) +
  ## dashed marker of the Europe zoom extent
  annotate("rect", xmin = EU_X[1], xmax = EU_X[2], ymin = EU_Y[1], ymax = EU_Y[2],
           fill = NA, colour = DARK, linetype = "dashed", linewidth = pt2mm(0.5)) +
  coord_sf(xlim = c(-180, 180), ylim = c(-60, 90), expand = FALSE) +
  theme_panel() +
  theme(panel.background = element_rect(fill = "#EEF3F6", colour = NA),
        plot.margin = margin(4, 4, 0, 4, "pt"))
pb_world <- panel_title(pb_world, "b", "Burden and visibility\ndiverge worldwide")

## ======================================= panel b2 — bivariate map, Europe
pb_eu <- ggplot(world_b) +
  geom_sf(aes(fill = I(fill)), colour = "white", linewidth = 0.10) +
  ## Iceland: direct short label west of the island
  annotate("segment", x = -20.8, y = 65.9, xend = -18.44, yend = 64.98, colour = DARK,
           linewidth = pt2mm(0.5), lineend = "round") +
  annotate("point", x = -18.44, y = 64.98, size = 0.225, colour = INK) +
  annotate("text", x = -25.5, y = 66.6, label = "Iceland", size = ggpt(FS_SMALL),
           fontface = "bold", colour = INK, family = TNR, hjust = 0) +
  ## UK: label over the Atlantic west of the British Isles
  annotate("segment", x = -7.2, y = 56.6, xend = -3.6, yend = 54, colour = DARK,
           linewidth = pt2mm(0.5), lineend = "round") +
  annotate("point", x = -3.6, y = 54, size = 0.225, colour = INK) +
  annotate("text", x = -11.5, y = 57.6, label = "UK", size = ggpt(FS_SMALL),
           fontface = "bold", colour = INK, family = TNR, hjust = 0) +
  ## Albania: two-line label over open Mediterranean south of the country
  annotate("segment", x = 20.1, y = 39.0, xend = 20.1, yend = 41.3, colour = DARK,
           linewidth = pt2mm(0.5), lineend = "round") +
  annotate("point", x = 20.1, y = 41.3, size = 0.225, colour = INK) +
  annotate("text", x = 20.1, y = 36.9, label = "Albania\nDODJI 2.30", size = ggpt(FS_TINY),
           fontface = "bold", colour = INK, family = TNR, hjust = 0.5, lineheight = 0.95) +
  coord_sf(xlim = EU_X, ylim = EU_Y, expand = FALSE) +
  theme_panel() +
  theme(panel.background = element_rect(fill = "#EEF3F6", colour = NA))
pb_eu <- panel_title(pb_eu, "", "")

## =================================== panel c1 — rank-change map, full world
df_c <- df
df_c$rank_change <- df_c$mortality_rank - df_c$combined_priority_rank
df_c$shape <- shape_name(df_c$country)
vmax <- max(abs(df_c$rank_change))   ## 42

world_c <- world
world_c$rc <- NA_real_
idxc <- match(world_c$NAME_EN, df_c$shape)
hitc <- !is.na(idxc)
world_c$rc[hitc] <- df_c$rank_change[idxc[hitc]]

pc_world <- ggplot(world_c) +
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
  annotate("rect", xmin = EU_X[1], xmax = EU_X[2], ymin = EU_Y[1], ymax = EU_Y[2],
           fill = NA, colour = DARK, linetype = "dashed", linewidth = pt2mm(0.5)) +
  coord_sf(xlim = c(-180, 180), ylim = c(-60, 90), expand = FALSE) +
  theme_panel() +
  theme(panel.background = element_rect(fill = "#EEF3F6", colour = NA),
        legend.position = "bottom",
        legend.direction = "horizontal",
        legend.title = element_text(size = FS_TINY - 1, face = "bold", colour = INK,
                                    family = TNR),
        legend.text = element_text(size = FS_TINY - 1, colour = DARK, family = TNR),
        legend.background = element_blank(),
        legend.margin = margin(t = 1, b = 0))
pc_world <- panel_title(pc_world, "c", "DODJI reorders national\npreparedness priorities")

## pull the colour bar out of the map so the map panel itself can be sized
## identically to panel b's world map (legend goes into the bottom strip)
pc_legend <- cowplot::get_legend(pc_world)
pc_world_map <- pc_world +
  theme(legend.position = "none",
        plot.margin = margin(4, 4, 0, 4, "pt"))

## ====================================== panel c2 — rank-change map, Europe
pc_eu <- ggplot(world_c) +
  geom_sf(aes(fill = rc), colour = "white", linewidth = 0.10) +
  scale_fill_gradient2(low = OKABE$blue, mid = "white", high = OKABE$vermillion,
                       midpoint = 0, limits = c(-vmax, vmax), na.value = PAL$missing,
                       guide = "none") +
  ## UK: label over open ocean north-west of Scotland
  annotate("segment", x = -6.8, y = 56.8, xend = -3.6, yend = 54, colour = DARK,
           linewidth = pt2mm(0.5), lineend = "round") +
  annotate("point", x = -3.6, y = 54, size = 0.225, colour = INK) +
  annotate("text", x = -12, y = 60.5, label = "UK\n\u221217 ranks", size = ggpt(FS_TINY),
           fontface = "bold", colour = OKABE$blue, family = TNR,
           hjust = 0.5, lineheight = 0.95) +
  ## Norway: dot on the mainland, label over the open Norwegian Sea
  annotate("segment", x = 8.5, y = 67.3, xend = 16, yend = 68, colour = DARK,
           linewidth = pt2mm(0.5), lineend = "round") +
  annotate("point", x = 16, y = 68, size = 0.225, colour = INK) +
  annotate("text", x = -1, y = 66.8, label = "Norway\n\u221215 ranks", size = ggpt(FS_TINY),
           fontface = "bold", colour = OKABE$blue, family = TNR,
           hjust = 0.5, lineheight = 0.95) +
  ## N. Macedonia: white-chip label north of the country, short leader
  annotate("segment", x = 21.6, y = 43.0, xend = 21.6, yend = 41.7, colour = DARK,
           linewidth = pt2mm(0.5), lineend = "round") +
  annotate("point", x = 21.6, y = 41.7, size = 0.225, colour = INK) +
  annotate("text", x = 21.6, y = 44.6, label = "N. Macedonia\n+21 ranks", size = ggpt(FS_TINY),
           fontface = "bold", colour = OKABE$vermillion, family = TNR,
           hjust = 0.5, lineheight = 0.95) +
  coord_sf(xlim = EU_X, ylim = EU_Y, expand = FALSE) +
  theme_panel() +
  theme(panel.background = element_rect(fill = "#EEF3F6", colour = NA))
pc_eu <- panel_title(pc_eu, "", "")

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
## v2.6: heatmap cells enlarged to 120% (dx 1.265 -> 1.518). To keep every
## label unclipped the panel title is set on ONE line (frees ~4 mm of strip
## height for the plot region) and the y axis range is extended 10 -> 11.1,
## which keeps the physical unit size unchanged so the heatmap grows by the
## full 120%. Grid re-anchored: x0 2.55 -> 1.9175 (centred), y0 -> 1.45;
## rotated "Weaker surveillance" label centred on the grid centre.
n5 <- 5; dx <- 1.518; x0 <- 1.9175; y0 <- 1.45
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
  y = c(y0 - 0.16, y0 - 0.16, top + 0.05, top + 0.05),
  t = c("Low burden\n+ protected", "High burden\n+ protected",
        "Low burden\n+ weak data", "High burden\n+ weak data"),
  hjust = c(1, 1, 1, 1), vjust = c(1, 1, 0, 0),
  col = c(OKABE$sky, OKABE$blue, "#B8A200", OKABE$vermillion)
)

pe <- ggplot(lg) +
  geom_rect(aes(xmin = x0, xmax = x0 + dx * 1.00, ymin = y0, ymax = y0 + dx * 1.00,
                fill = I(fill)), colour = "white", linewidth = pt2mm(0.3)) +
  ## v2.7: arrows moved off the text and lengthened to the full text size
  ## (widths measured with systemfonts on the render's 62.6 px/unit scale:
  ## 'Higher mortality burden' = 8.79 units wide, 'Weaker surveillance' =
  ## 7.32 units tall). Burden arrow sits BELOW its text, surveillance arrow
  ## to the RIGHT of its rotated text, pointing up. Top corner labels
  ## lowered (top+0.16 -> top+0.05) and ylim extended 11.1 -> 11.4 to make
  ## room for the stacked title + arrow without clipping.
  annotate("text", x = cx, y = 10.70, label = "Higher mortality burden",
           hjust = 0.5, vjust = 0, fontface = "bold", size = ggpt(FS_SMALL),
           colour = INK, family = TNR) +
  annotate("segment", x = cx - 4.39, xend = cx + 4.39, y = 10.40, yend = 10.40,
           colour = INK, linewidth = pt2mm(0.8), lineend = "round",
           arrow = grid::arrow(type = "closed", length = grid::unit(0.9, "mm"), angle = 22)) +
  annotate("text", x = x0 - 0.95, y = y0 + n5 * dx / 2,
           label = "Weaker surveillance", angle = 90, hjust = 0.5, vjust = 0.5,
           fontface = "bold", size = ggpt(FS_SMALL), colour = INK, family = TNR,
           lineheight = 1.0) +
  annotate("segment", x = x0 - 0.45, xend = x0 - 0.45,
           y = y0 + n5 * dx / 2 - 3.66, yend = y0 + n5 * dx / 2 + 3.66,
           colour = INK, linewidth = pt2mm(0.8), lineend = "round",
           arrow = grid::arrow(type = "closed", length = grid::unit(0.9, "mm"), angle = 22)) +
  geom_text(data = corners, aes(x = x, y = y, label = t, colour = I(col),
                                hjust = hjust, vjust = vjust),
            fontface = "bold", size = ggpt(FS_TINY), family = TNR, lineheight = 0.9) +
  scale_x_continuous(limits = c(-3.2, 10.3)) +
  scale_y_continuous(limits = c(0, 11.4)) +
  coord_fixed() +
  theme_panel()
pe <- panel_title(pe, "e", "How to read the colours")

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
           "High burden, strong visibility \u2192 sustain monitoring",
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
  if (r$country == "Monaco") return(paste0("+", abs(r$rank_change), " ranks \u00b7 sparse events"))
  if (abs(r$rank_change) >= 10) {
    sgn <- if (r$rank_change > 0) "+" else "\u2212"
    return(paste0(sgn, abs(r$rank_change), " ranks \u00b7 DODJI ",
                  minus(sprintf("%.2f", r$dodji_score))))
  }
  paste0("burden rank ", as.integer(r$mortality_rank), " \u00b7 DODJI ",
         minus(sprintf("%.2f", r$dodji_score)))
}, character(1))

## v2.6: card height +20% (1.28 -> 1.536); gap narrowed 0.16 -> 0.10 and
## top_y raised so the six taller cards still fit the [0, 10] canvas;
## text rows repositioned proportionally (0.38->0.46, 0.90->1.08)
card_h <- 1.536; gap <- 0.10; top_y <- 9.85
cards <- stories
cards$y_top <- top_y - (seq_len(nrow(cards)) - 1) * (card_h + gap)
cards$y_bot <- cards$y_top - card_h

pf <- ggplot(cards) +
  geom_rect(aes(xmin = 0.15, xmax = 9.85, ymin = y_bot, ymax = y_top),
            fill = PAL$neutral_light, alpha = 0.16, colour = PAL$neutral_light,
            linewidth = pt2mm(0.6)) +
  geom_rect(aes(xmin = 0.34, xmax = 0.44, ymin = y_bot + 0.17, ymax = y_top - 0.17,
                fill = I(color)), colour = NA) +
  geom_text(aes(x = 0.66, y = y_top - 0.46, label = short), hjust = 0, vjust = 0.5,
            fontface = "bold", size = ggpt(FS_SMALL), colour = INK, family = TNR) +
  geom_text(aes(x = 9.72, y = y_top - 0.46, label = stat, colour = I(color)),
            hjust = 1, vjust = 0.5, fontface = "bold", size = ggpt(FS_TINY), family = TNR) +
  geom_text(aes(x = 0.66, y = y_top - 1.08, label = note), hjust = 0, vjust = 0.5,
            size = ggpt(FS_TINY), colour = DARK, family = TNR) +
  scale_x_continuous(limits = c(0, 10)) +
  scale_y_continuous(limits = c(0, 10)) +
  theme_panel()
pf <- panel_title(pf, "f", "Six countries,\nsix surveillance stories")

## ================================================================= composite
## v2.1 layout redesign:
##   - panel a moved to the TOP-LEFT corner (reading order a,b,c,d,e,f)
##   - bivariate key (b) hugs the lower edge of the world map, square cells,
##     "higher burden" label rotated 90 degrees counter-clockwise
##   - three rows: [a | b world+key | b Europe]
##                 [d | c world+cbar | c Europe]
##                 [e | f story cards (spanning)]
## Key geometry: coord_fixed data aspect 4.35 x 4.17; the draw box matches
## that aspect so the key fills its box exactly (no centring gap) and its top
## edge sits flush against the world-map canvas bottom.
FIG_W <- 183; FIG_H <- 146
BCOL_W_MM <- FIG_W * 3.0 / (2.4 + 3.0 + 2.2)
ROW1_H_MM <- FIG_H * 1.30 / (1.30 + 1.30 + 1.00)
KEY_FRAC <- 0.30                     ## bottom strip height as npc of the column
KEY_W <- (KEY_FRAC * ROW1_H_MM * (4.35 / 4.17)) / BCOL_W_MM
b_col <- ggdraw() +
  draw_plot(pb_world, x = 0, y = KEY_FRAC, width = 1, height = 1 - KEY_FRAC) +
  ## v2.4: key centred horizontally under the world map
  draw_plot(pb_key, x = (1 - KEY_W) / 2, y = 0, width = KEY_W, height = KEY_FRAC)

## c_col mirrors b_col exactly (same canvas split, same widths, same row
## height) so the c maps render at the identical size/proportion as b's.
c_col <- ggdraw() +
  draw_plot(pc_world_map, x = 0, y = KEY_FRAC, width = 1, height = 1 - KEY_FRAC) +
  draw_grob(pc_legend, x = 0.5, y = KEY_FRAC / 2, hjust = 0.5, vjust = 0.5)

row1 <- plot_grid(pa, b_col, pb_eu, nrow = 1, rel_widths = c(2.4, 3.0, 2.2))
row2 <- plot_grid(pd, c_col, pc_eu, nrow = 1, rel_widths = c(2.4, 3.0, 2.2))
row3 <- plot_grid(pe, pf, nrow = 1, rel_widths = c(2.4, 5.2))
final <- plot_grid(row1, row2, row3, ncol = 1, rel_heights = c(1.30, 1.30, 1.00))

## dashed connector lines: Europe rectangle (world panels) -> Europe zoom panels
## npc coordinates measured on the 4322x3448 px render (600 dpi, 183x146 mm):
##   b world map px x[1492,2989] y[225,870] -> rect right edge lon 50 @ px 2448,
##     lat 72.5 @ px 300, lat 33.5 @ px 468; b Europe panel left edge npc x 0.7182
##   c world map px x[1487,2985] y[1470,2115] -> rect right edge px 2444,
##     lat 72.5 @ px 1545, lat 33.5 @ px 1713; c Europe panel left edge npc x 0.7182
px2npc <- data.frame(
  x    = c(2448, 2448, 2444, 2444) / 4322,
  y    = 1 - c(300, 468, 1545, 1713) / 3448,
  xend = c(0.7182, 0.7182, 0.7182, 0.7182),
  yend = c(0.9490, 0.6566, 0.5879, 0.2955)
)
CONNECT <- px2npc
final <- ggdraw(final)
if (nrow(CONNECT) > 0) {
  seg <- grid::segmentsGrob(x0 = CONNECT$x, y0 = CONNECT$y,
                            x1 = CONNECT$xend, y1 = CONNECT$yend,
                            default.units = "npc",
                            gp = grid::gpar(col = MID, lty = "dashed", lwd = 0.7))
  final <- final + draw_grob(seg)
}

save_pub(final, OUT, "Figure1_surveillance_gap_nature_eusplit_v2", FIG_W, FIG_H)
message("Fig1 EU-split redesign v2 done -> ", OUT)
