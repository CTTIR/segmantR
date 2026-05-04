# Shiny app launcher and example data generators

#' Launch the segmantR Shiny application
#'
#' Starts the interactive Shiny application for cell segmentation,
#' annotation, and model training. The app is bundled under
#' `inst/shiny/segmantR/`.
#'
#' @param image An `sg_image` object to pre-load, or `NULL`.
#' @param mask An `sg_mask` object to pre-load, or `NULL`.
#' @param port Integer port number, or `NULL` to use the default.
#' @param launch.browser Logical, whether to open the app in a browser
#'   (default `TRUE`).
#'
#' @return `NULL`, invisibly.
#' @export
#' @examples
#' \donttest{
#' sg_run_app()
#' }
sg_run_app <- function(image = NULL, mask = NULL, port = NULL,
                       launch.browser = TRUE) {

  app_dir <- system.file("shiny", "segmantR", package = "segmantR")
  if (!nzchar(app_dir)) {
    cli::cli_abort("Could not locate the bundled Shiny app directory.")
  }

  # Pass objects via options so the app can retrieve them on startup
  .sg_env <- new.env(parent = emptyenv())
  .sg_env$image <- image
  .sg_env$mask <- mask
  options(segmantR.app_env = .sg_env)

  run_args <- list(appDir = app_dir, launch.browser = launch.browser)
  if (!is.null(port)) {
    run_args$port <- as.integer(port)
  }
  do.call(shiny::runApp, run_args)

  invisible(NULL)
}

#' Load a bundled example image
#'
#' Returns an `sg_image` containing synthetic image data for testing
#' and demonstrations.
#'
#' @param type Character, one of `"he_breast"`, `"fluorescence_nuclei"`,
#'   or `"multiplex_4ch"`.
#'
#' @return An `sg_image` object.
#' @export
#' @examples
#' img <- sg_example_image("he_breast")
#' print(img)
sg_example_image <- function(type = c("he_breast", "fluorescence_nuclei",
                                      "multiplex_4ch")) {
  type <- match.arg(type)

  switch(type,
    he_breast       = .generate_he_image(),
    fluorescence_nuclei = .generate_fluorescence_image(),
    multiplex_4ch   = .generate_multiplex_image()
  )
}

#' Load a bundled example mask
#'
#' Returns an `sg_mask` matching the corresponding example image.
#'
#' @param type Character, one of `"he_breast"`, `"fluorescence_nuclei"`,
#'   or `"multiplex_4ch"`.
#'
#' @return An `sg_mask` object.
#' @export
#' @examples
#' mask <- sg_example_mask("he_breast")
#' print(mask)
sg_example_mask <- function(type = c("he_breast", "fluorescence_nuclei",
                                     "multiplex_4ch")) {
  type <- match.arg(type)

  switch(type,
    he_breast       = .generate_he_mask(),
    fluorescence_nuclei = .generate_fluorescence_mask(),
    multiplex_4ch   = .generate_multiplex_mask()
  )
}


# ---- internal generators ----------------------------------------------------

#' Generate synthetic H&E breast image (64x64, single channel)
#' @noRd
.generate_he_image <- function() {
  set.seed(42L)
  mat <- matrix(0.85, nrow = 64L, ncol = 64L)
  centres <- .random_centres(n = 20L, nr = 64L, nc = 64L)
  for (k in seq_len(nrow(centres))) {
    mat <- .draw_ellipse(mat, centres[k, 1], centres[k, 2],
                         rx = centres[k, 3], ry = centres[k, 4],
                         value = stats::runif(1L, 0.2, 0.5))
  }
  mat <- mat + matrix(stats::rnorm(64L * 64L, 0, 0.02), 64L, 64L)
  mat <- pmin(pmax(mat, 0), 1)
  new_sg_image(mat, channels = "H&E",
               metadata = list(type = "he_breast", synthetic = TRUE))
}

#' Generate synthetic fluorescence nuclei image (64x64, single channel)
#' @noRd
.generate_fluorescence_image <- function() {
  set.seed(123L)
  mat <- matrix(0.05, nrow = 64L, ncol = 64L)
  centres <- .random_centres(n = 15L, nr = 64L, nc = 64L)
  for (k in seq_len(nrow(centres))) {
    mat <- .draw_ellipse(mat, centres[k, 1], centres[k, 2],
                         rx = centres[k, 3], ry = centres[k, 4],
                         value = stats::runif(1L, 0.6, 1.0))
  }
  mat <- mat + matrix(stats::rnorm(64L * 64L, 0, 0.01), 64L, 64L)
  mat <- pmin(pmax(mat, 0), 1)
  new_sg_image(mat, channels = "DAPI",
               metadata = list(type = "fluorescence_nuclei", synthetic = TRUE))
}

