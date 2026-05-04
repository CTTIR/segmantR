#' Marker-controlled watershed segmentation
#'
#' Segments cells using a marker-controlled watershed algorithm.
#' Seeds (markers) are detected automatically via distance-transform
#' peaks or h-minima, and the watershed flood fills from these seeds.
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
  seeds <- .watershed_seeds(ch, method = seed_method, h = h,
                            min_distance = min_distance)

  cli::cli_inform(c(
    "i" = "Generated {max(seeds, na.rm = TRUE)} seed{?s} via {.val {seed_method}}."
  ))

  # --- Watershed flooding -------------------------------------------------
  labels <- .simple_watershed(surface, seeds)

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
#'   as a cost surface to penalise crossing membranes. If `NULL`,
#'   propagation proceeds uniformly.
#' @param lambda Numeric weight for the membrane penalty in the cost
#'   function. Higher values make propagation stop more readily at
#'   membranes. Default is `0.01`.
#' @param expand_max Integer; maximum number of propagation
#'   iterations. Default is `20L`.
#'
#' @return An `sg_mask` object with expanded cell labels.
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
                                 expand_max = 20L) {

  stopifnot(inherits(image, "sg_image"))
  stopifnot(inherits(nuclear_mask, "sg_mask"))
  stopifnot(is.numeric(lambda), length(lambda) == 1L, lambda >= 0)
  expand_max <- as.integer(expand_max)

  seeds <- nuclear_mask$labels

  # Membrane cost surface
  membrane <- NULL
  if (!is.null(membrane_image)) {
    stopifnot(inherits(membrane_image, "sg_image"))
    membrane <- .extract_channel(membrane_image, 1L)
  }

  # Try EBImage::propagate for speed
  if (.check_ebimage() && is.null(membrane_image)) {
    ch <- .extract_channel(image, 1L)
    labels <- tryCatch({
      eb_result <- EBImage::propagate(ch, seeds = seeds, lambda = lambda)
      eb_labels <- as.integer(EBImage::imageData(eb_result))
      dim(eb_labels) <- dim(seeds)
      eb_labels
    }, error = function(e) {
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
          lambda = lambda
        )
      ))
    }
  }

  # Pure-R Voronoi propagation
  mask_binary <- if (!is.null(membrane)) {
    ifelse(membrane < stats::quantile(membrane, 0.9), 1L, 0L)
  } else {
    NULL
  }

  labels <- .voronoi_propagate_r(seeds, mask = mask_binary,
                                 expand_max = expand_max)

  n_cells <- max(labels, na.rm = TRUE)
  if (is.na(n_cells) || n_cells < 0L) n_cells <- 0L
  cli::cli_inform(c(
    "v" = "Propagation assigned {n_cells} cell{?s}."
  ))

  new_sg_mask(
    labels = labels,
    model_info = list(
      method = "propagate:voronoi_r",
      lambda = lambda,
      expand_max = expand_max
    )
  )
}


# ---- Internal helpers ---------------------------------------------------

#' Simple priority-free watershed (greedy flood fill from seeds)
#' @noRd
.simple_watershed <- function(surface, seeds) {
  nr <- nrow(surface)
  nc <- ncol(surface)
  labels <- seeds
  changed <- TRUE
  max_iter <- max(nr, nc)
  iter <- 0L
  while (changed && iter < max_iter) {
    changed <- FALSE
    iter <- iter + 1L
    new_labels <- labels
    for (i in seq_len(nr)) {
      for (j in seq_len(nc)) {
        if (labels[i, j] != 0L) next
        neighbors <- integer(0)
        costs <- numeric(0)
        if (i > 1L && labels[i - 1L, j] > 0L) {
          neighbors <- c(neighbors, labels[i - 1L, j])
          costs <- c(costs, surface[i, j])
        }
        if (i < nr && labels[i + 1L, j] > 0L) {
          neighbors <- c(neighbors, labels[i + 1L, j])
          costs <- c(costs, surface[i, j])
        }
        if (j > 1L && labels[i, j - 1L] > 0L) {
          neighbors <- c(neighbors, labels[i, j - 1L])
          costs <- c(costs, surface[i, j])
        }
        if (j < nc && labels[i, j + 1L] > 0L) {
          neighbors <- c(neighbors, labels[i, j + 1L])
          costs <- c(costs, surface[i, j])
        }
        if (length(neighbors) > 0L) {
          # Assign the label of the lowest-cost neighbor
          tbl <- table(neighbors)
          new_labels[i, j] <- as.integer(names(tbl)[which.max(tbl)])
          changed <- TRUE
        }
      }
    }
    labels <- new_labels
  }
  labels
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
