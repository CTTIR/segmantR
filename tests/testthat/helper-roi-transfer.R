# Shared test fixtures for segmantR.
#
# Fixtures are deterministic: the identifier counter is reset where identifier
# stability matters, and nothing depends on wall-clock time or locale. Internal
# package objects are reachable directly from tests under testthat edition 3.

# ---- Image fixtures --------------------------------------------------------

# 10x10 single-band image for exact pixel arithmetic (the mask reference case).
tiny_image <- function() {
  .new_sg_roi_frame(
    source = "tiny.tif", backend = "raster",
    dims = c(10L, 10L), n_levels = 1L, level_dims = list(c(10L, 10L)),
    n_bands = 1L, dtype = "uint8"
  )
}

# 100x100 three-band pyramidal image.
small_image <- function() {
  .new_sg_roi_frame(
    source = "small.tif", backend = "tiff",
    dims = c(100L, 100L), n_levels = 3L,
    level_dims = list(c(100L, 100L), c(50L, 50L), c(25L, 25L)),
    n_bands = 3L, band_names = c("R", "G", "B"),
    pixel_size = c(0.5, 0.5), pixel_unit = "um", dtype = "uint16"
  )
}

# ---- ROI fixtures ----------------------------------------------------------

# An exact 3x3 square with lower-left corner at (2, 2): the mask reference ROI.
square_roi <- function(label = "square") {
  sg_roi_rect(2, 2, 5, 5, label = label)
}

# A triangle with vertices on exact pixel centres.
tri_roi <- function(label = "tri") {
  co <- matrix(c(1, 1, 8, 1, 4, 7), ncol = 2, byrow = TRUE)
  sg_roi_polygon(co, label = label)
}

# A polygon with a hole (a donut). The hole winds opposite the exterior ring.
donut_roi <- function(label = "donut") {
  outer <- matrix(c(0, 0, 10, 0, 10, 10, 0, 10), ncol = 2, byrow = TRUE)
  inner <- matrix(c(3, 3, 3, 7, 7, 7, 7, 3), ncol = 2, byrow = TRUE)
  sg_roi_polygon(list(outer, inner), label = label)
}

# Two deliberately overlapping rectangles.
overlap_pair <- function() {
  list(
    a = sg_roi_rect(0, 0, 6, 6, label = "a"),
    b = sg_roi_rect(4, 4, 10, 10, label = "b")
  )
}

# Raw, deliberately broken geometries (bypassing the constructor's repair) for
# testing sg_roi_check_geometry() / sg_roi_fix_geometry().
broken_geoms <- function() {
  sfc <- function(p) sf::st_sfc(p, crs = sf::NA_crs_)
  na_p <- sf::st_polygon(list(rbind(c(0, 0), c(5, 0), c(5, 5), c(0, 5), c(0, 0))))
  na_p[[1]][2, 1] <- NA_real_
  list(
    self_intersect = sfc(sf::st_polygon(list(rbind(
      c(0, 0), c(10, 10), c(10, 0), c(0, 10), c(0, 0)
    )))),
    zero_area = sfc(sf::st_polygon(list(rbind(
      c(0, 0), c(5, 0), c(10, 0), c(0, 0)
    )))),
    degenerate = sfc(sf::st_polygon(list(rbind(
      c(0, 0), c(5, 5), c(0, 0)
    )))),
    out_of_bounds = sfc(sf::st_polygon(list(rbind(
      c(0, 0), c(9999, 0), c(9999, 9999), c(0, 9999), c(0, 0)
    )))),
    na_coord = sfc(na_p),
    dup_vertex = sfc(sf::st_polygon(list(rbind(
      c(0, 0), c(0, 0), c(5, 0), c(5, 5), c(0, 0)
    )))),
    ring_orientation = sfc(sf::st_polygon(list(
      rbind(c(0, 0), c(10, 0), c(10, 10), c(0, 10), c(0, 0)),
      rbind(c(3, 3), c(7, 3), c(7, 7), c(3, 7), c(3, 3)) # same winding as exterior
    )))
  )
}

# Build a project holding a raw geometry under a given issue name.
broken_project <- function(name) {
  g <- broken_geoms()[[name]]
  roi <- .new_sg_roi(geometry = g, id = "broken_1", label = "broken", level = 0L)
  lyr <- sg_roi_layer("broken")
  lyr$rois <- list(roi)
  sg_roi_project(tiny_image(), lyr)
}

# ---- Project and session fixtures ------------------------------------------

# A populated project with two layers.
demo_project <- function() {
  .sg_roi_reset_id_counter()
  img <- small_image()
  tissue <- sg_roi_layer("tissue", labels = "tissue")
  tissue <- sg_roi_layer_add(tissue, sg_roi_rect(0, 0, 10, 10, label = "tissue"))
  tissue <- sg_roi_layer_add(tissue, sg_roi_circle(50, 50, 5, label = "tissue"))
  tumour <- sg_roi_layer("tumour", labels = "tumour", style = sg_roi_style(z = 2L))
  tumour <- sg_roi_layer_add(tumour, sg_roi_rect(20, 20, 40, 40, label = "tumour"))
  sg_roi_project(img, list(tissue, tumour), name = "demo")
}
