#' Marker-controlled watershed segmentation
#'
#' Segments cells using a marker-controlled watershed algorithm.
#' Seeds (markers) are detected automatically via distance-transform
#' peaks or h-minima inside the Otsu foreground of `channel`. The
#' watershed then floods from these seeds, level by level along the
#' surface, so that object boundaries follow its ridges; pixels outside
#' the foreground are never flooded (only `expand_pixels` grows objects
#' beyond it).
#'
#' @param image An `sg_image` object.
#' @param channel Integer index of the image channel used for
#'   segmentation. Default is `1L`.
#' @param seed_method Character string specifying how seeds are
#'   generated. One of `"h_minima"` (default), `"distance"`, or
#'   `"markers"`.
#' @param h Numeric; height parameter for h-minima or distance
#'   threshold fraction for seed detection. Default is `0.05`.
#' @param min_distance Integer; minimum pixel distance between seeds.
#'   Default is `10L`.
#' @param expand_method Character string specifying how seed regions
#'   are expanded. One of `"voronoi"` (default) or `"dilation"`.
#' @param expand_pixels Integer; number of pixels to expand beyond
#'   the initial watershed regions. Default is `3L`.
#' @param membrane_channel Integer or `NULL`. If provided, this
#'   channel is used as the topographic surface for watershed
#'   flooding. If `NULL`, the inverted `channel` image is used.
#'
#' @return An `sg_mask` object with labelled cell regions.
#' @export
#' @examples
#' set.seed(42)
#' pixels <- matrix(runif(400), nrow = 20, ncol = 20)
#' img <- new_sg_image(pixels)
#' mask <- sg_segment_watershed(img, seed_method = "distance", h = 0.3)
#' print(mask)
sg_segment_watershed <- function(image,
                                 channel = 1L,
                                 seed_method = c("h_minima", "distance",
                                                 "markers"),
                                 h = 0.05,
                                 min_distance = 10L,
                                 expand_method = c("voronoi", "dilation"),
                                 expand_pixels = 3L,
                                 membrane_channel = NULL) {

  stopifnot(inherits(image, "sg_image"))
  seed_method <- match.arg(seed_method)
  expand_method <- match.arg(expand_method)
  channel <- as.integer(channel)
  min_distance <- as.integer(min_distance)
  expand_pixels <- as.integer(expand_pixels)

  ch <- .extract_channel(image, channel)

  # Membrane surface for watershed
  if (!is.null(membrane_channel)) {
    membrane_channel <- as.integer(membrane_channel)
    surface <- .extract_channel(image, membrane_channel)
  } else {
    rng <- range(ch, na.rm = TRUE)
    surface <- if (rng[2] - rng[1] > 0) {
      (rng[2] - ch) / (rng[2] - rng[1])
    } else {
      ch
    }
  }

  # --- Generate seeds -----------------------------------------------------
  foreground <- .watershed_foreground(ch)
  seeds <- .watershed_seeds(ch, method = seed_method, h = h,
                            min_distance = min_distance,
                            foreground = foreground)

  cli::cli_inform(c(
    "i" = "Generated {max(seeds, na.rm = TRUE)} seed{?s} via {.val {seed_method}}."
  ))

  # --- Watershed flooding (restricted to the foreground) -------------------
  labels <- .simple_watershed(surface, seeds, foreground = foreground)

  # --- Expansion ----------------------------------------------------------
  if (expand_pixels > 0L) {
    if (expand_method == "voronoi") {
      labels <- .voronoi_propagate_r(labels, expand_max = expand_pixels)
    } else {
      labels <- .dilate_labels(labels, expand_pixels)
    }
  }

  n_cells <- max(labels, na.rm = TRUE)
  if (is.na(n_cells) || n_cells < 0L) n_cells <- 0L
  cli::cli_inform(c(
    "v" = "Watershed segmented {n_cells} object{?s}."
  ))

  new_sg_mask(
    labels = labels,
    model_info = list(
      method = "watershed",
      seed_method = seed_method,
      h = h,
      expand_method = expand_method,
      expand_pixels = expand_pixels
    )
  )
}


