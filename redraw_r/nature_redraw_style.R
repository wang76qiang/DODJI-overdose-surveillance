## Nature-grade shared style for the DODJI figure redraw (R / ggplot2 engine).
## Mirrors redraw_py/nature_redraw_style.py: TNR serif, Profile v1.0 type scale,
## Okabe-Ito semantics, 183 mm composites, ragg PNG + cairo PDF export.
## Run scripts with the PROJECT ROOT as working directory.

suppressPackageStartupMessages({
  library(ggplot2)
  library(dplyr)
  library(tidyr)
  library(readr)
  library(cowplot)
})

## ---------------------------------------------------------------- type scale
FS_TAG <- 10; FS_TITLE <- 9; FS_LABEL <- 8; FS_TICK <- 7; FS_SMALL <- 6; FS_TINY <- 5
LW <- 1.5; LW_SPINE <- 1.2; LW_TICK <- 0.9; LEN_TICK <- 3.2

PT <- 2.845276          ## ggplot text size unit: size = pt / PT
ggpt <- function(x) x / PT
pt2mm <- function(x) x * 0.3527778   ## ggplot linewidth unit is mm

TNR <- "Times New Roman"

## ---------------------------------------------------------------- Okabe-Ito
OKABE <- list(blue = "#0072B2", sky = "#56B4E9", green = "#009E73",
              orange = "#E69F00", vermillion = "#D55E00", pink = "#CC79A7",
              yellow = "#F0E442", dark_blue = "#004488", gray = "#999999",
              green_dark = "#117733")

PAL <- list(
  blue_main = OKABE$blue, blue_secondary = OKABE$sky,
  green_1 = "#CCECE3", green_2 = "#99D9C9", green_3 = OKABE$green,
  red_1 = "#F7D7C2", red_2 = "#F0BC8A", red_strong = OKABE$vermillion,
  gold = OKABE$orange, violet = OKABE$pink, teal = OKABE$green,
  green_dark = OKABE$green_dark,
  neutral_black = "#272727", neutral_dark = "#4D4D4D", neutral_mid = "#767676",
  neutral_light = "#CCCCCC", gray = OKABE$gray, missing = "#CCCCCC"
)

REGIME_COLORS <- c("Medical-system-driven" = PAL$blue_main,
                   "Low-burden / protected" = PAL$green_3,
                   "Data-quality-limited" = PAL$gold,
                   "Insufficient exposure data" = PAL$red_strong)
REGIME_MARKERS <- c("Medical-system-driven" = 16, "Low-burden / protected" = 15,
                    "Data-quality-limited" = 18, "Insufficient exposure data" = 17)
STAGE_COLORS <- c("Foundation" = OKABE$gray, "Foundational-intermediate" = OKABE$blue,
                  "Intermediate" = OKABE$green, "Advanced" = OKABE$dark_blue)
STAGE_DISPLAY <- c("Foundation" = "Foundation", "Foundational-intermediate" = "Enhanced",
                   "Intermediate" = "Targeted", "Advanced" = "Advanced")
PRIORITY_COLORS <- c(OKABE$vermillion, OKABE$orange, OKABE$green, OKABE$blue)

REGIME_SHORT <- c("Medical-system-driven" = "Medical-system\ndriven",
                  "Low-burden / protected" = "Low-burden\n/ protected",
                  "Data-quality-limited" = "Data-quality\nlimited",
                  "Insufficient exposure data" = "Insufficient\nexposure data")
REGIME_ONELINE <- c("Medical-system-driven" = "Medical-system-driven",
                    "Low-burden / protected" = "Low-burden / protected",
                    "Data-quality-limited" = "Data-quality-limited",
                    "Insufficient exposure data" = "Insufficient exposure data")

PROJECT_ROOT <- getwd()
SRC_DIR <- file.path(PROJECT_ROOT, "figures_v21_authoritative", "source_data")
OUT_R <- file.path(PROJECT_ROOT, "figures_redraw_nature", "r")

cshort <- function(x) {
  repl <- c("United States of America" = "USA", "United Kingdom" = "UK",
            "Russian Federation" = "Russia", "North Macedonia" = "N. Macedonia")
  out <- x
  hit <- x %in% names(repl)
  out[hit] <- repl[x[hit]]
  out
}

## ---------------------------------------------------------------- theme
PANEL_TINT <- "#CCCCCC17"

theme_nature <- function(tag_inside = TRUE) {
  theme_classic(base_size = FS_LABEL, base_family = TNR) %+replace%
    theme(
      panel.background = element_rect(fill = PANEL_TINT, colour = NA),
      plot.background = element_rect(fill = "white", colour = NA),
      axis.line = element_line(colour = PAL$neutral_black, linewidth = pt2mm(LW_SPINE)),
      axis.ticks = element_line(colour = PAL$neutral_black, linewidth = pt2mm(LW_TICK)),
      axis.ticks.length = unit(pt2mm(LEN_TICK), "mm"),
      axis.text = element_text(colour = PAL$neutral_dark, size = FS_TICK, family = TNR),
      axis.title = element_text(colour = PAL$neutral_black, size = FS_LABEL,
                                face = "bold", family = TNR),
      plot.tag = element_text(face = "bold", size = FS_TAG, colour = PAL$neutral_black,
                              family = TNR),
      plot.tag.position = if (tag_inside) c(0.012, 0.985) else "topleft",
      plot.margin = margin(4, 4, 4, 4, "pt")
    )
}

theme_void_nature <- function() {
  theme_void(base_family = TNR) %+replace%
    theme(
      plot.tag = element_text(face = "bold", size = FS_TAG, colour = PAL$neutral_black,
                              family = TNR),
      plot.tag.position = "topleft",
      plot.margin = margin(12, 3, 3, 3, "pt")
    )
}

## ---------------------------------------------------------------- export
save_pub <- function(p, outdir, basename, width_mm, height_mm, dpi = 600) {
  dir.create(outdir, recursive = TRUE, showWarnings = FALSE)
  ragg::agg_png(file.path(outdir, paste0(basename, ".png")),
                width = width_mm, height = height_mm, units = "mm", res = dpi,
                background = "white")
  print(p)
  invisible(dev.off())
  grDevices::cairo_pdf(file.path(outdir, paste0(basename, ".pdf")),
                       width = width_mm / 25.4, height = height_mm / 25.4,
                       family = TNR, bg = "white")
  print(p)
  invisible(dev.off())
  message("saved: ", file.path(outdir, basename))
}

## ------------------------------------------------------- manual bar hatching
## Clipped 45-degree hatch segments inside a bar rect (x0,x1) x (0,y).
hatch_segments <- function(x0, x1, y, spacing = 0.85, slope = 1) {
  if (is.na(y) || y <= 0) return(NULL)
  s <- abs(slope)
  run <- y / s   # x distance for the line to climb the full bar height
  if (slope > 0) {
    starts <- seq(x0 - run, x1, by = spacing)
    seg <- lapply(starts, function(sx) {
      xa <- max(sx, x0); xb <- min(sx + run, x1)
      if (xb <= xa) return(NULL)
      data.frame(x = xa, xend = xb, y = (xa - sx) * s, yend = (xb - sx) * s)
    })
  } else {
    starts <- seq(x0, x1 + run, by = spacing)
    seg <- lapply(starts, function(sx) {
      xa <- max(sx - run, x0); xb <- min(sx, x1)
      if (xb <= xa) return(NULL)
      data.frame(x = xa, xend = xb, y = (sx - xa) * s, yend = (sx - xb) * s)
    })
  }
  do.call(rbind, seg)
}
