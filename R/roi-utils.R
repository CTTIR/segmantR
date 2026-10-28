# Internal utilities shared across segmantR. None of these are exported.

# ---- Identifiers -----------------------------------------------------------

# Monotonic per-session counter used to mint identifiers. An environment is
# used deliberately (rather than `<<-`) to hold mutable state at package level.
.sg_roi_id_state <- new.env(parent = emptyenv())
.sg_roi_id_state$n <- 0L

# Reset the identifier counter. Exposed only for reproducible tests; not
# exported.
.sg_roi_reset_id_counter <- function() {
  .sg_roi_id_state$n <- 0L
  invisible(NULL)
}

# Mint a new identifier with the given prefix, e.g. "roi_000000001".
#
# Uses a monotonic counter rather than the random-number generator, so it never
# disturbs the caller's RNG stream and is fully deterministic within a session.
# Uniqueness within a project is additionally guaranteed on insertion, where a
# colliding identifier (e.g. from a loaded project) is re-minted.
.sg_roi_new_id <- function(prefix = "roi") {
  .sg_roi_id_state$n <- .sg_roi_id_state$n + 1L
  sprintf("%s_%09d", prefix, .sg_roi_id_state$n)
}

# ---- Time and version ------------------------------------------------------

# Current time as a length-1 POSIXct. Wrapped so the point of truth is single.
.sg_roi_now <- function() Sys.time()

# Installed segmantR version as a character scalar.
.sg_roi_pkg_version <- function() as.character(utils::packageVersion("segmantR"))

# Default author for new annotations: the `segmantR.author` option if set,
# otherwise the current system user, otherwise "unknown".
.sg_roi_default_author <- function() {
  opt <- getOption("segmantR.author", default = NULL)
  if (.sg_roi_is_string(opt)) {
    return(opt)
  }
  user <- tryCatch(Sys.info()[["user"]], error = function(e) NA_character_)
  if (.sg_roi_is_string(user) && nzchar(user)) user else "unknown"
}

# ---- The ROI query contract ------------------------------------------------

# The single source of truth for the tibble returned by `sg_roi_rois()` and every
# other function that yields an ROI table. Returns a 0-row tibble with exactly
# the contracted columns and column types. See `sg_roi_rois()` for the documented
# contract.
.sg_roi_empty_roi_tbl <- function() {
  tibble::tibble(
    roi_id     = character(0),
    layer      = character(0),
    label      = character(0),
    geom_type  = character(0),
    level      = integer(0),
    area_px    = double(0),
    centroid_x = double(0),
    centroid_y = double(0),
    n_vertices = integer(0),
    created    = .sg_roi_empty_posixct(),
    modified   = .sg_roi_empty_posixct(),
    author     = character(0),
    source     = character(0),
    geometry   = sf::st_sfc(crs = sf::NA_crs_)
  )
}

# A length-0 POSIXct with a stable class, for building empty tibbles.
.sg_roi_empty_posixct <- function() {
  as.POSIXct(numeric(0), origin = "1970-01-01", tz = "UTC")
}

# ---- Level transforms for the query contract -------------------------------

# Transform an sfc from `level` to level 0. Uses the real pyramid ratio from an
# sg_roi_frame when one is supplied (accurate for non-power-of-two pyramids),
# otherwise assumes a power-of-two pyramid.
.sg_roi_to_level0 <- function(geom, level, image = NULL) {
  if (level == 0L) {
    return(geom)
  }
  if (inherits(image, "sg_roi_frame") && length(image$level_dims) > level) {
    d0 <- image$level_dims[[1L]]
    dl <- image$level_dims[[level + 1L]]
    fx <- d0[1] / dl[1]
    fy <- d0[2] / dl[2]
    out <- lapply(geom, .sg_roi_apply_coords,
                  fun = function(m) cbind(m[, 1] * fx, m[, 2] * fy))
    return(sf::st_sfc(out, crs = sf::st_crs(geom)))
  }
  factor <- 2^(level - 0L)
  out <- lapply(geom, .sg_roi_apply_coords, fun = function(m) m * factor)
  sf::st_sfc(out, crs = sf::st_crs(geom))
}

# Transform an sfc from level 0 to `level`, using the real image pyramid ratio
# when an sg_roi_frame is supplied (correct for non-power-of-two pyramids),
# otherwise assuming a power-of-two pyramid. Inverse direction of .sg_roi_to_level0().
.sg_roi_geom_to_level <- function(geom, level, image = NULL) {
  if (level == 0L) {
    return(geom)
  }
  if (inherits(image, "sg_roi_frame") && length(image$level_dims) > level) {
    d0 <- image$level_dims[[1L]]
    dl <- image$level_dims[[level + 1L]]
    fx <- dl[1] / d0[1]
    fy <- dl[2] / d0[2]
    out <- lapply(geom, .sg_roi_apply_coords,
                  fun = function(m) cbind(m[, 1] * fx, m[, 2] * fy))
    return(sf::st_sfc(out, crs = sf::st_crs(geom)))
  }
  .sg_roi_rescale_geom(geom, 0L, level)
}