#' Voronoi propagation from nuclear seeds
#'
#' Expands nuclear seed regions outward using Voronoi-style
#' propagation, optionally constrained by a membrane signal.
#' When available, `EBImage::propagate()` is used for higher
#' performance; otherwise a pure-R fallback is used.
#'
#' @param image An `sg_image` object.
#' @param nuclear_mask An `sg_mask` object providing the nuclear seed
#'   labels.
#' @param membrane_image An `sg_image` object (single channel) used
#'   to constrain the pure-R engine: new pixels must have intensity strictly
#'   below the membrane image's 90th percentile. Supplied seeds are retained.
#'   A membrane image selects pure R in auto mode.
#' @param lambda Finite nonnegative numeric weight passed only to EBImage.
#'   Higher values give Euclidean distance more weight relative to image
#'   gradients. The pure-R engine does not use this parameter. Default `0.01`.
#' @param expand_max Nonnegative integer; maximum number of four-neighbour
#'   propagation steps from the supplied seed pixels. Default is `20L`.
#'   With no membrane, this bounds the support to Manhattan distance
#'   `expand_max` pixels from a seed. Both engines honor this support bound;
#'   EBImage retains its intensity-aware assignment of labels within it, so
#'   the engines need not assign identical labels. Zero preserves the seeds.
#' @param engine `"auto"` (default, historic behaviour: EBImage when it is
#'   installed and no membrane image is given, otherwise pure R),
#'   `"voronoi_r"` (always the pure-R engine) or `"ebimage"` (always
#'   EBImage; errors instead of falling back).
#'
#' @return An `sg_mask` object with expanded cell labels. Its `model_info`
#'   records the engine, requested `lambda`, whether `lambda_applied`, and
#'   `expand_max`. For pure R it also records `membrane_threshold` and
#'   `membrane_quantile` (`NULL` when no membrane image is supplied).
#' @export
#' @examples
#' set.seed(42)
#' pixels <- matrix(runif(400), nrow = 20, ncol = 20)
#' img <- new_sg_image(pixels)
#' seeds <- matrix(0L, nrow = 20, ncol = 20)
#' seeds[5, 5] <- 1L
#' seeds[15, 15] <- 2L
#' nuc_mask <- new_sg_mask(seeds)
#' result <- sg_segment_propagate(img, nuclear_mask = nuc_mask)
#' print(result)
sg_segment_propagate <- function(image,
                                 nuclear_mask,
                                 membrane_image = NULL,
                                 lambda = 0.01,
                                 expand_max = 20L,
                                 engine = c("auto", "voronoi_r", "ebimage")) {

  stopifnot(inherits(image, "sg_image"))
  stopifnot(inherits(nuclear_mask, "sg_mask"))
  stopifnot(is.numeric(lambda), length(lambda) == 1L,
            is.null(dim(lambda)), is.finite(lambda), lambda >= 0)
  if (!is.numeric(expand_max) || length(expand_max) != 1L ||
      !is.null(dim(expand_max)) || !is.finite(expand_max) ||
      expand_max < 0 || expand_max != floor(expand_max) ||
      expand_max > .Machine$integer.max) {
    .sg_abort("{.arg expand_max} must be one nonnegative integer within the supported integer range.",
              code = "PARAMETER_OUT_OF_RANGE")
  }
  expand_max <- as.integer(expand_max)
  engine <- match.arg(engine)

  seeds <- nuclear_mask$labels
  if (!identical(dim(seeds), dim(image$pixels)[1:2])) {
    .sg_abort("Image and nuclear mask dimensions must match.",
              code = "DIMENSION_MISMATCH")
  }

  # Membrane cost surface
  membrane <- NULL
  if (!is.null(membrane_image)) {
    stopifnot(inherits(membrane_image, "sg_image"))
    membrane <- .extract_channel(membrane_image, 1L)
    if (!identical(dim(membrane), dim(seeds))) {
      .sg_abort("Membrane image and nuclear mask dimensions must match.",
                code = "DIMENSION_MISMATCH")
    }
  }

  if (engine == "ebimage") {
    if (!.check_ebimage()) {
      .sg_abort_unavailable(
        "EBImage propagation",
        "Install the Bioconductor package {.pkg EBImage} or use engine = 'voronoi_r'."
      )
    }
    if (!is.null(membrane_image)) {
      .sg_abort("The EBImage engine does not use a membrane image.",
                code = "VALIDATION_FAILED")
    }
  }

  # Try EBImage::propagate for speed
  if (engine != "voronoi_r" && .check_ebimage() && is.null(membrane_image)) {
    ch <- .extract_channel(image, 1L)
    labels <- tryCatch({
      support <- .sg_propagation_support(seeds, expand_max)
      eb_result <- .ebimage_propagate(ch, seeds = seeds, lambda = lambda,
                                      mask = support)
      eb_labels <- as.integer(EBImage::imageData(eb_result))
      dim(eb_labels) <- dim(seeds)
      eb_labels
    }, error = function(e) {
      if (engine == "ebimage") {
        .sg_abort(c("EBImage::propagate() failed.",
                    "x" = "{conditionMessage(e)}"),
                  class = "sg_capability_error",
                  code = "CAPABILITY_UNAVAILABLE")
      }
      cli::cli_inform(c(
        "!" = "EBImage::propagate() failed; using pure-R fallback.",
        "i" = "{conditionMessage(e)}"
      ))
      NULL
    })
    if (!is.null(labels)) {
      return(new_sg_mask(
        labels = labels,
        model_info = list(
          method = "propagate:ebimage",
          lambda = lambda,
          lambda_applied = TRUE,
          expand_max = expand_max
        )
      ))
    }
  }

  # Pure-R Voronoi propagation
  membrane_threshold <- if (!is.null(membrane)) {
    unname(stats::quantile(membrane, 0.9))
  } else {
    NULL
  }
  mask_binary <- if (!is.null(membrane)) {
    ifelse(membrane < membrane_threshold, 1L, 0L)
  } else {
    NULL
  }

  labels <- .voronoi_propagate_r(seeds, mask = mask_binary,
                                 expand_max = expand_max)

  n_cells <- length(.sg_label_ids(labels))
  cli::cli_inform(c(
    "v" = "Propagation assigned {n_cells} cell{?s}."
  ))

  new_sg_mask(
    labels = labels,
    model_info = list(
      method = "propagate:voronoi_r",
      lambda = lambda,
      lambda_applied = FALSE,
      membrane_threshold = membrane_threshold,
      membrane_quantile = if (!is.null(membrane)) 0.9 else NULL,
      expand_max = expand_max
    )
  )
}