#' Generate synthetic multiplex 4-channel image (64x64x4)
#' @noRd
.generate_multiplex_image <- function() {
  set.seed(7L)
  arr <- array(0.05, dim = c(64L, 64L, 4L))
  centres <- .random_centres(n = 18L, nr = 64L, nc = 64L)
  for (ch in seq_len(4L)) {
    for (k in seq_len(nrow(centres))) {
      arr[, , ch] <- .draw_ellipse(
        arr[, , ch], centres[k, 1], centres[k, 2],
        rx = centres[k, 3], ry = centres[k, 4],
        value = stats::runif(1L, 0.3, 1.0)
      )
    }
    arr[, , ch] <- arr[, , ch] +
      matrix(stats::rnorm(64L * 64L, 0, 0.01), 64L, 64L)
  }
  arr <- pmin(pmax(arr, 0), 1)
  new_sg_image(arr, channels = c("DAPI", "CD3", "CD8", "PanCK"),
               metadata = list(type = "multiplex_4ch", synthetic = TRUE))
}

#' Generate mask matching HE image
#' @noRd
.generate_he_mask <- function() {
  set.seed(42L)
  labels <- matrix(0L, nrow = 64L, ncol = 64L)
  centres <- .random_centres(n = 20L, nr = 64L, nc = 64L)
  for (k in seq_len(nrow(centres))) {
    labels <- .draw_ellipse_int(labels, centres[k, 1], centres[k, 2],
                                rx = centres[k, 3], ry = centres[k, 4],
                                value = k)
  }
  new_sg_mask(labels,
              model_info = list(method = "synthetic", type = "he_breast"))
}

#' Generate mask matching fluorescence image
#' @noRd
.generate_fluorescence_mask <- function() {
  set.seed(123L)
  labels <- matrix(0L, nrow = 64L, ncol = 64L)
  centres <- .random_centres(n = 15L, nr = 64L, nc = 64L)
  for (k in seq_len(nrow(centres))) {
    labels <- .draw_ellipse_int(labels, centres[k, 1], centres[k, 2],
                                rx = centres[k, 3], ry = centres[k, 4],
                                value = k)
  }
  new_sg_mask(labels,
              model_info = list(method = "synthetic",
                                type = "fluorescence_nuclei"))
}

#' Generate mask matching multiplex image
#' @noRd
.generate_multiplex_mask <- function() {
  set.seed(7L)
  labels <- matrix(0L, nrow = 64L, ncol = 64L)
  centres <- .random_centres(n = 18L, nr = 64L, nc = 64L)
  for (k in seq_len(nrow(centres))) {
    labels <- .draw_ellipse_int(labels, centres[k, 1], centres[k, 2],
                                rx = centres[k, 3], ry = centres[k, 4],
                                value = k)
  }
  new_sg_mask(labels,
              model_info = list(method = "synthetic",
                                type = "multiplex_4ch"))
}


# ---- low-level drawing helpers ----------------------------------------------

#' Generate random ellipse centres and radii
#' @noRd
.random_centres <- function(n, nr, nc, min_r = 3L, max_r = 7L) {
  cbind(
    row = sample(seq(min_r + 1L, nr - min_r - 1L), n, replace = TRUE),
    col = sample(seq(min_r + 1L, nc - min_r - 1L), n, replace = TRUE),
    rx  = sample(seq(min_r, max_r), n, replace = TRUE),
    ry  = sample(seq(min_r, max_r), n, replace = TRUE)
  )
}

#' Draw a filled ellipse on a numeric matrix
#' @noRd
.draw_ellipse <- function(mat, cr, cc, rx, ry, value) {
  nr <- nrow(mat)
  nc <- ncol(mat)
  r_seq <- seq(max(1L, cr - rx), min(nr, cr + rx))
  c_seq <- seq(max(1L, cc - ry), min(nc, cc + ry))
  for (i in r_seq) {
    for (j in c_seq) {
      if (((i - cr) / rx)^2 + ((j - cc) / ry)^2 <= 1) {
        mat[i, j] <- value
      }
    }
  }
  mat
}

#' Draw a filled ellipse on an integer label matrix
#' @noRd
.draw_ellipse_int <- function(mat, cr, cc, rx, ry, value) {
  nr <- nrow(mat)
  nc <- ncol(mat)
  r_seq <- seq(max(1L, cr - rx), min(nr, cr + rx))
  c_seq <- seq(max(1L, cc - ry), min(nc, cc + ry))
  for (i in r_seq) {
    for (j in c_seq) {
      if (((i - cr) / rx)^2 + ((j - cc) / ry)^2 <= 1) {
        mat[i, j] <- as.integer(value)
      }
    }
  }
  mat
}