# Build the ROI query-contract tibble from a list of sg_roi and a matching
# vector of layer names. Coordinates, area, and centroid are expressed at level
# 0; the `level` column records each ROI's original reference level. Returns the
# canonical 0-row tibble when `rois` is empty.
.sg_roi_rois_to_tbl <- function(rois, layers, image = NULL) {
  if (length(rois) == 0L) {
    return(.sg_roi_empty_roi_tbl())
  }
  n <- length(rois)
  geoms <- lapply(rois, function(r) .sg_roi_to_level0(r$geometry, r$level, image))
  geometry <- do.call(c, geoms)
  gtype <- vapply(
    geoms, function(g) as.character(sf::st_geometry_type(g)), character(1)
  )
  areal <- gtype %in% c("POLYGON", "MULTIPOLYGON")
  area <- vapply(
    seq_len(n),
    function(i) if (areal[i]) as.numeric(sf::st_area(geoms[[i]])) else NA_real_,
    numeric(1)
  )
  cen <- t(vapply(
    geoms,
    function(g) {
      co <- sf::st_coordinates(suppressWarnings(sf::st_centroid(g)))
      c(co[1, "X"], co[1, "Y"])
    },
    numeric(2)
  ))
  nv <- vapply(geoms, function(g) nrow(sf::st_coordinates(g)), integer(1))
  tibble::tibble(
    roi_id     = vapply(rois, `[[`, character(1), "id"),
    layer      = as.character(layers),
    label      = vapply(rois, `[[`, character(1), "label"),
    geom_type  = gtype,
    level      = vapply(rois, function(r) as.integer(r$level), integer(1)),
    area_px    = area,
    centroid_x = cen[, 1],
    centroid_y = cen[, 2],
    n_vertices = nv,
    created    = do.call(c, lapply(rois, `[[`, "created")),
    modified   = do.call(c, lapply(rois, `[[`, "modified")),
    author     = vapply(rois, `[[`, character(1), "author"),
    source     = vapply(rois, `[[`, character(1), "source"),
    geometry   = geometry
  )
}

# ---- Colour palette --------------------------------------------------------

# The Okabe-Ito colourblind-safe qualitative palette (8 colours), used as the
# default for ROI/label styling. Order is the canonical Okabe-Ito order,
# beginning with a neutral grey.
.sg_roi_okabe_ito <- function() {
  c(
    "#999999", "#E69F00", "#56B4E9", "#009E73",
    "#F0E442", "#0072B2", "#D55E00", "#CC79A7"
  )
}

# Resolve a stable label -> colour mapping. `colour` may be NULL (cycle the
# Okabe-Ito palette over the labels), a single colour (recycled), or a named or
# unnamed character vector of colours. The returned vector is always named by
# `labels` (followed by named colours of labels not in use yet) so the mapping
# is stable across sessions. Without labels a supplied `colour` is kept as
# given, so the labels added later still receive it.
.sg_roi_resolve_palette <- function(labels, colour = NULL) {
  labels <- unique(as.character(labels))
  n <- length(labels)
  if (n == 0L) {
    if (length(colour) > 0L) return(colour)
    out <- character(0)
    names(out) <- character(0)
    return(out)
  }
  pal <- .sg_roi_okabe_ito()
  if (is.null(colour)) {
    out <- pal[((seq_len(n) - 1L) %% length(pal)) + 1L]
    names(out) <- labels
    return(out)
  }
  nms <- names(colour)
  colour <- as.character(colour)
  names(colour) <- nms
  if (!is.null(names(colour))) {
    out <- rep(pal[1], n)
    names(out) <- labels
    common <- intersect(labels, names(colour))
    out[common] <- colour[common]
    # Fill any labels not named in `colour` by cycling the palette.
    missing <- setdiff(labels, names(colour))
    if (length(missing)) {
      idx <- match(missing, labels)
      out[missing] <- pal[((idx - 1L) %% length(pal)) + 1L]
    }
    # Keep the named colours of labels not in use yet, so a label added
    # later still receives its colour.
    unused <- setdiff(names(colour), c(labels, "", NA))
    out <- c(out, colour[unused])
    return(out)
  }
  out <- rep(colour, length.out = n)
  names(out) <- labels
  out
}

# ---- Geometry orientation --------------------------------------------------

# Flip the y-axis of an sfc between image orientation (top-left origin, y down)
# and GIS orientation (bottom-left origin, y up), given the image height in
# pixels. Self-inverse. Internal; used at the boundaries with GIS-oriented
# tooling. `height` is the extent along y at the geometry's reference level.
.sg_roi_flip_y <- function(geom, height) {
  if (!inherits(geom, "sfc")) {
    .sg_roi_at_abort("{.arg geom} must be an {.cls sfc}.")
  }
  flip <- function(m) {
    m[, 2] <- height - m[, 2]
    m
  }
  out <- lapply(geom, .sg_roi_apply_coords, fun = flip)
  sf::st_sfc(out, crs = sf::st_crs(geom))
}

# Apply a coordinate-matrix transform `fun` to every ring/part of a single
# sfg geometry, preserving its type. Handles POINT, MULTIPOINT, LINESTRING,
# POLYGON, MULTILINESTRING, and MULTIPOLYGON.
.sg_roi_apply_coords <- function(g, fun) {
  type <- as.character(sf::st_geometry_type(sf::st_sfc(g)))
  switch(
    type,
    "POINT"           = sf::st_point(fun(matrix(unclass(g), nrow = 1))),
    "MULTIPOINT"      = sf::st_multipoint(fun(unclass(g))),
    "LINESTRING"      = sf::st_linestring(fun(unclass(g))),
    "MULTILINESTRING" = sf::st_multilinestring(lapply(g, fun)),
    "POLYGON"         = sf::st_polygon(lapply(g, fun)),
    "MULTIPOLYGON"    = sf::st_multipolygon(lapply(g, function(p) lapply(p, fun))),
    cli::cli_abort("Unsupported geometry type {.val {type}} in {.fn .sg_roi_apply_coords}.")
  )
}

# ---- Small helpers ---------------------------------------------------------

# Vector-safe test for a single non-missing string.
.sg_roi_is_string <- function(x) is.character(x) && length(x) == 1L && !is.na(x)

# Coerce to integer, erroring on loss. Internal convenience.
.sg_roi_as_count <- function(x) {
  xi <- suppressWarnings(as.integer(round(x)))
  xi
}