# ---- Internal helpers ---------------------------------------------------

#' Thin wrapper around `EBImage::propagate()`
#'
#' Provides a mockable seam so tests can force the EBImage code path to fail
#' and exercise the pure-R Voronoi fallback regardless of whether EBImage is
#' installed.
#' @noRd
.ebimage_propagate <- function(x, seeds, lambda, mask = NULL) {
  EBImage::propagate(x, seeds = seeds, lambda = lambda, mask = mask)
}

# Support reachable by synchronous four-neighbour steps, matching the pure-R
# propagation bound without imposing its label assignment on another engine.
.sg_propagation_support <- function(seeds, expand_max) {
  reached <- seeds > 0L
  nr <- nrow(seeds)
  nc <- ncol(seeds)
  steps <- min(expand_max, as.double(nr) + nc - 2)
  for (i in seq_len(steps)) {
    grown <- reached
    if (nr > 1L) {
      grown[-1L, ] <- grown[-1L, , drop = FALSE] | reached[-nr, , drop = FALSE]
      grown[-nr, ] <- grown[-nr, , drop = FALSE] | reached[-1L, , drop = FALSE]
    }
    if (nc > 1L) {
      grown[, -1L] <- grown[, -1L, drop = FALSE] | reached[, -nc, drop = FALSE]
      grown[, -nc] <- grown[, -nc, drop = FALSE] | reached[, -1L, drop = FALSE]
    }
    if (identical(grown, reached)) break
    reached <- grown
  }
  reached
}

