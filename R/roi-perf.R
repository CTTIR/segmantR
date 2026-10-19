.sg_roi_is_axis_aligned_rect <- function(geom) {
  if (length(unclass(geom)) != 1L) {
    return(FALSE)
  }
  ring <- geom[[1]]
  length(unique(round(ring[, 1], 9))) == 2L &&
    length(unique(round(ring[, 2], 9))) == 2L
}

# Fast, exact cover for rectangles and points (touches = FALSE only). Returns a
# logical [height, width] matrix identical to the general rasteriser, or NULL
# when no fast path applies. Uses the same half-open [lower, upper) convention:
# a pixel centre at k - 0.5 is covered when lower <= k - 0.5 < upper.
.sg_roi_cover_shortcircuit <- function(geom, dims) {
  type <- as.character(sf::st_geometry_type(sf::st_sfc(geom)))
  width <- as.integer(dims[1])
  height <- as.integer(dims[2])
  if (type == "POINT") {
    co <- as.numeric(unclass(geom))
    j <- as.integer(floor(co[1] - 1e-7)) + 1L
    i <- as.integer(floor(co[2] - 1e-7)) + 1L
    m <- matrix(FALSE, height, width)
    if (i >= 1L && i <= height && j >= 1L && j <= width) {
      m[i, j] <- TRUE
    }
    return(m)
  }
  if (type == "POLYGON" && .sg_roi_is_axis_aligned_rect(geom)) {
    ring <- geom[[1]]
    xmin <- min(ring[, 1]); xmax <- max(ring[, 1])
    ymin <- min(ring[, 2]); ymax <- max(ring[, 2])
    j1 <- max(1L, as.integer(ceiling(xmin + 0.5)))
    j2 <- min(width, as.integer(ceiling(xmax - 0.5)))
    i1 <- max(1L, as.integer(ceiling(ymin + 0.5)))
    i2 <- min(height, as.integer(ceiling(ymax - 0.5)))
    m <- matrix(FALSE, height, width)
    if (j1 <= j2 && i1 <= i2) {
      m[i1:i2, j1:j2] <- TRUE
    }
    return(m)
  }
  NULL
}