#' Level-ordered watershed flood from seeds
#'
#' Floods the surface by immersion: the surface is binned into `n_levels`
#' levels and, level by level, unlabelled pixels at or below the current
#' level take the label of a labelled 4-neighbour (first of up, down, left,
#' right) until nothing changes. Ridges of the surface therefore become the
#' boundaries between basins. Pixels outside `foreground` are never
#' flooded.
#' @noRd
.simple_watershed <- function(surface, seeds, foreground = NULL,
                              n_levels = 256L) {
  nr <- nrow(surface)
  nc <- ncol(surface)
  labels <- seeds
  allowed <- if (is.null(foreground)) {
    matrix(TRUE, nr, nc)
  } else {
    !is.na(foreground) & foreground == 1L
  }
  vals <- surface[allowed & is.finite(surface)]
  rng <- if (length(vals) > 0L) range(vals) else c(0, 0)
  level <- if (rng[2] > rng[1]) {
    1L + floor((surface - rng[1]) / (rng[2] - rng[1]) * (n_levels - 1L))
  } else {
    matrix(1L, nr, nc)
  }
  level[!is.finite(level)] <- n_levels
  level <- pmin(pmax(level, 1L), n_levels)
  for (lev in sort(unique(level[allowed & labels == 0L]))) {
    repeat {
      free <- allowed & labels == 0L & level <= lev
      if (!any(free)) break
      nb <- .neighbour_label(labels)
      grow <- free & nb > 0L
      if (!any(grow)) break
      labels[grow] <- nb[grow]
    }
  }
  labels
}

#' Label of the first labelled 4-neighbour (up, down, left, right), or 0
#' @noRd
.neighbour_label <- function(labels) {
  nr <- nrow(labels)
  nc <- ncol(labels)
  up <- rbind(0L, labels[-nr, , drop = FALSE])
  down <- rbind(labels[-1L, , drop = FALSE], 0L)
  left <- cbind(0L, labels[, -nc, drop = FALSE])
  right <- cbind(labels[, -1L, drop = FALSE], 0L)
  nb <- up
  for (cand in list(down, left, right)) {
    take <- nb == 0L
    nb[take] <- cand[take]
  }
  nb
}

#' Dilate labelled regions
#' @noRd
.dilate_labels <- function(labels, n_pixels) {
  for (iter in seq_len(n_pixels)) {
    nr <- nrow(labels)
    nc <- ncol(labels)
    new_labels <- labels
    for (i in seq_len(nr)) {
      for (j in seq_len(nc)) {
        if (labels[i, j] != 0L) next
        neighbors <- integer(0)
        if (i > 1L && labels[i - 1L, j] > 0L) {
          neighbors <- c(neighbors, labels[i - 1L, j])
        }
        if (i < nr && labels[i + 1L, j] > 0L) {
          neighbors <- c(neighbors, labels[i + 1L, j])
        }
        if (j > 1L && labels[i, j - 1L] > 0L) {
          neighbors <- c(neighbors, labels[i, j - 1L])
        }
        if (j < nc && labels[i, j + 1L] > 0L) {
          neighbors <- c(neighbors, labels[i, j + 1L])
        }
        if (length(neighbors) > 0L) {
          tbl <- table(neighbors)
          new_labels[i, j] <- as.integer(names(tbl)[which.max(tbl)])
        }
      }
    }
    labels <- new_labels
  }
  labels
}
